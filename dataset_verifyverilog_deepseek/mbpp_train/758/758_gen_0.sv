module counter (input clk, reset, input [7:0] count_to, output reg [7:0] count);
  always @(posedge clk or posedge reset) begin
    if (reset)
      count <= 8'd0;
    else if (count == count_to)
      count <= 8'd0;
    else
      count <= count + 1;
  end
endmodule