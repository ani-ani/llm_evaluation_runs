module knight_arrangements(input clk, input rst_n, input start, input [1:0] n, input [3:0] m, output reg [29:0] result, output reg done);

reg [29:0] result;
reg done;
reg [2:0] state;

always @(posedge clk) begin
   if (!rst_n) begin
      result <= 0;
      done <= 0;
      state <= 0;
   end else begin
      result <= 0;
      done <= 0;
      if (state == 0) begin
          if (start) begin
              state <= 1;
          end
      end
   end
end
endmodule