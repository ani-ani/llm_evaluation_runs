module median_of_three(
  input [7:0] a,
  input [7:0] b,
  input [7:0] c,
  output reg [7:0] median
);

  always @(*) begin
    if (a > b) begin
      if (a < c) median = a;
      else if (b > c) median = b;
      else median = c;
    end
    else begin
      if (a > c) median = a;
      else if (b < c) median = b;
      else median = c;
    end
  end

endmodule