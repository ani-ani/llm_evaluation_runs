module trash_game(
  input clk, // system clock
  input rst_n, // active-low reset
  input [3:0] card_in, // serial card input (ASCII: '1'-'9','A','T','J','Q','K')
  input card_valid, // high when card_in valid
  output reg theta_win, // 1 if theta wins
  output reg friend_win // 1 if friend wins
);

  // Constants
  localparam ST_IDLE         = 3'b000;
  localparam ST_DEAL         = 3'b001;
  localparam ST_THETA_START  = 3'b010;
  localparam ST_THETA_PROC   = 3'b011;
  localparam ST_FRIEND_START = 3'b100;
  localparam ST_FRIEND_PROC  = 3'b101;
  localparam ST_DONE         = 3'b110;

  // State
  reg [2:0] state, next_state;
  reg [7:0] dealt_count; // 0..8 used during DEAL
  reg [3:0] theta_buf [0:3]; // face-down slots: 0..3 (IDs 1..4)
  reg [3:0] friend_buf [0:3];
  reg [3:0] theta_slots; // bitmask of filled slots (1= filled)
  reg [3:0] friend_slots;
  reg [3:0] card_reg; // registered card_in (valid when card_valid sampled)
  reg game_active; // 1 while game ongoing (until win)

  // Helpers
  function [3:0] ascii_to_rank (input [7:0] ch);
    case (ch)
      8'd49: ascii_to_rank = 4'd1;  // '1'
      8'd50: ascii_to_rank = 4'd2;  // '2'
      8'd51: ascii_to_rank = 4'd3;  // '3'
      8'd52: ascii_to_rank = 4'd4;  // '4'
      8'd53: ascii_to_rank = 4'd5;  // '5'
      8'd54: ascii_to_rank = 4'd6;  // '6'
      8'd55: ascii_to_rank = 4'd7;  // '7'
      8'd56: ascii_to_rank = 4'd8;  // '8'
      8'd57: ascii_to_rank = 4'd9;  // '9'
      8'd65: ascii_to_rank = 4'd14; // 'A'
      8'd84: ascii_to_rank = 4'd10; // 'T'
      8'd74: ascii_to_rank = 4'd11; // 'J'
      8'd81: ascii_to_rank = 4'd12; // 'Q'
      8'd75: ascii_to_rank = 4'd13; // 'K'
      default: ascii_to_rank = 4'd0; // invalid
    endcase
  endfunction

  function [3:0] slot_requirement (input [3:0] slot_id);
    // slot_id is 1..4
    case (slot_id)
      4'd1: slot_requirement = 4'd1;  // 1 or A
      4'd2: slot_requirement = 4'd2;
      4'd3: slot_requirement = 4'd3;
      4'd4: slot_requirement = 4'd4;  // 4 or any wild (handled elsewhere)
      default: slot_requirement = 4'd0;
    endcase
  endfunction

  function [3:0] lowest_open_slot (input [3:0] filled_mask);
    // Returns 1..4 of lowest open slot, 4'd0 if none open
    lowest_open_slot = 4'd0;
    if (!filled_mask[0]) lowest_open_slot = 4'd1;
    else if (!filled_mask[1]) lowest_open_slot = 4'd2;
    else if (!filled_mask[2]) lowest_open_slot = 4'd3;
    else if (!filled_mask[3]) lowest_open_slot = 4'd4;
  endfunction

  // Combinational next state logic
  always @(*) begin
    next_state = state;
    if (!rst_n) begin
      next_state = ST_IDLE;
    end else if (!game_active) begin
      next_state = ST_DONE;
    end else begin
      case (state)
        ST_IDLE:   next_state = (card_valid ? ST_DEAL : ST_IDLE);
        ST_DEAL: begin
          if (dealt_count == 8) next_state = ST_THETA_START;
          else next_state = ST_DEAL;
        end
        ST_THETA_START: next_state = (card_valid ? ST_THETA_PROC : ST_THETA_START);
        ST_THETA_PROC:  next_state = (theta_slots == 4'b1111) ? ST_DONE : ST_FRIEND_START;
        ST_FRIEND_START: next_state = (card_valid ? ST_FRIEND_PROC : ST_FRIEND_START);
        ST_FRIEND_PROC:  next_state = (friend_slots == 4'b1111) ? ST_DONE : ST_THETA_START;
        ST_DONE: next_state = ST_DONE;
        default: next_state = ST_IDLE;
      endcase
    end
  end

  // Sequential logic: state update, registered inputs, dealing, and gameplay
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset outputs and state
      theta_win <= 1'b0;
      friend_win <= 1'b0;
      state <= ST_IDLE;
      dealt_count <= 8'd0;
      theta_slots <= 4'd0;
      friend_slots <= 4'd0;
      card_reg <= 4'd0;
      game_active <= 1'b0;
      theta_buf[0] <= 4'd0; theta_buf[1] <= 4'd0; theta_buf[2] <= 4'd0; theta_buf[3] <= 4'd0;
      friend_buf[0] <= 4'd0; friend_buf[1] <= 4'd0; friend_buf[2] <= 4'd0; friend_buf[3] <= 4'd0;
    end else begin
      // Update state
      state <= next_state;

      // Default: no win
      theta_win <= 1'b0;
      friend_win <= 1'b0;

      // Registered sampled card (sampled only when a card_valid arrives during relevant phases)
      if (card_valid && (state == ST_DEAL || state == ST_THETA_START || state == ST_FRIEND_START)) begin
        card_reg <= ascii_to_rank({4'b0000, card_in});
      end

      // Game control
      if (state == ST_IDLE) begin
        game_active <= 1'b0;
      end else if (state == ST_DEAL) begin
        game_active <= 1'b1;
      end

      // Dealing: first 4 to Theta, next 4 to Friend
      if (state == ST_DEAL && card_valid) begin
        if (dealt_count < 4) begin
          theta_buf[dealt_count] <= ascii_to_rank({4'b0000, card_in});
        end else begin
          friend_buf[dealt_count - 4] <= ascii_to_rank({4'b0000, card_in});
        end
        dealt_count <= dealt_count + 1;
      end

      // Theta processing
      if (state == ST_THETA_PROC && card_valid) begin
        if (card_reg == 4'd11) begin
          // Jack: use lowest available slot
          if (theta_slots != 4'b1111) begin
            theta_slots <= theta_slots | (1 << (lowest_open_slot(theta_slots) - 1));
          end
        end else begin
          // Match by slot requirement (A/1 both map to 1 or 14 -> rank 1 for slot 1)
          if ((card_reg == slot_requirement(1)) && !theta_slots[0]) begin
            theta_slots[0] <= 1'b1;
          end else if ((card_reg == slot_requirement(2)) && !theta_slots[1]) begin
            theta_slots[1] <= 1'b1;
          end else if ((card_reg == slot_requirement(3)) && !theta_slots[2]) begin
            theta_slots[2] <= 1'b1;
          end else if ((card_reg == slot_requirement(4)) && !theta_slots[3]) begin
            theta_slots[3] <= 1'b1;
          end
          // else: invalid card -> discarded
        end
        if (theta_slots == 4'b1111) begin
          theta_win <= 1'b1;
          friend_win <= 1'b0;
          game_active <= 1'b0;
        end
      end

      // Friend processing
      if (state == ST_FRIEND_PROC && card_valid) begin
        if (card_reg == 4'd11) begin
          // Jack: use lowest available slot (optimal per requirement)
          if (friend_slots != 4'b1111) begin
            friend_slots <= friend_slots | (1 << (lowest_open_slot(friend_slots) - 1));
          end
        end else begin
          if ((card_reg == slot_requirement(1)) && !friend_slots[0]) begin
            friend_slots[0] <= 1'b1;
          end else if ((card_reg == slot_requirement(2)) && !friend_slots[1]) begin
            friend_slots[1] <= 1'b1;
          end else if ((card_reg == slot_requirement(3)) && !friend_slots[2]) begin
            friend_slots[2] <= 1'b1;
          end else if ((card_reg == slot_requirement(4)) && !friend_slots[3]) begin
            friend_slots[3] <= 1'b1;
          end
          // else: invalid -> discarded
        end
        if (friend_slots == 4'b1111) begin
          friend_win <= 1'b1;
          theta_win <= 1'b0;
          game_active <= 1'b0;
        end
      end

      // Latch done state when someone wins (optional safety)
      if (state == ST_DONE) begin
        game_active <= 1'b0;
      end
    end
  end

endmodule
