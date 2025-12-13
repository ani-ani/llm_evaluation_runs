module cyclic_codec(
  input  [71:0] str_in,
  input         mode,      // 0: encode, 1: decode
  output reg [71:0] str_out
);

  // Extract 3-character groups (each char is 8 bits)
  wire [23:0] grp0_in = str_in[23:0];    // chars 0,1,2
  wire [23:0] grp1_in = str_in[47:24];  // chars 3,4,5
  wire [23:0] grp2_in = str_in[71:48];  // chars 6,7,8

  // Individual bytes for each group
  wire [7:0] g0_c0 = grp0_in[7:0];
  wire [7:0] g0_c1 = grp0_in[15:8];
  wire [7:0] g0_c2 = grp0_in[23:16];

  wire [7:0] g1_c0 = grp1_in[7:0];
  wire [7:0] g1_c1 = grp1_in[15:8];
  wire [7:0] g1_c2 = grp1_in[23:16];

  wire [7:0] g2_c0 = grp2_in[7:0];
  wire [7:0] g2_c1 = grp2_in[15:8];
  wire [7:0] g2_c2 = grp2_in[23:16];

  // Complete group detection (all three bytes non-zero)
  wire grp0_complete = (g0_c0 != 8'h00) && (g0_c1 != 8'h00) && (g0_c2 != 8'h00);
  wire grp1_complete = (g1_c0 != 8'h00) && (g1_c1 != 8'h00) && (g1_c2 != 8'h00);
  wire grp2_complete = (g2_c0 != 8'h00) && (g2_c1 != 8'h00) && (g2_c2 != 8'h00);

  // Combinational transform
  always @* begin
    // Default: pass-through
    str_out = str_in;

    if (mode == 1'b0) begin
      // Encode: left cyclic shift within complete groups
      if (grp0_complete) begin
        str_out[7:0]    = g0_c1; // new c0
        str_out[15:8]   = g0_c2; // new c1
        str_out[23:16]  = g0_c0; // new c2
      end
      if (grp1_complete) begin
        str_out[31:24]  = g1_c1;
        str_out[39:32]  = g1_c2;
        str_out[47:40]  = g1_c0;
      end
      if (grp2_complete) begin
        str_out[55:48]  = g2_c1;
        str_out[63:56]  = g2_c2;
        str_out[71:64]  = g2_c0;
      end
    end else begin
      // Decode: right cyclic shift within complete groups
      if (grp0_complete) begin
        str_out[7:0]    = g0_c2; // new c0
        str_out[15:8]   = g0_c0; // new c1
        str_out[23:16]  = g0_c1; // new c2
      end
      if (grp1_complete) begin
        str_out[31:24]  = g1_c2;
        str_out[39:32]  = g1_c0;
        str_out[47:40]  = g1_c1;
      end
      if (grp2_complete) begin
        str_out[55:48]  = g2_c2;
        str_out[63:56]  = g2_c0;
        str_out[71:64]  = g2_c1;
      end
    end
  end

endmodule