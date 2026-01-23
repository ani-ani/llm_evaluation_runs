module otherside_rightangle (
  input clk,
  input rst_n,
  input start,
  input [31:0] w,
  input [31:0] h,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] SQUARING = 3'b001;
  localparam [2:0] ADDING = 3'b010;
  localparam [2:0] SQRT = 3'b011;
  localparam [2:0] DONE = 3'b100;

  reg [2:0] state = IDLE;
  reg [31:0] w_sq, h_sq, sum;
  reg [63:0] remainder;
  reg [31:0] sqrt_result;
  reg [4:0] sqrt_iter = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 32'b0;
      done <= 1'b0;
      sqrt_iter <= 5'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SQUARING;
          end
        end

        SQUARING: begin
          // Compute squares and normalize to Q16.16
          w_sq <= (w * w) >> 16;
          h_sq <= (h * h) >> 16;
          state <= ADDING;
        end

        ADDING: begin
          sum <= w_sq + h_sq;
          // Prepare for sqrt: shift sum left by 16 to make it Q32.0
          remainder <= {sum, 32'b0};
          sqrt_result <= 32'b0;
          sqrt_iter <= 5'b0;
          state <= SQRT;
        end

        SQRT: begin
          if (sqrt_iter < 32) begin
            // Iterative restoring square root algorithm
            reg [63:0] temp_remainder;
            reg [31:0] temp_result;
            reg [31:0] temp_val;

            temp_result = sqrt_result | (1 << (31 - sqrt_iter));
            temp_val = (temp_result << 1) + 1;
            temp_remainder = remainder - (temp_val << (62 - 2*sqrt_iter));

            if (temp_remainder[63] == 0) begin
              remainder <= temp_remainder << 2;
              sqrt_result <= temp_result;
            end else begin
              remainder <= remainder << 2;
              sqrt_result <= sqrt_result;
            end

            sqrt_iter <= sqrt_iter + 1;
          end else begin
            // Final result: shift left by 16 to get Q16.16
            result <= sqrt_result << 16;
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule