// degree_to_radian
// Converts integer degrees [15:0] to Q16.16 fixed-point radians [31:0]
// Conversion: radian = degree * (pi/180), with pi/180 approximated as Q16.16 constant 1144 (0x00000478)
// Output represents fixed-point value = (result / 65536.0)

module degree_to_radian (
  input  reg [15:0] degree,
  output reg [31:0] radian
);

  localparam [31:0] PI_OVER_180 = 32'h00000478; // Q16.16 approximation of pi/180

  always_comb begin
    radian = degree * PI_OVER_180; // [31:0] result
  end

endmodule
