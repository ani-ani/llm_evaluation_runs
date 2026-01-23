module trash_game(
  input clk,
  input rst_n,
  input start,
  input [415:0] deck,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    INIT,
    TURN_START,
    DRAW,
    JACK,
    UNCOVER,
    DISCARD,
    SWITCH,
    WIN
  } state_t;
  state_t state, next_state;

  // Player and turn tracking
  reg current_player; // 0: Theta, 1: Friend
  reg [3:0] turn_count;

  // Card slots
  reg [3:0] theta_slots [0:9];
  reg [3:0] friend_slots [0:9];

  // Revealed cards
  reg [13:0] theta_revealed;
  reg [13:0] friend_revealed;
  reg [13:0] discard_revealed;

  // Deck pointer and current card
  reg [5:0] deck_ptr;
  reg [3:0] current_card;

  // Initial hands
  reg [3:0] theta_initial_hand [0:19];
  reg [3:0] friend_initial_hand [0:19];

  // Helper functions
  function automatic bit is_slot_filled;
    input [3:0] slots [0:9];
    integer i;
    for (i = 0; i < 10; i = i + 1) begin
      if (slots[i] == 0) return 0;
    end
    return 1;
  endfunction

  function automatic integer find_lowest_unfilled;
    input [3:0] slots [0:9];
    integer i;
    for (i = 0; i < 10; i = i + 1) begin
      if (slots[i] == 0) return i;
    end
    return -1;
  endfunction

  function automatic integer theta_jack_strategy;
    input [3:0] slots [0:9];
    input [13:0] revealed;
    input [13:0] discard;
    integer i, req, best_slot;
    best_slot = -1;
    for (i = 0; i < 10; i = i + 1) begin
      if (slots[i] == 0) begin
        req = i + 1;
        if (req <= 13 && (revealed[req] || discard[req])) begin
          if (best_slot == -1 || i < best_slot) best_slot = i;
        end
      end
    end
    if (best_slot != -1) return best_slot;
    return find_lowest_unfilled(slots);
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_player <= 0;
      turn_count <= 0;
      deck_ptr <= 0;
      current_card <= 0;
      theta_revealed <= 0;
      friend_revealed <= 0;
      discard_revealed <= 0;
      result <= 0;
      done <= 0;
      integer i;
      for (i = 0; i < 10; i = i + 1) begin
        theta_slots[i] <= 0;
        friend_slots[i] <= 0;
      end
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT;
      end
      INIT: begin
        next_state = TURN_START;
      end
      TURN_START: begin
        if (current_player == 0 && is_slot_filled(theta_slots)) begin
          next_state = WIN;
        end else if (current_player == 1 && is_slot_filled(friend_slots)) begin
          next_state = WIN;
        end else begin
          next_state = DRAW;
        end
      end
      DRAW: begin
        next_state = JACK;
      end
      JACK: begin
        if (current_card == 4'd11) begin
          if (current_player == 0) begin
            integer slot = theta_jack_strategy(theta_slots, theta_revealed, discard_revealed);
            if (slot != -1) begin
              theta_slots[slot] = 4'd11;
              theta_revealed[4'd11] = 1;
              next_state = UNCOVER;
            end else begin
              discard_revealed[4'd11] = 1;
              next_state = DISCARD;
            end
          end else begin
            integer slot = find_lowest_unfilled(friend_slots);
            if (slot != -1) begin
              friend_slots[slot] = 4'd11;
              friend_revealed[4'd11] = 1;
              next_state = UNCOVER;
            end else begin
              discard_revealed[4'd11] = 1;
              next_state = DISCARD;
            end
          end
        end else if (current_card == 4'd12 || current_card == 4'd13) begin
          discard_revealed[current_card] = 1;
          next_state = DISCARD;
        end else begin
          integer slot = current_card - 1;
          if (current_player == 0) begin
            if (theta_slots[slot] == 0) begin
              theta_slots[slot] = current_card;
              theta_revealed[current_card] = 1;
              next_state = UNCOVER;
            end else begin
              discard_revealed[current_card] = 1;
              next_state = DISCARD;
            end
          end else begin
            if (friend_slots[slot] == 0) begin
              friend_slots[slot] = current_card;
              friend_revealed[current_card] = 1;
              next_state = UNCOVER;
            end else begin
              discard_revealed[current_card] = 1;
              next_state = DISCARD;
            end
          end
        end
      end
      UNCOVER: begin
        if (current_player == 0) begin
          integer slot = find_lowest_unfilled(theta_slots);
          if (slot != -1) begin
            current_card = theta_initial_hand[slot];
            next_state = JACK;
          end else begin
            next_state = DISCARD;
          end
        end else begin
          integer slot = find_lowest_unfilled(friend_slots);
          if (slot != -1) begin
            current_card = friend_initial_hand[slot];
            next_state = JACK;
          end else begin
            next_state = DISCARD;
          end
        end
      end
      DISCARD: begin
        next_state = SWITCH;
      end
      SWITCH: begin
        current_player = ~current_player;
        turn_count = turn_count + 1;
        next_state = TURN_START;
      end
      WIN: begin
        if (current_player == 0) result = 1;
        else result = 0;
        done = 1;
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Initialization logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      integer i;
      for (i = 0; i < 20; i = i + 1) begin
        theta_initial_hand[i] <= 0;
        friend_initial_hand[i] <= 0;
      end
    end else if (state == INIT) begin
      integer i;
      for (i = 0; i < 20; i = i + 1) begin
        theta_initial_hand[i] = deck[415 - 4*i +: 4];
        friend_initial_hand[i] = deck[335 - 4*i +: 4];
      end
      deck_ptr = 20;
      turn_count = 0;
      current_player = 0;
      theta_revealed = 0;
      friend_revealed = 0;
      discard_revealed = 0;
      result = 0;
      done = 0;
      for (i = 0; i < 10; i = i + 1) begin
        theta_slots[i] = 0;
        friend_slots[i] = 0;
      end
    end
  end

  // Draw card logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_card <= 0;
    end else if (state == DRAW) begin
      current_card = deck[415 - 4*deck_ptr +: 4];
      deck_ptr = deck_ptr + 1;
    end
  end

endmodule