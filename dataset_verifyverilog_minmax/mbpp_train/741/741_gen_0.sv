module all_chars_same(
  input wire [63:0] s,   // 8 ASCII bytes: s[63:56] is char 1, s[7:0] is char 8
  input wire [2:0] len,  // 1..8
  output logic all_same  // 1 if all len characters equal the first, else 0
);
  logic [7:0] mask;      // 1 = include byte in comparison, 0 = ignore
  logic [7:0] eq;        // per-byte equality with first char

  always_comb begin
    // Build mask for the first 'len' bytes; treat len=0 as none to compare
    mask = (len == 3'd0) ? 8'b0 : (8'b10000000 >> (len - 3'd1));

    // Equality of each byte with the first byte (s[63:56])
    eq = {8{s[63:56]}} == s[63:0];

    // Include out-of-range bytes as "equal" by OR with ~mask, then reduce with AND
    all_same = & (eq | ~mask);
  end
endmodule
