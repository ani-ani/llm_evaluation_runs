module fibfib_calculator(input clk, input rst_n, input [3:0] n, input start, output reg [11:0] result, output reg done);
  reg [3:0] latched_n;
  reg [3:0] counter;
  reg [11:0] a, b, c;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a <= 12'b0;
      b <= 12'b0;
      c <= 12'b1;
      latched_n <= 4'b0;
      counter <= 4'b0;
      done <= 1'b0;
      result <= 12'b0;
    end else begin
      done <= 1'b0;
      if (start) begin
        latched_n <= n;
        counter <= 4'b0;
        a <= 12'b0;
        b <= 12'b0;
        c <= 12'b1;
      end else begin
        if (counter < latched_n) begin
          if (counter >= 4'd2) begin
            a <= b;
            b <= c;
            c <= a + b + c;
          end
          counter <= counter + 1;
        end else if (counter == latched_n) begin
          if (latched_n == 0) result <= a;
          else if (latched_n == 1) result <= b;
          else result <= c;
          done <= 1'b1;
          counter <= counter + 1;
        end
      end
    end
  end
endmodule
