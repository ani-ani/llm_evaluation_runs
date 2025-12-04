module wind_chill_calculator (
  input [7:0] wind_velocity, // 0-255 km/h
  input [7:0] temperature,   // -128 to 127°C, signed
  output reg [7:0] wind_chill // 8-bit signed result
);

  // 256-entry lookup table for v^0.16 in Q16.16 format
  reg [31:0] lut [0:255];
  integer i;
  
  // Initialize LUT with precomputed values
  initial begin
    for (i = 0; i < 256; i = i + 1) begin
      // v^0.16 in Q16.16 format
      lut[i] = $rtoi($pow(i, 0.16) * 65536);
    end
  end

  // Convert inputs to Q16.16 format
  wire signed [31:0] t_fixed = $signed(temperature) << 16; // 32-bit Q16.16
  wire [31:0] lut_value = lut[wind_velocity]; // 32-bit Q16.16

  // Constants in Q16.16 format
  wire signed [31:0] const0 = 32'd860160;  // 13.12 * 65536
  wire signed [31:0] const1 = 32'd40751;   // 0.6215 * 65536
  wire signed [31:0] const2 = 32'd745160;  // 11.37 * 65536
  wire signed [31:0] const3 = 32'd25989;   // 0.3965 * 65536

  // Intermediate calculations
  wire signed [31:0] term0 = const0;
  wire signed [31:0] term1 = (const1 * t_fixed) >>> 16;
  wire signed [31:0] term2 = (const2 * lut_value) >>> 16;
  wire signed [31:0] temp1 = (const3 * t_fixed) >>> 16;
  wire signed [31:0] term3 = (temp1 * lut_value) >>> 16;
  
  // Combined result in Q16.16
  wire signed [31:0] result_fixed = term0 + term1 - term2 + term3;
  
  // Round to nearest integer (add 0.5 = 32768 and truncate fractional bits)
  wire signed [15:0] result_rounded = (result_fixed + 32768) >>> 16;

  // Clamp to 8-bit signed range
  always @(*) begin
    if (result_rounded > 127)
      wind_chill = 127;
    else if (result_rounded < -128)
      wind_chill = -128;
    else
      wind_chill = result_rounded[7:0];
  end
endmodule