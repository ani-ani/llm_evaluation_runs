module str_to_tuple (
  input      [127:0] data_in,
  input      [3:0]  length,
  output reg [127:0] tuple_data,
  output reg [4:0]  tuple_length
);

  // Helper: is a byte not a space (ASCII 0x20)?
  function [0:0] is_not_space (input [7:0] byte);
    is_not_space = (byte != 8'h20);
  endfunction

  // Per-byte analysis and local keep/pos signals
  wire [15:0] keep;      // whether this byte is kept (valid && not space)
  wire [15:0] pos_bit;   // position increment for this byte (0 or 1)

  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : BYTE_ANALYZERS
      wire [7:0] byte_i = data_in[i*8 +: 8];
      wire valid_i = (i < length);
      assign keep[i]   = valid_i && is_not_space(byte_i);
      assign pos_bit[i] = keep[i];
    end
  endgenerate

  // 16 parallel prefix (carry) on 1-bit numbers pos_bit, with total as MSB
  // Level 0 (singles)
  wire [15:0] p0;   // prefix sums for groups of 1
  assign p0[0] = pos_bit[0];
  genvar g0;
  generate
    for (g0 = 1; g0 < 16; g0 = g0 + 1) begin : L0
      assign p0[g0] = p0[g0-1] + pos_bit[g0];
    end
  endgenerate

  // Level 1 (pairs)
  wire [7:0]  p1;   // prefix sums for groups of 2
  genvar g1;
  generate
    for (g1 = 0; g1 < 8; g1 = g1 + 1) begin : L1
      assign p1[g1] = p0[2*g1+1];
    end
  endgenerate

  // Level 2 (quads)
  wire [3:0]  p2;   // prefix sums for groups of 4
  genvar g2;
  generate
    for (g2 = 0; g2 < 4; g2 = g2 + 1) begin : L2
      assign p2[g2] = p1[2*g2+1];
    end
  endgenerate

  // Level 3 (bytes)
  wire [1:0]  p3;   // prefix sums for groups of 8
  assign p3[0] = p2[1];
  assign p3[1] = p2[3];

  // Level 4 (total across all 16)
  wire [4:0]  total;
  assign total = p3[1];

  // Final per-byte positions (1..count) for kept bytes, 0 otherwise
  wire [15:0] pos;  // 5-bit per byte; LSB used to index output, upper 4 bits are zero here
  assign pos[0] = 1'b0;
  genvar j;
  generate
    for (j = 1; j < 16; j = j + 1) begin : FINAL_POS
      // Select the prefix result for the group containing j:
      // group index base (most significant 4 bits of j):
      //   groups of 1 -> prefix p0[j]
      //   groups of 2 -> prefix p1[j>>1]
      //   groups of 4 -> prefix p2[j>>2]
      //   groups of 8 -> prefix p3[j>>3]
      //   across all 16 -> total (used via implicit base below for j==15)
      // Compute base counts for groups that end before the group containing j.
      wire [4:0] base;
      // base across groups of 8 (if j >= 8, add p3[1], else 0)
      assign base = (j >= 8) ? p3[1] : 5'b0;
      // base across groups of 4 within the 8-block
      case (j[3:2]) // j>>2
        2'd0: begin end
        2'd1: base = base + p2[0];
        2'd2: base = base + p2[1];
        2'd3: base = base + p2[2];
      endcase
      // base across groups of 2 within the 4-block
      case (j[1]) // j[1]
        1'b0: begin end
        1'b1: base = base + p1[(j>>2)*2];
      endcase
      // base across groups of 1 within the 2-block
      // if j[0] is 1, add p0[base_index_of_pair]
      // pair index is (j>>1), and the first element index is (j & 5'b11110)
      if (j[0]) begin
        base = base + p0[(j>>1)];
      end
      // prefix position for byte j
      assign pos[j] = base + pos_bit[j];
    end
  endgenerate

  // Packing: select which input bytes populate each output byte position (0..total-1)
  // Position j (output byte) will receive the first kept byte with position == j.
  genvar k;
  generate
    for (k = 0; k < 16; k = k + 1) begin : PACK
      // For each output position k, check which input byte should go there.
      // Check all input bytes and OR in their contribution.
      integer idx;
      reg [7:0] outbyte;
      begin
        outbyte = 8'h00; // default to null
        for (idx = 0; idx < 16; idx = idx + 1) begin
          if (keep[idx] && (pos[idx] == k)) begin
            outbyte = data_in[idx*8 +: 8];
          end
        end
        // Assign to the output byte lane
        assign tuple_data[k*8 +: 8] = outbyte;
      end
    end
  endgenerate

  // Total count of kept bytes (0..16)
  assign tuple_length = total;

endmodule