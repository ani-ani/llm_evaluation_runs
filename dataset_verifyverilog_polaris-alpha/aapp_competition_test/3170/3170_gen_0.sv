module trash_game(
  input clk, // system clock
  input rst_n, // active-low reset
  input [3:0] card_in, // serial card input (encoded ranks)
  input card_valid, // high when card_in valid
  output reg theta_win, // 1 if theta wins
  output reg friend_win // 1 if friend wins
);

  // Internal representation of ranks (4-bit) expected on card_in:
  // 1-9 : numeric ranks
  // 10  : 'T' (10)
  // 11  : 'J'
  // 12  : 'Q'
  // 13  : 'K'

  typedef enum logic [2:0] {
    S_INIT_DEAL       = 3'd0,
    S_TURN_START      = 3'd1,
    S_WAIT_CARD       = 3'd2,
    S_PROCESS_CARD    = 3'd3,
    S_CHECK_WIN       = 3'd4,
    S_DONE            = 3'd5
  } state_t;

  state_t state, next_state;

  // turn: 0 = theta, 1 = friend
  logic turn, next_turn;

  // Slots filled flags: bit0->slot1, bit1->slot2, bit2->slot3, bit3->slot4
  reg [3:0] theta_slots, friend_slots;
  reg [3:0] next_theta_slots, next_friend_slots;

  // Track how many initial cards have been consumed for dealing (0-7)
  reg [3:0] deal_count, next_deal_count;

  // Latched card for processing
  reg [3:0] cur_card, next_cur_card;
  reg       cur_card_valid, next_cur_card_valid;

  // Discard flag for informational use only (no output)
  reg discard_next;

  // Winner flags next
  reg next_theta_win, next_friend_win;

  // Combinational helpers
  function automatic logic is_jack(input logic [3:0] r);
    is_jack = (r == 4'd11);
  endfunction

  function automatic logic is_valid_for_slot(
    input logic [3:0] r,
    input int unsigned slot_id
  );
    // slot_id: 1..4
    case (slot_id)
      1: is_valid_for_slot = (r == 4'd1) || (r == 4'd10); // 1 or 10(T) treated as wild for 1? (spec ambiguous)
      2: is_valid_for_slot = (r == 4'd2);
      3: is_valid_for_slot = (r == 4'd3);
      4: is_valid_for_slot = (r == 4'd4) || (r == 4'd10); // 4 or any with wild; assume T is wild here
      default: is_valid_for_slot = 1'b0;
    endcase
  endfunction

  // Note: Problem text ambiguous on wilds; implemented simple example:
  // - 'T' (10) considered wild for slots 1 and 4.
  // Adjust mapping as needed.

  // Place card into appropriate slot based on player policy.
  function automatic [3:0] place_card_theta(
    input [3:0] slots,
    input [3:0] r
  );
    // Theta uses Jacks optimally: choose lowest ID available slot.
    // For non-Jacks: place only if rank exactly matches required slot.
    reg [3:0] new_slots;
    new_slots = slots;

    if (is_jack(r)) begin
      if (!new_slots[0])      new_slots[0] = 1'b1; // slot1
      else if (!new_slots[1]) new_slots[1] = 1'b1; // slot2
      else if (!new_slots[2]) new_slots[2] = 1'b1; // slot3
      else if (!new_slots[3]) new_slots[3] = 1'b1; // slot4
    end else begin
      // Direct mapping: slot N expects rank N (except slot4 allows 4 or wild via is_valid_for_slot)
      if (!slots[0] && is_valid_for_slot(r,1)) new_slots[0] = 1'b1;
      else if (!slots[1] && is_valid_for_slot(r,2)) new_slots[1] = 1'b1;
      else if (!slots[2] && is_valid_for_slot(r,3)) new_slots[2] = 1'b1;
      else if (!slots[3] && is_valid_for_slot(r,4)) new_slots[3] = 1'b1;
    end
    place_card_theta = new_slots;
  endfunction

  function automatic [3:0] place_card_friend(
    input [3:0] slots,
    input [3:0] r
  );
    // Friend always uses Jacks in lowest available slot.
    reg [3:0] new_slots;
    new_slots = slots;

    if (is_jack(r)) begin
      if (!new_slots[0])      new_slots[0] = 1'b1;
      else if (!new_slots[1]) new_slots[1] = 1'b1;
      else if (!new_slots[2]) new_slots[2] = 1'b1;
      else if (!new_slots[3]) new_slots[3] = 1'b1;
    end else begin
      if (!slots[0] && is_valid_for_slot(r,1)) new_slots[0] = 1'b1;
      else if (!slots[1] && is_valid_for_slot(r,2)) new_slots[1] = 1'b1;
      else if (!slots[2] && is_valid_for_slot(r,3)) new_slots[2] = 1'b1;
      else if (!slots[3] && is_valid_for_slot(r,4)) new_slots[3] = 1'b1;
    end
    place_card_friend = new_slots;
  endfunction

  // Sequential state and registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= S_INIT_DEAL;
      turn            <= 1'b0; // theta starts
      theta_slots     <= 4'b0000;
      friend_slots    <= 4'b0000;
      deal_count      <= 4'd0;
      cur_card        <= 4'd0;
      cur_card_valid  <= 1'b0;
      theta_win       <= 1'b0;
      friend_win      <= 1'b0;
    end else begin
      state           <= next_state;
      turn            <= next_turn;
      theta_slots     <= next_theta_slots;
      friend_slots    <= next_friend_slots;
      deal_count      <= next_deal_count;
      cur_card        <= next_cur_card;
      cur_card_valid  <= next_cur_card_valid;
      theta_win       <= next_theta_win;
      friend_win      <= next_friend_win;
    end
  end

  // Combinational next-state logic
  always_comb begin
    next_state          = state;
    next_turn           = turn;
    next_theta_slots    = theta_slots;
    next_friend_slots   = friend_slots;
    next_deal_count     = deal_count;
    next_cur_card       = cur_card;
    next_cur_card_valid = cur_card_valid;
    next_theta_win      = theta_win;
    next_friend_win     = friend_win;
    discard_next        = 1'b0;

    case (state)

      // Initial phase: first 4 cards -> theta face-down, next 4 -> friend face-down
      // We do not use their values; we simply consume 8 cards from the stream.
      S_INIT_DEAL: begin
        if (theta_win || friend_win) begin
          next_state = S_DONE;
        end else if (deal_count < 4'd8) begin
          // wait for 8 valid cards to be consumed
          if (card_valid) begin
            next_deal_count = deal_count + 4'd1;
          end
          // stay in S_INIT_DEAL until 8 cards seen
        end
        if (deal_count == 4'd8) begin
          // move to first turn start once dealing done
          next_state = S_TURN_START;
          next_turn  = 1'b0; // theta starts
        end
      end

      // Start of a player's turn: request a draw
      S_TURN_START: begin
        if (theta_win || friend_win) begin
          next_state = S_DONE;
        end else begin
          // move to wait for a new card from draw pile
          next_cur_card_valid = 1'b0;
          next_state          = S_WAIT_CARD;
        end
      end

      // Wait for card_valid high to latch a draw
      S_WAIT_CARD: begin
        if (theta_win || friend_win) begin
          next_state = S_DONE;
        end else if (card_valid) begin
          next_cur_card       = card_in;
          next_cur_card_valid = 1'b1;
          next_state          = S_PROCESS_CARD;
        end
      end

      // Process drawn card for current player
      S_PROCESS_CARD: begin
        if (theta_win || friend_win) begin
          next_state = S_DONE;
        end else if (cur_card_valid) begin
          if (turn == 1'b0) begin
            // Theta's move
            logic [3:0] new_slots;
            new_slots = place_card_theta(theta_slots, cur_card);
            if (new_slots != theta_slots)
              next_theta_slots = new_slots;
            else
              discard_next = 1'b1; // invalid/unused card -> discard
          end else begin
            // Friend's move
            logic [3:0] new_slots;
            new_slots = place_card_friend(friend_slots, cur_card);
            if (new_slots != friend_slots)
              next_friend_slots = new_slots;
            else
              discard_next = 1'b1;
          end

          // After processing, go check win condition
          next_cur_card_valid = 1'b0;
          next_state          = S_CHECK_WIN;
        end else begin
          // no valid card latched; go back to wait (robustness)
          next_state = S_WAIT_CARD;
        end
      end

      // Check if any player completed all 4 slots
      S_CHECK_WIN: begin
        if (&next_theta_slots && !theta_win && !friend_win) begin
          next_theta_win = 1'b1;
          next_friend_win = 1'b0;
          next_state = S_DONE;
        end else if (&next_friend_slots && !theta_win && !friend_win) begin
          next_friend_win = 1'b1;
          next_theta_win = 1'b0;
          next_state = S_DONE;
        end else begin
          // No winner yet, toggle turn and continue
          next_turn  = ~turn;
          next_state = S_TURN_START;
        end
      end

      // Game finished, hold outputs and state
      S_DONE: begin
        next_state = S_DONE;
      end

      default: begin
        next_state = S_INIT_DEAL;
      end
    endcase
  end

endmodule