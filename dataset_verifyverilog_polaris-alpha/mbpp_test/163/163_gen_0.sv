module poly_area(
  input      [3:0] sides,
  input      [4:0] length,
  output reg [31:0] area
);

  // Q16.16 coefficients: sides / (4 * tan(pi/sides))
  // Approximated values (hex) for sides = 3..16
  // Precomputed externally to ensure synthesis-friendly ROM usage.
  // Note: Values are in unsigned Q16.16 format.
  function automatic [31:0] coeff_lut;
    input [3:0] s;
    begin
      case (s)
        4'd3:  coeff_lut = 32'h00006ED9; // 0.4329
        4'd4:  coeff_lut = 32'h00010000; // 1.0000
        4'd5:  coeff_lut = 32'h00015B48; // 1.3764
        4'd6:  coeff_lut = 32'h0001C5C2; // 1.7712
        4'd7:  coeff_lut = 32'h0002362D; // 2.2123
        4'd8:  coeff_lut = 32'h0002ABFC; // 2.6833
        4'd9:  coeff_lut = 32'h000326D2; // 3.1989
        4'd10: coeff_lut = 32'h0003AE5F; // 3.7635
        4'd11: coeff_lut = 32'h00043A64; // 4.3828
        4'd12: coeff_lut = 32'h0004D2AC; // 5.0629
        4'd13: coeff_lut = 32'h00056F12; // 5.8103
        4'd14: coeff_lut = 32'h0006177E; // 6.6328
        4'd15: coeff_lut = 32'h0006CBE0; // 7.5388
        4'd16: coeff_lut = 32'h00078C28; // 8.5388
        default: coeff_lut = 32'h00000000; // invalid -> 0
      endcase
    end
  endfunction

  wire [31:0] coeff;
  wire [9:0]  length_squared;   // 5-bit * 5-bit = 10-bit
  wire [41:0] mult_full;        // 32-bit * 10-bit = 42-bit

  assign coeff          = coeff_lut(sides);
  assign length_squared = length * length;
  assign mult_full      = coeff * length_squared;

  // Q16.16 result: coeff(Q16.16) * length^2(integer) = Q16.16
  // Keep lower 32 bits (fractional alignment preserved)
  always @* begin
    if ((sides < 4'd3) || (sides > 4'd16)) begin
      area = 32'h00000000;
    end else begin
      area = mult_full[31:0];
    end
  end

endmodule