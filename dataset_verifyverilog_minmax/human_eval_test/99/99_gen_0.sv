module closest_integer (
  input  reg [31:0] fixed_point_number,
  output reg [16:0] rounded_value
);

  // Split Q16.16 into signed 16-bit integer part and 16-bit fractional part
  wire signed [15:0] integer_part;
  wire        [15:0] frac_u;

  assign integer_part = $signed(fixed_point_number[31:16]);
  assign frac_u       = fixed_point_number[15:0];

  // Treat fractional as signed for threshold comparisons (0x8000 = 0)
  wire signed [16:0] frac_s;
  assign frac_s = $signed(frac_u);

  // Rounding: round half away from zero
  always @(*) begin
    if (frac_s > 0) begin
      // Positive fractional: round up
      rounded_value = $signed(integer_part) + 1;
    end else if (frac_s < 0) begin
      // Negative fractional: round down (more negative)
      rounded_value = $signed(integer_part) - 1;
    end else begin
      // Exactly 0x8000: tie -> round away from zero
      if (integer_part >= 0) begin
        rounded_value = $signed(integer_part) + 1;
      end else begin
        rounded_value = $signed(integer_part) - 1;
      end
    end
  end

endmodule
