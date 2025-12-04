module series_sum (
  input clk,
  input rst_n,
  input start,
  input [4:0] n_in,
  output reg [7:0] sum,
  output reg done
);

  reg [4:0] work;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum <= 8'h0;
      done <= 1'b0;
      work <= 5'h0;
    end else begin
      if (start) begin
        sum <= n_in;
        work <= (n_in >= 5'h2) ? (n_in - 5'h2) : 5'h0;
        done <= (n_in <= 5'h1);
      end else begin
        done <= 1'b0;
        if (work != 5'h0) begin
          sum <= sum + work;
          work <= (work >= 5'h2) ? (work - 5'h2) : 5'h0;
          if (work <= 5'h2) done <= 1'b1;
        end
      end
    end
  end

endmodule