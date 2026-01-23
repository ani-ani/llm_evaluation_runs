module round_and_sum (
  input clk,
  input rst_n,
  input start,
  input [2:0] list_length,
  input [31:0] list_data [0:7],
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD,
    ROUNDING,
    SUMMING,
    MULTIPLYING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Intermediate registers
  reg [31:0] rounded_values [0:7];
  reg [31:0] sum;
  reg [47:0] product;
  reg [2:0] current_index;

  // Constants
  parameter ROUND_VALUE = 16'h8000; // 0.5 in Q16.16

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      result <= 32'b0;
      current_index <= 3'b0;
      sum <= 32'b0;
      product <= 48'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      LOAD: next_state = ROUNDING;
      ROUNDING: begin
        if (current_index == list_length - 1) next_state = SUMMING;
      end
      SUMMING: next_state = MULTIPLYING;
      MULTIPLYING: next_state = DONE;
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_index <= 3'b0;
      sum <= 32'b0;
      product <= 48'b0;
    end else begin
      case (current_state)
        LOAD: begin
          current_index <= 3'b0;
          sum <= 32'b0;
          product <= 48'b0;
        end
        ROUNDING: begin
          // Round each element
          rounded_values[current_index] <= (list_data[current_index] + ROUND_VALUE) >>> 16;
          current_index <= current_index + 1'b1;
        end
        SUMMING: begin
          // Sum all rounded values
          for (int i = 0; i < 8; i = i + 1) begin
            if (i < list_length) begin
              sum <= sum + rounded_values[i];
            end
          end
        end
        MULTIPLYING: begin
          // Multiply sum by list_length (48-bit result)
          product <= sum * list_length;
          // Convert back to Q16.16 by shifting left 16 bits
          result <= product << 16;
        end
        DONE: done <= 1'b1;
        default: begin
          done <= 1'b0;
          result <= 32'b0;
        end
      endcase
    end
  end

endmodule