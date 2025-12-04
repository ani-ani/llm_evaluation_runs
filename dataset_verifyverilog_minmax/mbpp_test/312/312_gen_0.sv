module cone_volume (
  input reg [7:0] r,  // Radius (0..255)
  input reg [7:0] h,  // Height (0..255)
  output wire [31:0] volume // Q16.16 fixed-point result
);

  // Q16.16 constants
  localparam [31:0] PI_Q16_16 = 32'h0003243F;      // 3.1415926535 in Q16.16
  localparam [31:0] ONE_THIRD = 32'h00005555;      // ~0.3333 in Q16.16

  // Q16.16 multiplication: returns upper 32 bits of 64-bit product
  function [31:0] Q16_16_mult;
    input [31:0] a;
    input [31:0] b;
    logic [63:0] prod;
  begin
    prod = $unsigned(a) * $unsigned(b);
    Q16_16_mult = prod[63:32]; // top 32 bits
  end
  endfunction

  // Step 1: r^2 (16-bit result)
  wire [15:0] r_squared;
  assign r_squared = r * r;

  // Step 2: pi * r^2 (Q16.16)
  wire [31:0] pi_times_r2;
  assign pi_times_r2 = Q16_16_mult(PI_Q16_16, {16'b0, r_squared});

  // Step 3: (pi * r^2) * h (Q16.16)
  wire [31:0] intermediate;
  assign intermediate = Q16_16_mult(pi_times_r2, {24'b0, h});

  // Step 4: multiply by 1/3 (Q16.16)
  assign volume = Q16_16_mult(intermediate, ONE_THIRD);

endmodule