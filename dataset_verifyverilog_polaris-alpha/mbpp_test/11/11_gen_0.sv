module char_remover(
  input  [63:0] str_in,
  input  [7:0]  ch,
  output [63:0] str_out
);

  // Extract bytes from input string
  wire [7:0] b[7:0];
  assign b[0] = str_in[63:56];
  assign b[1] = str_in[55:48];
  assign b[2] = str_in[47:40];
  assign b[3] = str_in[39:32];
  assign b[4] = str_in[31:24];
  assign b[5] = str_in[23:16];
  assign b[6] = str_in[15:8];
  assign b[7] = str_in[7:0];

  // Mark which positions match ch
  wire match[7:0];
  assign match[0] = (b[0] == ch);
  assign match[1] = (b[1] == ch);
  assign match[2] = (b[2] == ch);
  assign match[3] = (b[3] == ch);
  assign match[4] = (b[4] == ch);
  assign match[5] = (b[5] == ch);
  assign match[6] = (b[6] == ch);
  assign match[7] = (b[7] == ch);

  // Find first occurrence index (0-7), if any
  wire [2:0] first_idx;
  wire       has_match;
  assign has_match = match[0] | match[1] | match[2] | match[3] |
                     match[4] | match[5] | match[6] | match[7];

  assign first_idx = match[0] ? 3'd0 :
                     match[1] ? 3'd1 :
                     match[2] ? 3'd2 :
                     match[3] ? 3'd3 :
                     match[4] ? 3'd4 :
                     match[5] ? 3'd5 :
                     match[6] ? 3'd6 :
                     match[7] ? 3'd7 : 3'd0;

  // Find last occurrence index (0-7), if any
  wire [2:0] last_idx;
  assign last_idx = match[7] ? 3'd7 :
                    match[6] ? 3'd6 :
                    match[5] ? 3'd5 :
                    match[4] ? 3'd4 :
                    match[3] ? 3'd3 :
                    match[2] ? 3'd2 :
                    match[1] ? 3'd1 :
                    match[0] ? 3'd0 : 3'd0;

  // Determine which indices to remove
  // - If no match: remove none.
  // - If exactly one match: remove that index.
  // - If multiple matches: remove first_idx and last_idx.

  wire [3:0] match_count;
  assign match_count = match[0] + match[1] + match[2] + match[3] +
                       match[4] + match[5] + match[6] + match[7];

  wire remove_first;
  wire remove_last;
  assign remove_first = has_match; // if at least one match, first_idx is removed
  assign remove_last  = (match_count > 4'd1); // last_idx additionally removed only if more than one match

  // Compute per-index remove flags
  wire remove[7:0];
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : gen_remove
      wire is_first = (i[2:0] == first_idx);
      wire is_last  = (i[2:0] == last_idx);
      assign remove[i] = (remove_first && is_first) || (remove_last && is_last);
    end
  endgenerate

  // Build output by compacting non-removed bytes to the left, pad with zeros
  reg [7:0] out_bytes[7:0];
  integer j;
  integer out_idx;

  always @* begin
    // default to zeros
    for (j = 0; j < 8; j = j + 1) begin
      out_bytes[j] = 8'h00;
    end

    out_idx = 0;
    for (j = 0; j < 8; j = j + 1) begin
      if (!remove[j]) begin
        if (out_idx < 8) begin
          out_bytes[out_idx] = b[j];
          out_idx = out_idx + 1;
        end
      end
    end
  end

  assign str_out = {out_bytes[0], out_bytes[1], out_bytes[2], out_bytes[3],
                    out_bytes[4], out_bytes[5], out_bytes[6], out_bytes[7]};

endmodule