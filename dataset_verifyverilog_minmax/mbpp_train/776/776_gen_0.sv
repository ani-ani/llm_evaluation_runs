module vowel_neighbor_count (
  input [127:0] str_flat, // 16-byte string (ASCII), LSB = first char
  input [3:0] str_len,    // 1..16
  output [3:0] count      // number of non-vowel chars with at least one vowel neighbor
);

  // Build a 16-bit mask of vowel positions (bit i == 1 if byte i is a vowel a/e/i/o/u)
  logic [15:0] vowel_mask;
  always_comb begin
    vowel_mask = 16'b0;
    for (int i = 0; i < 16; i = i + 1) begin
      case (str_flat[i*8 +: 8])
        8'd97, 8'd101, 8'd105, 8'd111, 8'd117: vowel_mask[i] = 1'b1; // a, e, i, o, u
        default: vowel_mask[i] = 1'b0;
      endcase
    end
  end

  // Qualify: not a vowel AND has at least one vowel neighbor within bounds
  // Boundary rules:
  //   idx 0: check right neighbor only
  //   idx str_len-1: check left neighbor only
  //   otherwise: check both left and right
  logic [15:0] qualify;
  always_comb begin
    qualify = 16'b0;
    for (int i = 0; i < 16; i = i + 1) begin
      if (i < str_len) begin
        if (~vowel_mask[i]) begin // not a vowel
          if (i == 0) begin
            // First char: only right neighbor
            qualify[i] = (str_len > 1) ? vowel_mask[i+1] : 1'b0;
          end else if (i == str_len - 1) begin
            // Last char: only left neighbor
            qualify[i] = vowel_mask[i-1];
          end else begin
            // Internal char: either neighbor
            qualify[i] = vowel_mask[i-1] | vowel_mask[i+1];
          end
        end
      end
    end
  end

  // Count set bits in qualify (max 16, fits in 4 bits)
  assign count = (
    qualify[0] + qualify[1] + qualify[2] + qualify[3] +
    qualify[4] + qualify[5] + qualify[6] + qualify[7] +
    qualify[8] + qualify[9] + qualify[10] + qualify[11] +
    qualify[12] + qualify[13] + qualify[14] + qualify[15]
  );

endmodule