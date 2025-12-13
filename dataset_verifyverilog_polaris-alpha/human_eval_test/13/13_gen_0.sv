module gcd_calculator(
  input        clk,
  input        rst_n,
  input        start,
  input  [15:0] a,
  input  [15:0] b,
  output reg [15:0] result,
  output reg       done
);

  reg [15:0] a_reg;
  reg [15:0] b_reg;
  reg        busy;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_reg  <= 16'd0;
      b_reg  <= 16'd0;
      result <= 16'd0;
      done   <= 1'b1;
      busy   <= 1'b0;
    end else begin
      if (start && !busy) begin
        // Start new computation
        a_reg  <= a;
        b_reg  <= b;
        done   <= 1'b0;
        busy   <= 1'b1;
      end else if (busy) begin
        if (b_reg == 16'd0) begin
          // Computation complete
          result <= a_reg;
          done   <= 1'b1;
          busy   <= 1'b0;
        end else begin
          // Euclid's algorithm using subtraction and conditional swap
          if (b_reg > a_reg) begin
            // swap a_reg and b_reg
            a_reg <= b_reg;
            b_reg <= a_reg;
          end else begin
            a_reg <= a_reg - b_reg;
          end
        end
      end
    end
  end

endmodule