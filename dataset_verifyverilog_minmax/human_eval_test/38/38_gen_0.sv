module cyclic_codec (
  input [71:0] str_in, // 9 characters (8 bits each) null-padded
  input mode,          // 0: encode, 1: decode
  output reg [71:0] str_out
);

  always_comb begin
    // Byte extraction for clarity
    // Group 0: bytes 0,1,2  -> indices 0..2
    // Group 1: bytes 3,4,5  -> indices 3..5
    // Group 2: bytes 6,7,8  -> indices 6..8
    logic [7:0] g0 [0:2];
    logic [7:0] g1 [0:2];
    logic [7:0] g2 [0:2];

    g0[0] = str_in[7:0];    // char 0
    g0[1] = str_in[15:8];   // char 1
    g0[2] = str_in[23:16];  // char 2
    g1[0] = str_in[31:24];  // char 3
    g1[1] = str_in[39:32];  // char 4
    g1[2] = str_in[47:40];  // char 5
    g2[0] = str_in[55:48];  // char 6
    g2[1] = str_in[63:56];  // char 7
    g2[2] = str_in[71:64];  // char 8

    // Complete group check: all 3 bytes != 0
    logic complete0, complete1, complete2;
    assign complete0 = (g0[0] != 8'h00) && (g0[1] != 8'h00) && (g0[2] != 8'h00);
    assign complete1 = (g1[0] != 8'h00) && (g1[1] != 8'h00) && (g1[2] != 8'h00);
    assign complete2 = (g2[0] != 8'h00) && (g2[1] != 8'h00) && (g2[2] != 8'h00);

    // Local variables for transformed groups
    logic [7:0] out_g0 [0:2];
    logic [7:0] out_g1 [0:2];
    logic [7:0] out_g2 [0:2];

    // Apply transformation in parallel per group if complete
    if (mode == 1'b0) begin : encode_mode
      // Encode: left cyclic shift within each complete group
      // [2:0] -> [1:0][2]
      assign out_g0[0] = complete0 ? g0[1] : g0[0];
      assign out_g0[1] = complete0 ? g0[2] : g0[1];
      assign out_g0[2] = complete0 ? g0[0] : g0[2];

      assign out_g1[0] = complete1 ? g1[1] : g1[0];
      assign out_g1[1] = complete1 ? g1[2] : g1[1];
      assign out_g1[2] = complete1 ? g1[0] : g1[2];

      assign out_g2[0] = complete2 ? g2[1] : g2[0];
      assign out_g2[1] = complete2 ? g2[2] : g2[1];
      assign out_g2[2] = complete2 ? g2[0] : g2[2];
    end else begin : decode_mode
      // Decode: right cyclic shift within each complete group
      // [2:0] -> [0][2:1]
      assign out_g0[0] = complete0 ? g0[2] : g0[0];
      assign out_g0[1] = complete0 ? g0[0] : g0[1];
      assign out_g0[2] = complete0 ? g0[1] : g0[2];

      assign out_g1[0] = complete1 ? g1[2] : g1[0];
      assign out_g1[1] = complete1 ? g1[0] : g1[1];
      assign out_g1[2] = complete1 ? g1[1] : g1[2];

      assign out_g2[0] = complete2 ? g2[2] : g2[0];
      assign out_g2[1] = complete2 ? g2[0] : g2[1];
      assign out_g2[2] = complete2 ? g2[1] : g2[2];
    end

    // Reassemble output
    str_out = {
      out_g2[2], out_g2[1], out_g2[0],
      out_g1[2], out_g1[1], out_g1[0],
      out_g0[2], out_g0[1], out_g0[0]
    };
  end
endmodule
