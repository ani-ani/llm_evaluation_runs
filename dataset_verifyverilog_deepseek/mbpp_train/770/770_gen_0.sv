module odd_power_sum(
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg [39:0] sum = 0,
  output reg done = 0
);

  reg [7:0] n_reg;
  reg [7:0] count;
  reg computing;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum <= 0;
      done <= 0;
      computing <= 0;
      count <= 0;
      n_reg <= 0;
    end else begin
      if (start) begin
        n_reg <= n;
        count <= 0;
        sum <= 0;
        done <= 0;
        if (n == 0) begin
          done <= 1;
          computing <= 0;
        end else begin
          computing <= 1;
        end
      end else if (computing) begin
        logic [8:0] odd_num = 2 * count + 1;
        logic [17:0] odd_sq = odd_num * odd_num;
        logic [35:0] term = odd_sq * odd_sq;
        sum <= sum + term;
        count <= count + 1;
        if ((count + 1) == n_reg) begin
          computing <= 0;
          done <= 1;
        end
      end
    end
  end

endmodule