module hex_key(
  input [127:0] hex_string,
  input [4:0] length,
  output [4:0] prime_count
);

  wire [15:0] prime_flags;
  wire [4:0] count [0:15];

  // Generate prime flags for each digit position
  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : prime_check
      wire [3:0] digit = hex_string[(i+1)*4-1 : i*4];
      assign prime_flags[i] = (digit == 4'h2) || (digit == 4'h3) || (digit == 4'h5) || (digit == 4'h7) || (digit == 4'hB) || (digit == 4'hD);
    end
  endgenerate

  // Tree adder structure for counting
  assign count[0] = (i < length) ? prime_flags[0] : 0;
  assign count[1] = count[0] + ((i < length) ? prime_flags[1] : 0);
  assign count[2] = count[1] + ((i < length) ? prime_flags[2] : 0);
  assign count[3] = count[2] + ((i < length) ? prime_flags[3] : 0);
  assign count[4] = count[3] + ((i < length) ? prime_flags[4] : 0);
  assign count[5] = count[4] + ((i < length) ? prime_flags[5] : 0);
  assign count[6] = count[5] + ((i < length) ? prime_flags[6] : 0);
  assign count[7] = count[6] + ((i < length) ? prime_flags[7] : 0);
  assign count[8] = count[7] + ((i < length) ? prime_flags[8] : 0);
  assign count[9] = count[8] + ((i < length) ? prime_flags[9] : 0);
  assign count[10] = count[9] + ((i < length) ? prime_flags[10] : 0);
  assign count[11] = count[10] + ((i < length) ? prime_flags[11] : 0);
  assign count[12] = count[11] + ((i < length) ? prime_flags[12] : 0);
  assign count[13] = count[12] + ((i < length) ? prime_flags[13] : 0);
  assign count[14] = count[13] + ((i < length) ? prime_flags[14] : 0);
  assign count[15] = count[14] + ((i < length) ? prime_flags[15] : 0);

  assign prime_count = count[15];

endmodule