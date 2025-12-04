module counter (input clk, reset, input [7:0] count_limit, output reg [7:0] count);
  always @(posedge clk or posedge reset) begin
    if (reset)
      count <= 8'h00;
    else if (count == count_limit)
      count <= 8'h00;
    else
      count <= count + 1;
  end
endmodule