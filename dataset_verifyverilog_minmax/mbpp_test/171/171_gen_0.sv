module perimeter_pentagon (
  input [7:0] a,
  output reg [10:0] perimeter
);
  always @* begin
    perimeter = 5 * a;
  end
endmodule