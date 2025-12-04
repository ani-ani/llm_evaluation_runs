module puppy_recolor_check (
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0] valid_length,
  input  [127:0] string_in, // 16 x 8-bit ASCII characters
  output reg result,
  output reg done
);

  // Internal signals
  logic start_rise;
  logic [25:0] seen_onehot; // 26 bits, one per 'a'..'z'
  logic has_duplicate;

  // Edge detection for start
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      result <= 1'b0;
      start_rise <= 1'b0;
    end else begin
      // One-cycle pulse when start transitions 0->1
      start_rise <= start && !(start_rise);
      done <= start_rise; // done is valid for one cycle after start is sampled
    end
  end

  // Combinatorial check on each start_rise
  always_comb begin
    // Default: no duplicates seen
    seen_onehot = 26'b0;
    has_duplicate = 1'b0;

    if (valid_length >= 4'b0001) begin
      // Process 16 bytes (using only valid_length of them)
      for (int i = 0; i < 16; i = i + 1) begin
        if (i < valid_length) begin
          logic [7:0] ch;
          ch = string_in[i*8 +: 8];
          if ((ch >= 8'h61) && (ch <= 8'h7A)) begin
            int idx;
            idx = ch - 8'h61; // 'a'..'z' -> 0..25
            if (seen_onehot[idx]) begin
              has_duplicate = 1'b1; // Found a character that appears at least twice
            end else begin
              seen_onehot[idx] = 1'b1; // Mark first occurrence
            end
          end
          // Ignore non 'a'-'z' characters (do not affect duplicate detection)
        end
      end
    end
  end

  // Register result on the start_rise, keep it stable until next start
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 1'b0;
    end else if (start_rise) begin
      result <= (valid_length == 4'b0001) || has_duplicate; // Yes if length 1 or any repeat
    end
  end

endmodule
