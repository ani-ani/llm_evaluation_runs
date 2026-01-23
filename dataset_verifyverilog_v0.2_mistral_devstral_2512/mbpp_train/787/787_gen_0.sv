module pattern_matcher (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input valid_in,
  output reg match,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE,
    S_A,
    S_B1,
    S_B2,
    S_B3,
    MATCH,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [3:0] char_counter;

  // State transition logic
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (!rst_n || start) next_state = IDLE;
        else if (valid_in && char_in == 8'h61) next_state = S_B1;
        else if (valid_in) next_state = S_A;
      end
      S_A: begin
        if (!rst_n || start) next_state = IDLE;
        else if (valid_in && char_in == 8'h61) next_state = S_B1;
        else if (valid_in && char_in == 8'h62) next_state = S_B1;
        else if (valid_in) next_state = S_A;
      end
      S_B1: begin
        if (!rst_n || start) next_state = IDLE;
        else if (valid_in && char_in == 8'h62) next_state = S_B2;
        else if (valid_in && char_in == 8'h61) next_state = S_B1;
        else if (valid_in) next_state = S_A;
      end
      S_B2: begin
        if (!rst_n || start) next_state = IDLE;
        else if (valid_in && char_in == 8'h62) next_state = S_B3;
        else if (valid_in && char_in == 8'h61) next_state = S_B1;
        else if (valid_in) next_state = S_A;
      end
      S_B3: begin
        if (!rst_n || start) next_state = IDLE;
        else if (valid_in && char_in == 8'h62) next_state = MATCH;
        else if (valid_in && char_in == 8'h61) next_state = S_B1;
        else if (valid_in) next_state = S_A;
      end
      MATCH: begin
        if (!rst_n || start) next_state = IDLE;
        else next_state = MATCH;
      end
      DONE: begin
        if (!rst_n || start) next_state = IDLE;
        else next_state = DONE;
      end
    endcase
  end

  // Counter logic
  always_comb begin
    if (!rst_n || start) char_counter = 4'h0;
    else if (valid_in && current_state != DONE && current_state != MATCH) begin
      if (char_counter == 4'hF) char_counter = 4'hF;
      else char_counter = char_counter + 1'b1;
    end
  end

  // State update and output logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      char_counter <= 4'h0;
      match <= 1'b0;
      done <= 1'b0;
    end
    else begin
      current_state <= next_state;
      if (next_state == MATCH) match <= 1'b1;
      else if (start) match <= 1'b0;
      else match <= match;

      if (char_counter == 4'hF && valid_in && current_state != DONE && current_state != MATCH) done <= 1'b1;
      else if (start) done <= 1'b0;
      else done <= done;
    end
  end

endmodule