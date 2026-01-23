module last_digit (
  input clk,
  input rst_n,
  input start,
  input [31:0] number,
  output reg [3:0] last_digit,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  // Internal registers
  reg [1:0] state;
  reg [31:0] num_reg;
  reg [31:0] temp_num;
  reg [4:0] shift_count;
  reg [3:0] remainder;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      state <= IDLE;
      num_reg <= 32'b0;
      temp_num <= 32'b0;
      shift_count <= 5'b0;
      remainder <= 4'b0;
      last_digit <= 4'b0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Load input number and start processing
            num_reg <= number;
            temp_num <= number;
            shift_count <= 5'b0;
            remainder <= 4'b0;
            state <= PROCESSING;
          end
        end

        PROCESSING: begin
          if (shift_count < 32) begin
            // Shift-and-subtract method
            if (temp_num[0]) begin
              remainder <= remainder + 1;
            end
            temp_num <= temp_num >> 1;
            shift_count <= shift_count + 1;
          end else begin
            // Compute remainder (n - 10*floor(n/10))
            if (remainder >= 10) begin
              remainder <= remainder - 10;
            end else begin
              // Final result
              last_digit <= remainder;
              done <= 1'b1;
              state <= DONE;
            end
          end
        end

        DONE: begin
          // Return to IDLE on next cycle
          state <= IDLE;
          done <= 1'b0;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule