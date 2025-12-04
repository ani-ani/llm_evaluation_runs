module trash_game(
  input clk,
  input rst_n,
  input [3:0] card_in,
  input card_valid,
  output reg theta_win,
  output reg friend_win
);

  typedef enum {
    INIT,
    LOAD_THETA,
    LOAD_FRIEND,
    THETA_TURN_START,
    FRIEND_TURN_START,
    DRAW,
    PROCESS,
    CHECK_WIN,
    WIN
  } state_t;

  state_t state;
  reg [2:0] load_counter;
  reg current_player;
  reg [3:0] theta_slots_filled;
  reg [3:0] friend_slots_filled;
  reg [3:0] current_card;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= INIT;
      load_counter <= 0;
      theta_slots_filled <= 0;
      friend_slots_filled <= 0;
      current_player <= 0;
      theta_win <= 0;
      friend_win <= 0;
      current_card <= 0;
    end else begin
      case (state)
        INIT: state <= LOAD_THETA;

        LOAD_THETA: begin
          if (card_valid) begin
            load_counter <= load_counter + 1;
            if (load_counter == 3)
              state <= LOAD_FRIEND;
          end
        end

        LOAD_FRIEND: begin
          if (card_valid) begin
            load_counter <= load_counter + 1;
            if (load_counter == 7) begin
              state <= THETA_TURN_START;
              current_player <= 0;
            end
          end
        end

        THETA_TURN_START: state <= DRAW;
        FRIEND_TURN_START: state <= DRAW;

        DRAW: begin
          if (card_valid) begin
            current_card <= card_in;
            state <= PROCESS;
          end
        end

        PROCESS: begin
          if (current_card == 4'hC) begin  // Jack
            if (current_player == 0) begin
              if (!theta_slots_filled[0])       theta_slots_filled[0] <= 1'b1;
              else if (!theta_slots_filled[1])  theta_slots_filled[1] <= 1'b1;
              else if (!theta_slots_filled[2])  theta_slots_filled[2] <= 1'b1;
              else if (!theta_slots_filled[3])  theta_slots_filled[3] <= 1'b1;
            end else begin
              if (!friend_slots_filled[0])      friend_slots_filled[0] <= 1'b1;
              else if (!friend_slots_filled[1]) friend_slots_filled[1] <= 1'b1;
              else if (!friend_slots_filled[2]) friend_slots_filled[2] <= 1'b1;
              else if (!friend_slots_filled[3]) friend_slots_filled[3] <= 1'b1;
            end
          end else begin
            if (current_player == 0) begin
              if (!theta_slots_filled[0] && 
                 (current_card == 4'h1 || current_card == 4'hA)) // Slot 1
                theta_slots_filled[0] <= 1'b1;
              else if (!theta_slots_filled[1] && current_card == 4'h2) // Slot 2
                theta_slots_filled[1] <= 1'b1;
              else if (!theta_slots_filled[2] && current_card == 4'h3) // Slot 3
                theta_slots_filled[2] <= 1'b1;
              else if (!theta_slots_filled[3] && current_card == 4'h4) // Slot 4
                theta_slots_filled[3] <= 1'b1;
            end else begin
              if (!friend_slots_filled[0] && 
                 (current_card == 4'h1 || current_card == 4'hA))
                friend_slots_filled[0] <= 1'b1;
              else if (!friend_slots_filled[1] && current_card == 4'h2)
                friend_slots_filled[1] <= 1'b1;
              else if (!friend_slots_filled[2] && current_card == 4'h3)
                friend_slots_filled[2] <= 1'b1;
              else if (!friend_slots_filled[3] && current_card == 4'h4)
                friend_slots_filled[3] <= 1'b1;
            end
          end
          state <= CHECK_WIN;
        end

        CHECK_WIN: begin
          if (current_player == 0) begin
            if (theta_slots_filled == 4'b1111) begin
              theta_win <= 1'b1;
              state <= WIN;
            end else begin
              current_player <= 1;
              state <= FRIEND_TURN_START;
            end
          end else begin
            if (friend_slots_filled == 4'b1111) begin
              friend_win <= 1'b1;
              state <= WIN;
            end else begin
              current_player <= 0;
              state <= THETA_TURN_START;
            end
          end
        end

        WIN: ; // Stay here

        default: state <= INIT;
      endcase
    end
  end
endmodule