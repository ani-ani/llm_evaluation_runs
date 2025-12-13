module hex_prime_counter(
  input  [4:0]  len,
  input  [127:0] hex_str,
  output [5:0]  count
);

  // Extract 32 nibbles (d[31] is first/MSB nibble, d[0] is last/LSB nibble)
  wire [3:0] d [31:0];
  assign d[31] = hex_str[127:124];
  assign d[30] = hex_str[123:120];
  assign d[29] = hex_str[119:116];
  assign d[28] = hex_str[115:112];
  assign d[27] = hex_str[111:108];
  assign d[26] = hex_str[107:104];
  assign d[25] = hex_str[103:100];
  assign d[24] = hex_str[99:96];
  assign d[23] = hex_str[95:92];
  assign d[22] = hex_str[91:88];
  assign d[21] = hex_str[87:84];
  assign d[20] = hex_str[83:80];
  assign d[19] = hex_str[79:76];
  assign d[18] = hex_str[75:72];
  assign d[17] = hex_str[71:68];
  assign d[16] = hex_str[67:64];
  assign d[15] = hex_str[63:60];
  assign d[14] = hex_str[59:56];
  assign d[13] = hex_str[55:52];
  assign d[12] = hex_str[51:48];
  assign d[11] = hex_str[47:44];
  assign d[10] = hex_str[43:40];
  assign d[9]  = hex_str[39:36];
  assign d[8]  = hex_str[35:32];
  assign d[7]  = hex_str[31:28];
  assign d[6]  = hex_str[27:24];
  assign d[5]  = hex_str[23:20];
  assign d[4]  = hex_str[19:16];
  assign d[3]  = hex_str[15:12];
  assign d[2]  = hex_str[11:8];
  assign d[1]  = hex_str[7:4];
  assign d[0]  = hex_str[3:0];

  // Per-position: in-range mask (i < len)
  wire in_range [31:0];
  assign in_range[31] = (len > 5'd31);
  assign in_range[30] = (len > 5'd30);
  assign in_range[29] = (len > 5'd29);
  assign in_range[28] = (len > 5'd28);
  assign in_range[27] = (len > 5'd27);
  assign in_range[26] = (len > 5'd26);
  assign in_range[25] = (len > 5'd25);
  assign in_range[24] = (len > 5'd24);
  assign in_range[23] = (len > 5'd23);
  assign in_range[22] = (len > 5'd22);
  assign in_range[21] = (len > 5'd21);
  assign in_range[20] = (len > 5'd20);
  assign in_range[19] = (len > 5'd19);
  assign in_range[18] = (len > 5'd18);
  assign in_range[17] = (len > 5'd17);
  assign in_range[16] = (len > 5'd16);
  assign in_range[15] = (len > 5'd15);
  assign in_range[14] = (len > 5'd14);
  assign in_range[13] = (len > 5'd13);
  assign in_range[12] = (len > 5'd12);
  assign in_range[11] = (len > 5'd11);
  assign in_range[10] = (len > 5'd10);
  assign in_range[9]  = (len > 5'd9);
  assign in_range[8]  = (len > 5'd8);
  assign in_range[7]  = (len > 5'd7);
  assign in_range[6]  = (len > 5'd6);
  assign in_range[5]  = (len > 5'd5);
  assign in_range[4]  = (len > 5'd4);
  assign in_range[3]  = (len > 5'd3);
  assign in_range[2]  = (len > 5'd2);
  assign in_range[1]  = (len > 5'd1);
  assign in_range[0]  = (len > 5'd0);

  // Prime digit detection: {2,3,5,7,B(11),D(13)}
  function automatic is_prime_hex(input [3:0] x);
    begin
      case (x)
        4'h2, 4'h3, 4'h5, 4'h7, 4'hB, 4'hD: is_prime_hex = 1'b1;
        default:                            is_prime_hex = 1'b0;
      endcase
    end
  endfunction

  wire prime_bit [31:0];
  assign prime_bit[31] = in_range[31] & is_prime_hex(d[31]);
  assign prime_bit[30] = in_range[30] & is_prime_hex(d[30]);
  assign prime_bit[29] = in_range[29] & is_prime_hex(d[29]);
  assign prime_bit[28] = in_range[28] & is_prime_hex(d[28]);
  assign prime_bit[27] = in_range[27] & is_prime_hex(d[27]);
  assign prime_bit[26] = in_range[26] & is_prime_hex(d[26]);
  assign prime_bit[25] = in_range[25] & is_prime_hex(d[25]);
  assign prime_bit[24] = in_range[24] & is_prime_hex(d[24]);
  assign prime_bit[23] = in_range[23] & is_prime_hex(d[23]);
  assign prime_bit[22] = in_range[22] & is_prime_hex(d[22]);
  assign prime_bit[21] = in_range[21] & is_prime_hex(d[21]);
  assign prime_bit[20] = in_range[20] & is_prime_hex(d[20]);
  assign prime_bit[19] = in_range[19] & is_prime_hex(d[19]);
  assign prime_bit[18] = in_range[18] & is_prime_hex(d[18]);
  assign prime_bit[17] = in_range[17] & is_prime_hex(d[17]);
  assign prime_bit[16] = in_range[16] & is_prime_hex(d[16]);
  assign prime_bit[15] = in_range[15] & is_prime_hex(d[15]);
  assign prime_bit[14] = in_range[14] & is_prime_hex(d[14]);
  assign prime_bit[13] = in_range[13] & is_prime_hex(d[13]);
  assign prime_bit[12] = in_range[12] & is_prime_hex(d[12]);
  assign prime_bit[11] = in_range[11] & is_prime_hex(d[11]);
  assign prime_bit[10] = in_range[10] & is_prime_hex(d[10]);
  assign prime_bit[9]  = in_range[9]  & is_prime_hex(d[9]);
  assign prime_bit[8]  = in_range[8]  & is_prime_hex(d[8]);
  assign prime_bit[7]  = in_range[7]  & is_prime_hex(d[7]);
  assign prime_bit[6]  = in_range[6]  & is_prime_hex(d[6]);
  assign prime_bit[5]  = in_range[5]  & is_prime_hex(d[5]);
  assign prime_bit[4]  = in_range[4]  & is_prime_hex(d[4]);
  assign prime_bit[3]  = in_range[3]  & is_prime_hex(d[3]);
  assign prime_bit[2]  = in_range[2]  & is_prime_hex(d[2]);
  assign prime_bit[1]  = in_range[1]  & is_prime_hex(d[1]);
  assign prime_bit[0]  = in_range[0]  & is_prime_hex(d[0]);

  // Tree adder: 32 -> 16 -> 8 -> 4 -> 2 -> 1 (max = 32 -> need 6 bits)

  // Level 1: sum adjacent bits into 2-bit values (0..2)
  wire [1:0] s1 [15:0];
  genvar i1;
  generate
    for (i1 = 0; i1 < 16; i1 = i1 + 1) begin : GEN_L1
      assign s1[i1] = {1'b0, prime_bit[2*i1]} + {1'b0, prime_bit[2*i1 + 1]};
    end
  endgenerate

  // Level 2: sum pairs of s1 (each 0..2) -> 3-bit (0..4)
  wire [2:0] s2 [7:0];
  genvar i2;
  generate
    for (i2 = 0; i2 < 8; i2 = i2 + 1) begin : GEN_L2
      assign s2[i2] = {1'b0, s1[2*i2]} + {1'b0, s1[2*i2 + 1]};
    end
  endgenerate

  // Level 3: sum pairs of s2 (each 0..4) -> 4-bit (0..8)
  wire [3:0] s3 [3:0];
  genvar i3;
  generate
    for (i3 = 0; i3 < 4; i3 = i3 + 1) begin : GEN_L3
      assign s3[i3] = {1'b0, s2[2*i3]} + {1'b0, s2[2*i3 + 1]};
    end
  endgenerate

  // Level 4: sum pairs of s3 (each 0..8) -> 5-bit (0..16)
  wire [4:0] s4 [1:0];
  genvar i4;
  generate
    for (i4 = 0; i4 < 2; i4 = i4 + 1) begin : GEN_L4
      assign s4[i4] = {1'b0, s3[2*i4]} + {1'b0, s3[2*i4 + 1]};
    end
  endgenerate

  // Level 5: sum final two (each 0..16) -> 6-bit (0..32)
  wire [5:0] s5;
  assign s5 = {1'b0, s4[0]} + {1'b0, s4[1]};

  assign count = s5;

endmodule