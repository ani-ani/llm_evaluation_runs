module char_calculator(
  input  [63:0] str_input,
  output [7:0]  result_char
);

  // Split into 8 bytes
  wire [7:0] c0 = str_input[63:56];
  wire [7:0] c1 = str_input[55:48];
  wire [7:0] c2 = str_input[47:40];
  wire [7:0] c3 = str_input[39:32];
  wire [7:0] c4 = str_input[31:24];
  wire [7:0] c5 = str_input[23:16];
  wire [7:0] c6 = str_input[15:8];
  wire [7:0] c7 = str_input[7:0];

  // Convert ASCII to 1-26 (only for non-zero); invalid chars yield x (don't care)
  wire [5:0] v0 = (c0 == 8'd0) ? 6'd0 : (c0 - 8'd96); // 'a' = 97
  wire [5:0] v1 = (c1 == 8'd0) ? 6'd0 : (c1 - 8'd96);
  wire [5:0] v2 = (c2 == 8'd0) ? 6'd0 : (c2 - 8'd96);
  wire [5:0] v3 = (c3 == 8'd0) ? 6'd0 : (c3 - 8'd96);
  wire [5:0] v4 = (c4 == 8'd0) ? 6'd0 : (c4 - 8'd96);
  wire [5:0] v5 = (c5 == 8'd0) ? 6'd0 : (c5 - 8'd96);
  wire [5:0] v6 = (c6 == 8'd0) ? 6'd0 : (c6 - 8'd96);
  wire [5:0] v7 = (c7 == 8'd0) ? 6'd0 : (c7 - 8'd96);

  // Sum (max 8*26=208 < 256) so 8 bits are enough; use 9 for safety
  wire [8:0] sum = v0 + v1 + v2 + v3 + v4 + v5 + v6 + v7;

  // Compute sum mod 26 (pure combinational)
  wire [7:0] sum_mod_26 = sum % 8'd26;

  // Map to result_char
  // If mod == 0 -> 'z'; else 'a' + (mod-1)
  assign result_char = (sum_mod_26 == 8'd0) ? 8'h7A : (8'd96 + sum_mod_26);

endmodule