module snowblower_area(input clk, input rst_n, input start, input [63:0] max_sq, input [63:0] min_sq, output reg [63:0] diff);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) diff <= 64'h0;
    else if (start) diff <= max_sq - min_sq;
  end
endmodule