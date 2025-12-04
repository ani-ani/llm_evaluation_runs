module cone_volume (
  input [7:0] r,
  input [7:0] h,
  output [31:0] volume
);
  localparam [31:0] PI = 32'h0003243F;
  localparam [31:0] ONE_THIRD = 32'h00005555;

  function automatic [31:0] Q16_16_mult(input [31:0] a, input [31:0] b);
    reg [63:0] product;
    begin
      product = a * b;
      Q16_16_mult = product[47:16];
    end
  endfunction

  wire [15:0] r_squared = r * r;
  wire [31:0] rs_32 = {r_squared, 16'b0};
  wire [31:0] pi_rs = Q16_16_mult(PI, rs_32);
  wire [31:0] h_32 = {8'b0, h, 16'b0};
  wire [31:0] interm = Q16_16_mult(pi_rs, h_32);
  assign volume = Q16_16_mult(interm, ONE_THIRD);
endmodule