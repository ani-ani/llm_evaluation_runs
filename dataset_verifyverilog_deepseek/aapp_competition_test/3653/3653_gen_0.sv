module dog_chain_calculator(
  input clk,
  input rst_n,
  input start,
  input [11:0] L,
  output reg [7:0] chain_length,
  output reg done
);

  localparam [2:0] IDLE  = 3'd0,
                  COMPUTE = 3'd1,
                  DIVIDE  = 3'd2,
                  SQRT    = 3'd3,
                  DONE    = 3'd4;

  reg [2:0] state, next_state;
  reg [19:0] temp;
  reg [10:0] quotient;
  reg [10:0] target_value;
  reg [7:0] r_reg;
  reg [3:0] cycle;

  // Division temporary registers
  reg [19:0] dividend;
  reg [8:0] divisor;
  reg [10:0] div_quotient;
  reg [19:0] remainder;
  reg [4:0] div_step;

  // Square root temporary registers
  reg [7:0] low, high, mid;
  reg [4:0] sqrt_step;
  wire [15:0] mid_sq = mid * mid;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      chain_length <= 0;
      cycle <= 0;
    end else begin
      cycle <= (state == IDLE) ? 0 : cycle + 1;
      done <= 0;

      case (state)
        IDLE: begin
          if (start) begin
            next_state <= COMPUTE;
            cycle <= 0;
          end
        end

        COMPUTE: begin
          temp <= L * 12'd226;
          next_state <= DIVIDE;
        end

        DIVIDE: begin
          if (cycle == 1) begin
            dividend <= temp;
            divisor <= 9'd355;
            div_quotient <= 0;
            remainder <= 0;
            div_step <= 0;
          end

          if (div_step < 20) begin
            remainder = {remainder[18:0], dividend[19]} << 1;
            dividend <= dividend << 1;
            if (remainder >= divisor) begin
              remainder <= remainder - divisor;
              div_quotient <= {div_quotient[9:0], 1'b1};
            end else begin
              div_quotient <= {div_quotient[9:0], 1'b0};
            end
            div_step <= div_step + 1;
          end else begin
            if (remainder != 0) quotient <= div_quotient + 1;
            else quotient <= div_quotient;
            next_state <= SQRT;
          end
        end

        SQRT: begin
          if (cycle == 7) begin
            target_value <= quotient;
            low <= 0;
            high <= 8'h80;
            sqrt_step <= 0;
          end

          // Binary search sqrt implementation (3 steps)
          if (sqrt_step < 3) begin
            mid <= (low + high) >> 1;
            if (mid_sq < target_value) low <= mid + 1;
            else high <= mid;
            sqrt_step <= sqrt_step + 1;
          end else begin
            chain_length <= high;
            next_state <= DONE;
          end
        end

        DONE: begin
          done <= 1;
          next_state <= IDLE;
        end

        default: next_state <= IDLE;
      endcase
      state <= next_state;
    end
  end
endmodule