module biggest_even(
  input      [15:0] x,
  input      [15:0] y,
  output reg signed [15:0] result
);

  always @* begin
    if (x > y) begin
      result = -16'sd1;
    end else if ((y & 16'h0001) == 16'h0000) begin
      // y is even
      result = $signed(y);
    end else if ((y - 16'd1) >= x) begin
      // y is odd, check y-1
      result = $signed(y - 16'd1);
    end else begin
      result = -16'sd1;
    end
  end

endmodule