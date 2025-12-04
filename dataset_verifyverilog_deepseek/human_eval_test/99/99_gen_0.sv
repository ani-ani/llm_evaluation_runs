module closest_integer(input [31:0] fixed_point_number, output reg [16:0] rounded_value);
  wire signed [15:0] integer_part = fixed_point_number[31:16];
  wire [15:0] fractional_part = fixed_point_number[15:0];
  wire [16:0] int_ext = {integer_part[15], integer_part};
  always_comb begin
    if (fractional_part < 16'h8000) rounded_value = int_ext;
    else if (integer_part > 0) rounded_value = int_ext + 1;
    else rounded_value = int_ext - 1;
  end
endmodule