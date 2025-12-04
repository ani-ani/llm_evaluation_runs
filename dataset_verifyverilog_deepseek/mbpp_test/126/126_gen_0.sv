module common_divisor_sum(input clk, input rst_n, input start, input [7:0] a, input [7:0] b, output reg [7:0] sum, output reg done);
  reg busy;
  reg [7:0] counter;
  reg [7:0] min_reg;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum <= 8'd0;
      done <= 1'b0;
      busy <= 1'b0;
      counter <= 8'd0;
      min_reg <= 8'd0;
    end else begin
      done <= 1'b0;
      if (busy) begin
        if (counter <= min_reg) begin
          if ((a % counter == 8'd0) && (b % counter == 8'd0)) begin
            sum <= sum + counter;
          end
          counter <= counter + 8'd1;
        end else begin
          done <= 1'b1;
          busy <= 1'b0;
        end
      end else if (start) begin
        busy <= 1'b1;
        sum <= 8'd0;
        counter <= 8'd1;
        min_reg <= (a < b) ? a : b;
      end
    end
  end
endmodule