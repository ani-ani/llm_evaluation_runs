module three_equal_counter (
  input signed [7:0] x,
  input signed [7:0] y,
  input signed [7:0] z,
  output reg [2:0] count
);

  wire xy_equal = (x == y);
  wire yz_equal = (y == z);
  wire xz_equal = (x == z);

  always @* begin
    if (xy_equal && yz_equal) begin
      count = 3'b011; // All three equal
    end
    else if (xy_equal || yz_equal || xz_equal) begin
      count = 3'b010; // Two equal
    end
    else begin
      count = 3'b000; // All distinct
    end
  end

endmodule