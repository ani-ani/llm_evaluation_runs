module even_power_sum (
  input clk,
  input rst_n,
  input [4:0] n,
  input start,
  output reg [29:0] sum,
  output reg done
);
  reg busy;
  reg [5:0] counter;
  reg [4:0] n_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy <= 1'b0;
      done <= 1'b0;
      counter <= 6'd0;
      n_reg <= 5'd0;
      sum <= 30'd0;
    end else begin
      if (busy) begin
        if (counter < n_reg) begin
          sum <= sum + (32 * ((counter + 6'd1) ** 5));
          counter <= counter + 6'd1;
        end else if (counter == n_reg) begin
          done <= 1'b1;
          busy <= 1'b0;
        end
      end else begin
        if (start) begin
          busy <= 1'b1;
          done <= 1'b0;
          counter <= 6'd0;
          n_reg <= n;
          sum <= 30'd0;
        end
      end
    end
  end
endmodule