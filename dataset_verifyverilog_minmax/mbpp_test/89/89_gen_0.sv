module closest_num(
  input [7:0] N,
  output reg [7:0] result
);

  always @* begin
    result = N - 1; // Unsigned arithmetic wraps: N=0 -> 255
  end

endmodule