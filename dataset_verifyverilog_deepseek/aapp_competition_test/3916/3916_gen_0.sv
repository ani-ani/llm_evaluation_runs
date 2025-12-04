module example (input clk, input rst, output reg [7:0] counter);
  reg [7:0] count;
  always @(posedge clk or posedge rst) begin
    if (rst)
      count <= 8'd0;
    else
      count <= count + 1;
  end
  assign counter = count;
endmodule