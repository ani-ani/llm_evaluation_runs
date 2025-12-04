module char_remover (
  input  [63:0] str_in,
  input  [7:0]  ch,
  output [63:0] str_out
);

  // Big-endian interpretation: str_in[63:56] is byte 0 (first char), ... str_in[7:0] is byte 7 (last char)
  wire [7:0] bytes_in [0:7];
  genvar i;
  for (i = 0; i < 8; i = i + 1) begin : unpack_bytes
    assign bytes_in[i] = str_in[56 - 8*i +: 8];
  end

  // Scan for first and last occurrence
  integer idx;
  integer first_idx, last_idx;
  initial begin
    first_idx = -1;
    last_idx  = -1;
    for (idx = 0; idx < 8; idx = idx + 1) begin
      if (bytes_in[idx] == ch) begin
        if (first_idx == -1) first_idx = idx;
        last_idx = idx;
      end
    end
  end

  // Build output bytes by compacting non-removed characters to the left
  wire [7:0] bytes_out [0:7];
  reg [2:0] write_ptr; // 0..7
  reg [7:0] keep_mask; // bit j=1 means keep byte_in[j]
  reg [7:0] rem_first, rem_last;

  initial begin
    // Defaults
    write_ptr = 3'd0;
    keep_mask = 8'hFF; // keep all unless removed
    rem_first = 8'h00; // no first removal by default
    rem_last  = 8'h00; // no last removal by default
    if (first_idx != -1) begin
      rem_first = 1 << first_idx;
      if (last_idx != -1) begin
        if (last_idx != first_idx) begin
          rem_last = 1 << last_idx;
        end
      end
      keep_mask = ~(rem_first | rem_last);
    end
  end

  reg [7:0] tmp_out [0:7];
  initial begin
    // Compact bytes
    write_ptr = 3'd0;
    for (idx = 0; idx < 8; idx = idx + 1) begin
      if (keep_mask[idx]) begin
        tmp_out[write_ptr] = bytes_in[idx];
        write_ptr = write_ptr + 1;
      end
    end
    // Zero-fill the rest
    for (idx = write_ptr; idx < 8; idx = idx + 1) begin
      tmp_out[idx] = 8'h00;
    end
  end

  // Pack output (big-endian: byte 0 -> [63:56], ... byte 7 -> [7:0])
  for (i = 0; i < 8; i = i + 1) begin : pack_bytes
    assign str_out[56 - 8*i +: 8] = tmp_out[i];
  end

endmodule
