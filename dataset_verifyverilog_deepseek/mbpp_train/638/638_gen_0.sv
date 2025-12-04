module wind_chill_calculator (
  input [7:0] wind_velocity,
  input [7:0] temperature,
  output reg [7:0] wind_chill
);
  localparam C1312 = 32'sh000D1F98; // 13.12 Q16.16
  localparam C06215 = 32'sh00009F19; // 0.6215 Q16.16
  localparam C1137 = 32'sh000B5A2F; // 11.37 Q16.16
  localparam C03965 = 32'sh0000659E; // 0.3965 Q16.16
  localparam H8000 = 32'sh00008000; // 0.5 Q16.16
  
  // LUT declaration (actual values should be precomputed)
  localparam logic signed [31:0] lut_table [0:255] = '{256{32'sh00000000}};
  
  // Internal signals
  logic signed [31:0] temp_fixed;
  logic signed [31:0] lut_value;
  logic signed [31:0] term1, term2, term3, term4;
  logic signed [63:0] product_temp;
  logic signed [31:0] term_t_lut;
  logic signed [31:0] sum;
  logic signed [31:0] sum_rounded;
  logic signed [15:0] intermediate;
  
  always_comb begin
    // Step 1: Convert to Q16.16
    temp_fixed = $signed(temperature) << 16;
    
    // Step 2: Lookup LUT
    lut_value = lut_table[wind_velocity];
    
    // Step 3: Calculate terms
    product_temp = temp_fixed * lut_value;
    term_t_lut = product_temp >>> 16;
    
    product_temp = C06215 * temp_fixed;
    term2 = product_temp >>> 16;
    
    product_temp = C1137 * lut_value;
    term3 = product_temp >>> 16;
    
    product_temp = C03965 * term_t_lut;
    term4 = product_temp >>> 16;
    
    // Core formula
    sum = C1312 + term2 + term4 - term3;
    
    // Step 4: Rounding
    sum_rounded = sum + H8000;
    wind_chill = sum_rounded[23:16];
  end
endmodule