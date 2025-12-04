module snowblower_area(
  input clk,
  input rst_n,
  input start,
  input [63:0] max_sq,
  input [63:0] min_sq,
  output reg [63:0] diff
);

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    diff <= 64'd0;
  end else if (start) begin
    diff <= max_sq - min_sq;
  end
end

endmodule