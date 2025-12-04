module biggest_even(
  input wire [15:0] x,
  input wire [15:0] y,
  output reg signed [15:0] result
);

  always_comb begin
    if (x > y) begin
      result = -1;
    end else if (y[0] == 1'b0) begin
      result = y;
    end else if ((y - 1) >= x) begin
      result = y - 1;
    end else begin
      result = -1;
    end
  end

endmodule