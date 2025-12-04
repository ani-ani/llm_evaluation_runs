module ab_pattern_matcher(input clk, input rst_n, input start, input [7:0] data, input valid, output reg match, output reg done);
  typedef enum logic [1:0] {IDLE, SEARCH_A, SEARCH_B, FINISH} state_t;
  state_t state, next_state;
  reg [3:0] counter;
  reg found;
  reg done_next, match_next;
  
  always_comb begin
    next_state = state;
    done_next = 0;
    match_next = 0;
    case (state)
      IDLE:   if (start) next_state = SEARCH_A;
      SEARCH_A: begin
        if (valid) begin
          if (counter == 4'd15) next_state = FINISH;
          else next_state = (data == 8'h61) ? SEARCH_B : SEARCH_A;
        end
        else next_state = FINISH;
      end
      SEARCH_B: begin
        if (valid) begin
          if (counter == 4'd15) next_state = FINISH;
          else next_state = (data == 8'h62) ? SEARCH_B : SEARCH_A;
        end
        else next_state = FINISH;
      end
      FINISH: begin
        next_state = IDLE;
        done_next = 1;
        match_next = found;
      end
      default: next_state = IDLE;
    endcase
  end
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      found <= 0;
      counter <= 0;
      done <= 0;
      match <= 0;
    end else begin
      state <= next_state;
      done <= done_next;
      match <= match_next;
      if (state == IDLE && start) begin
        counter <= 0;
        found <= 0;
      end else if (state != IDLE && state != FINISH && valid) begin
        counter <= counter + 1;
      end
      if ((state == SEARCH_B) && valid && (data == 8'h62)) begin
        found <= 1;  
      end
    end
  end
endmodule