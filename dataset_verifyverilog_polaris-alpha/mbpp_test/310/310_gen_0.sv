module str_to_tuple(
  input  [127:0] data_in,
  input  [3:0]   length,
  output reg [127:0] tuple_data,
  output reg [4:0]  tuple_length
);

  // Per-character signals
  wire [7:0] ch [0:15];
  wire       valid_pos [0:15];
  wire       is_space [0:15];
  wire [4:0] rank [0:15];

  genvar gi;
  generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : GEN_CHAR
      assign ch[gi] = data_in[8*gi +: 8];
      assign valid_pos[gi] = (gi < length);
      assign is_space[gi] = (ch[gi] == 8'h20);
    end
  endgenerate

  // Prefix sums for ranks (number of kept chars before i)
  // rank[i] = count of (valid_pos[j] && !is_space[j]) for j < i
  // Implemented combinationally via explicit logic for 16 positions.

  // Helper wires: keep[i]
  wire keep [0:15];
  generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : GEN_KEEP
      assign keep[gi] = valid_pos[gi] && !is_space[gi];
    end
  endgenerate

  // For clarity and synthesis-friendliness, build prefix counts iteratively.
  // Use temporary wires for cumulative counts.
  wire [4:0] prefix [0:16];
  assign prefix[0] = 5'd0;

  generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : GEN_PREFIX
      assign prefix[gi+1] = prefix[gi] + (keep[gi] ? 5'd1 : 5'd0);
      assign rank[gi]    = prefix[gi];
    end
  endgenerate

  // tuple_length is total kept characters
  always @* begin
    tuple_length = prefix[16];

    // Default tuple_data to zeros
    tuple_data = 128'd0;

    // Pack kept characters into tuple_data using their rank as index
    // When keep[i] is 1, place ch[i] at position rank[i]
    if (keep[0])  tuple_data[8*rank[0]  +: 8] = ch[0];
    if (keep[1])  tuple_data[8*rank[1]  +: 8] = ch[1];
    if (keep[2])  tuple_data[8*rank[2]  +: 8] = ch[2];
    if (keep[3])  tuple_data[8*rank[3]  +: 8] = ch[3];
    if (keep[4])  tuple_data[8*rank[4]  +: 8] = ch[4];
    if (keep[5])  tuple_data[8*rank[5]  +: 8] = ch[5];
    if (keep[6])  tuple_data[8*rank[6]  +: 8] = ch[6];
    if (keep[7])  tuple_data[8*rank[7]  +: 8] = ch[7];
    if (keep[8])  tuple_data[8*rank[8]  +: 8] = ch[8];
    if (keep[9])  tuple_data[8*rank[9]  +: 8] = ch[9];
    if (keep[10]) tuple_data[8*rank[10] +: 8] = ch[10];
    if (keep[11]) tuple_data[8*rank[11] +: 8] = ch[11];
    if (keep[12]) tuple_data[8*rank[12] +: 8] = ch[12];
    if (keep[13]) tuple_data[8*rank[13] +: 8] = ch[13];
    if (keep[14]) tuple_data[8*rank[14] +: 8] = ch[14];
    if (keep[15]) tuple_data[8*rank[15] +: 8] = ch[15];
  end

endmodule