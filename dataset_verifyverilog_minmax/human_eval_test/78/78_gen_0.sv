// hex_prime_counter
// Counts prime hexadecimal digits among the first 'len' nibbles of hex_str.
// Prime hex digits: 2,3,5,7,B(11),D(13)
// - len [4:0]: number of valid nibbles to process (0..32)
// - hex_str [127:0]: 32 hex digits packed left-to-right (MSB first)
// - count [5:0]: number of prime digits in the first 'len' positions

module hex_prime_counter (
  input  [4:0]  len,
  input  [127:0] hex_str,
  output logic [5:0] count
);

  function automatic logic is_prime_hex(input [3:0] nibble);
    case (nibble)
      4'h2, 4'h3, 4'h5, 4'h7, 4'hB, 4'hD: is_prime_hex = 1'b1;
      default:                               is_prime_hex = 1'b0;
    endcase
  endfunction

  // Precompute per-position prime flags and mask by len using a priority-encoder tree approach
  logic [31:0] prime_mask;
  always_comb begin
    // Identify positions i < len (i from 0 for LSB nibble to 31 for MSB nibble)
    for (int i = 0; i < 32; i++) begin
      logic [3:0] nibble;
      nibble = hex_str[i*4 +: 4];
      prime_mask[i] = (i < len) ? is_prime_hex(nibble) : 1'b0;
    end
  end

  // Count set bits in prime_mask using a parallel reduction tree (4:2, 6:3, 7:3)
  // Level 1: 16 two-bit sums
  logic [15:0][1:0] sum2;
  for (genvar g = 0; g < 16; g++) begin : L1_pairs
    assign sum2[g] = prime_mask[2*g] + prime_mask[2*g+1];
  end

  // Level 2: 8 four-bit sums
  logic [7:0][2:0] sum4;
  for (genvar g = 0; g < 8; g++) begin : L2_pairs
    assign sum4[g] = sum2[2*g] + sum2[2*g+1];
  end

  // Level 3: 4 eight-bit sums
  logic [3:0][3:0] sum8;
  for (genvar g = 0; g < 4; g++) begin : L3_pairs
    assign sum8[g] = sum4[2*g] + sum4[2*g+1];
  end

  // Level 4: 2 sixteen-bit sums
  logic [1:0][4:0] sum16;
  for (genvar g = 0; g < 2; g++) begin : L4_pairs
    assign sum16[g] = sum8[2*g] + sum8[2*g+1];
  end

  // Level 5: final 32-bit sum
  logic [5:0] total;
  assign total = sum16[0] + sum16[1];

  // Register the output to ensure clean, static timing (optional, but safe)
  always_comb count = total;

endmodule