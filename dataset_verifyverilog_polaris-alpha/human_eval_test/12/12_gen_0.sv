module longest_string(
  input  [3:0]        num_valid,   // Valid string count (0-8)
  input  [7:0][63:0]  strings,     // 8 strings, 64 bits each
  input  [7:0][3:0]   lengths,     // 8 length values, 0-8 each
  output reg [63:0]  longest_str, // First longest string
  output reg         valid        // 1 if result valid, 0 if no strings
);

  integer i;
  reg [3:0] max_len;
  reg [2:0] max_idx;

  always @* begin
    // Default outputs
    valid       = (num_valid != 4'd0);
    longest_str = 64'd0;
    max_len     = 4'd0;
    max_idx     = 3'd0;

    if (num_valid != 4'd0) begin
      // Initialize with first valid entry (index 0)
      max_len = lengths[0];
      max_idx = 3'd0;
      longest_str = strings[0];

      // Scan remaining valid entries (1 to num_valid-1)
      for (i = 1; i < num_valid; i = i + 1) begin
        if (lengths[i] > max_len) begin
          max_len     = lengths[i];
          max_idx     = i[2:0];
          longest_str = strings[i];
        end
      end
    end
  end

endmodule