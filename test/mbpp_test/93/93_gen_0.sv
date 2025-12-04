module power_calculator(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0] a,
  input  [3:0] b,
  output reg [31:0] result,
  output reg done
);

  // Internal state
  reg [3:0] base_reg;
  reg [3:0] exp_reg;
  reg       busy;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result   <= 32'd1;
      done     <= 1'b0;
      busy     <= 1'b0;
      base_reg <= 4'd0;
      exp_reg  <= 4'd0;
    end else begin
      // Default done low unless set when operation completes
      if (!start && !busy)
        done <= 1'b0;

      if (start && !busy) begin
        // Latch inputs and handle special cases
        base_reg <= a;
        exp_reg  <= b;
        busy     <= 1'b0;

        if (b == 4'd0) begin
          // a^0 = 1 (including 0^0 -> 1 per spec)
          result <= 32'd1;
          done   <= 1'b1;
        end else if (a == 4'd0) begin
          // 0^b = 0 for b>0
          result <= 32'd0;
          done   <= 1'b1;
        end else begin
          // Normal iterative case
          result   <= 32'd1;
          exp_reg  <= b;
          base_reg <= a;
          busy     <= 1'b1;
          done     <= 1'b0;
        end
      end else if (busy) begin
        // Iterative multiplication: perform one multiply per cycle
        result <= result * base_reg;

        if (exp_reg == 4'd1) begin
          // Last iteration just completed
          busy <= 1'b0;
          done <= 1'b1;
        end

        exp_reg <= exp_reg - 4'd1;
      end
    end
  end

endmodule