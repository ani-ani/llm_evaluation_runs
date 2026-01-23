module cone_volume(
  input [31:0] radius,
  input [31:0] height,
  output reg [31:0] volume
);

  reg [63:0] r_squared;
  reg [63:0] r_squared_h;
  reg [63:0] r_squared_h_pi;
  reg [63:0] r_squared_h_pi_div3;

  // Constants in Q16.16 format
  localparam [31:0] PI = 32'h0003243F;
  localparam [31:0] ONE_THIRD = 32'h00005555;

  // Calculate r^2 (Q32.32 format)
  assign r_squared = $signed(radius) * $signed(radius);

  // Calculate r^2 * h (Q32.32 format)
  assign r_squared_h = r_squared * $signed(height);

  // Multiply by PI (Q32.32 format)
  assign r_squared_h_pi = r_squared_h * $signed(PI);

  // Multiply by 1/3 (Q32.32 format)
  assign r_squared_h_pi_div3 = r_squared_h_pi * $signed(ONE_THIRD);

  // Take upper 32 bits to get back to Q16.16 format
  always @* begin
    volume = r_squared_h_pi_div3[63:32];
  end

endmodule