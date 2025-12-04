module longest_string (
  input [3:0] num_valid, // Valid string count (0-8)
  input reg [63:0] strings [0:7], // 8 strings, 64 bits each (8 bytes)
  input reg [3:0] lengths [0:7], // 8 length values, 0-8 each
  output logic [63:0] longest_str, // First longest string
  output logic valid // 1 if result valid, 0 if no strings
);
  // Internal signals for finding the longest string among the first num_valid entries.
  logic [3:0] max_len;
  logic [63:0] cand;
  logic [3:0] i;

  always_comb begin
    // Default assignments to avoid latches
    valid = 1'b0;
    longest_str = 64'b0;
    max_len = 4'b0;
    cand = 64'b0;

    // If no valid strings, output remains zero and valid=0.
    if (num_valid > 4'd0) begin
      valid = 1'b1;
      // Initialize with the first valid string.
      cand = strings[0];
      max_len = lengths[0];
      // Scan the remaining entries (1..7) and consider only if i < num_valid.
      for (i = 4'd1; i < 4'd8; i = i + 4'd1) begin
        if (i < num_valid) begin
          if (lengths[i] > max_len) begin
            max_len = lengths[i];
            cand = strings[i];
          end
          // If tie, keep the first occurrence (do nothing).
        end
      end
      longest_str = cand;
    end
  end
endmodule
