module file_name_checker (
  input clk,
  input rst_n,
  input start,
  input [127:0] file_name,
  output reg valid,
  output reg done
);

  // Internal signals
  wire [7:0] byte_data;             // Current 8-bit chunk of file_name
  reg [3:0] char_cnt;               // 0..15 (counts nibbles)
  reg [2:0] dot_idx;                // Index of dot if seen, else 3'b111
  reg [1:0] dot_cnt;                // Count of dots (0,1,2+)
  reg [1:0] suffix_len;             // Length of suffix after dot (0..3)
  reg prefix_ok;                    // Prefix is valid so far
  reg early_invalid;                // Multiple dots or invalid suffix length
  reg [3:0] digit_cnt;              // Count of digits in whole name

  // Byte addressing from nibble count
  // char_cnt[3] selects low(0)/high(1) nibble; char_cnt[2:0] selects byte 0..7
  assign byte_data = char_cnt[3] ? file_name[(char_cnt[2:0]*8)+:8] : file_name[(char_cnt[2:0]*8)+:8];

  // Latch-once start to guarantee a clean 16-cycle run
  reg run_q;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) run_q <= 1'b0;
    else if (start) run_q <= 1'b1;
    else if (char_cnt == 4'd15) run_q <= 1'b0; // complete 16 chars
  end

  // Idle condition: not running and not in the post-process cycle
  wire idle = !run_q && !done;

  // Nibble/byte processing (1 char per clock)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      char_cnt <= 4'd0;
      dot_idx <= 3'b111;
      dot_cnt <= 2'd0;
      suffix_len <= 2'd0;
      prefix_ok <= 1'b0;
      early_invalid <= 1'b0;
      digit_cnt <= 4'd0;
      valid <= 1'b0;
      done <= 1'b0;
    end else if (idle) begin
      // Idle/reset defaults
      char_cnt <= 4'd0;
      dot_idx <= 3'b111;
      dot_cnt <= 2'd0;
      suffix_len <= 2'd0;
      prefix_ok <= 1'b0;
      early_invalid <= 1'b0;
      digit_cnt <= 4'd0;
      valid <= 1'b0;
      done <= 1'b0;
    end else if (run_q) begin
      // Per-character updates
      // Update char index
      if (char_cnt == 4'd0) begin
        char_cnt <= 4'd1;
      end else begin
        char_cnt <= char_cnt + 4'd1;
      end

      // Digit count (0..9)
      if (byte_data >= 8'd48 && byte_data <= 8'd57) begin
        digit_cnt <= digit_cnt + 4'd1;
      end

      // Early invalidation triggers (multi-dot, or suffix too long early)
      if (dot_cnt == 2'd1 && byte_data == 8'd46) begin
        early_invalid <= 1'b1; // more than one dot found
      end
      if (dot_cnt == 2'd1) begin
        if (suffix_len >= 2'd3) begin
          early_invalid <= 1'b1; // suffix already too long before end
        end else begin
          suffix_len <= suffix_len + 2'd1; // extend suffix length by 1 char
        end
      end

      // Dot seen for the first time? Latch its index and initialize per-dot state
      if (dot_cnt == 2'd0 && byte_data == 8'd46) begin
        dot_idx <= char_cnt[2:0];        // remember position of the dot
        dot_cnt <= 2'd1;                 // mark first dot seen
        prefix_ok <= 1'b0;               // will be set below if prefix is valid
        // suffix_len already 0, early_invalid 0
      end else begin
        // Prefix validation (before dot)
        if (dot_cnt == 2'd0) begin
          // A-Z: 41..5A, a-z: 61..7A
          if (byte_data >= 8'd65 && byte_data <= 8'd90) begin
            prefix_ok <= 1'b1;
          end else if (byte_data >= 8'd97 && byte_data <= 8'd122) begin
            prefix_ok <= 1'b1;
          end else begin
            prefix_ok <= 1'b0; // invalid character in prefix
          end
        end
      end

      // Note: Outputs valid/done are updated in the post-process cycle below.
    end else if (done) begin
      // One-cycle 'done' pulse
      done <= 1'b0;
      valid <= 1'b0;
    end else begin
      // Post-process cycle: evaluate result (cycle 17 after start)
      // Compute suffix check
      if (dot_idx != 3'b111 && suffix_len == 2'd3) begin
        // Extract last 3 bytes after the dot index
        // byte 0 is at bits [7:0], byte 1 at [15:8], etc.
        logic [7:0] s0, s1, s2;
        s0 = file_name[(dot_idx*8)+:8];
        s1 = file_name[((dot_idx+1)*8)+:8];
        s2 = file_name[((dot_idx+2)*8)+:8];

        if ((s0 == 8'd116 && s1 == 8'd120 && s2 == 8'd116) || // "txt"
            (s0 == 8'd101 && s1 == 8'd120 && s2 == 8'd101) || // "exe"
            (s0 == 8'd100 && s1 == 8'd108 && s2 == 8'd108))   // "dll"
        begin
          valid <= 1'b1;
        end else begin
          valid <= 1'b0;
        end
      end else begin
        valid <= 1'b0;
      end

      // Enforce conditions
      if (dot_cnt != 2'd1 || !prefix_ok || early_invalid || digit_cnt > 4'd3) begin
        valid <= 1'b0;
      end

      done <= 1'b1;
    end
  end

endmodule
