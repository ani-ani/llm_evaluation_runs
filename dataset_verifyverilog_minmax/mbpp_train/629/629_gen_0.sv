module even_filter (
  input reg [63:0] nums,
  output [7:0] mask
);

genvar i;
generate
  for (i=0; i<8; i=i+1) begin
    assign mask[i] = ~nums[i*8];
  end
endgenerate

endmodule