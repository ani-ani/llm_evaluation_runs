module first_digit (
  input clk,
  input rst_n,
  input start,
  input [31:0] num,
  output reg [3:0] first_digit,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALCULATING,
    DONE
  } state_t;

  state_t state, next_state;
  reg [31:0] current_value;
  reg [31:0] temp_value;
  reg [31:0] subtract_counter;
  reg [3:0] digit_counter;
  reg [31:0] remainder;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_value <= 0;
      temp_value <= 0;
      subtract_counter <= 0;
      digit_counter <= 0;
      remainder <= 0;
      first_digit <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CALCULATING;
          current_value = num;
          temp_value = num;
          subtract_counter = 0;
          digit_counter = 0;
          remainder = 0;
          done = 0;
        end
      end
      CALCULATING: begin
        if (current_value < 10) begin
          next_state = DONE;
          first_digit = current_value;
          done = 1;
        end else begin
          // Implement division by 10 through repeated subtraction
          if (temp_value >= 10) begin
            temp_value = temp_value - 10;
            subtract_counter = subtract_counter + 1;
          end else begin
            // Found remainder, move to next decade
            remainder = temp_value;
            current_value = subtract_counter;
            temp_value = current_value;
            subtract_counter = 0;
          end
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

endmodule