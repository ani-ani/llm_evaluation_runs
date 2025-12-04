module below_threshold (input reg [7:0] threshold,
  input reg [3:0][7:0] l,
  output reg result);
  always @* begin
    result = (l[0] < threshold) && (l[1] < threshold) && (l[2] < threshold) && (l[3] < threshold);
  end
endmodule