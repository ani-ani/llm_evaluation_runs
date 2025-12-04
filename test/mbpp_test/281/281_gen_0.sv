module unique_checker(
  input  [3:0] data [0:3],
  output reg   is_unique
);

  wire eq_01 = (data[0] == data[1]);
  wire eq_02 = (data[0] == data[2]);
  wire eq_03 = (data[0] == data[3]);
  wire eq_12 = (data[1] == data[2]);
  wire eq_13 = (data[1] == data[3]);
  wire eq_23 = (data[2] == data[3]);

  wire any_equal = eq_01 | eq_02 | eq_03 | eq_12 | eq_13 | eq_23;

  always @(*) begin
    is_unique = ~any_equal;
  end

endmodule