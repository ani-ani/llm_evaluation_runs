module divisor_counter(input clk, input rst_n, input start, input [7:0] n, output reg [7:0] count, output reg done);
  reg active;
  reg [7:0] i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 8'h00;
      done <= 1'b0;
      active <= 1'b0;
      i <= 8'h00;
    end else begin
      done <= 1'b0;
      if (start) begin
        if (n == 8'h00) begin
          count <= 8'h00;
          done <= 1'b1;
          active <= 1'b0;
          i <= 8'h00;
        end else begin
          count <= 8'h00;
          active <= 1'b1;
          i <= 8'h01;
        end
      end else if (active) begin
        if (i <= n) begin
          if ((n % i) == 0) count <= count + 8'h01;
          if (i == n) begin
            done <= 1'b1;
            active <= 1'b0;
          end else begin
            i <= i + 8'h01;
          end
        end else active <= 1'b0;
      end
    end
  end
endmodule