module next_perfect_square (
  input clk,
  input rst_n,
  input [15:0] N,
  input start,
  output reg [31:0] result,
  output reg done
);

  typedef enum logic [1:0] {IDLE, SQRT_ST, SQUARE_ST} state_t;
  reg [1:0] state;

  reg [8:0] low;
  reg [8:0] high;
  reg [15:0] stored_N;
  reg [3:0] counter;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      low <= 9'b0;
      high <= 9'b0;
      stored_N <= 16'b0;
      counter <= 4'b0;
      result <= 32'b0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            stored_N <= N;
            low <= 9'b0;
            high <= 9'd256;
            counter <= 4'd0;
            state <= SQRT_ST;
          end
        end

        SQRT_ST: begin
          if (counter == 4'd15) begin
            state <= SQUARE_ST;
          end else begin
            counter <= counter + 4'd1;
          end

          begin
            reg [8:0] mid = (low + high) >> 1;
            reg [17:0] mid_sq = mid * mid;
            if (mid_sq <= stored_N) begin
              low <= mid + 1'b1;
            end else begin
              high <= mid - 1'b1;
            end
          end
        end

        SQUARE_ST: begin
          result <= low * low;
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule