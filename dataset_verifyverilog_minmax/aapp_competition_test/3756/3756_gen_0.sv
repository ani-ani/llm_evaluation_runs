module grade_rounder(
  input clk,              // clock signal
  input rst_n,            // active-low reset
  input start,            // pulse high to start processing
  input [3:0] grade_len,  // length of grade (1-15 chars)
  input [119:0] grade_in, // 15 ASCII chars (8-bits each, MSB aligned)
  input [2:0] t_in,       // max rounding steps (0-7)
  output reg [119:0] grade_out, // rounded result
  output reg [3:0] out_len,     // length of result
  output reg done          // high when computation complete
);

  localparam WIDTH = 15;
  localparam MAX_T = 4; // clamp t_in to 4 as per requirement
  localparam IDLE = 2'b00;
  localparam FIND_POSITION = 2'b01;
  localparam ROUND_PROPAGATE = 2'b10;
  localparam TRIM_TRAILING = 2'b11;

  // Registers
  logic [1:0] state, next_state;
  logic [3:0] len_r;
  logic [2:0] t_r;
  logic [3:0] decimals_r; // number of digits after decimal (clamped by len_r)
  logic decimal_found_r;
  logic [3:0] first_frac_idx_r; // index of first digit after '.', if found
  logic [3:0] last_frac_idx_r;  // index of last digit after '.', if found
  logic [3:0] last_non_ws_idx_r;
  logic [3:0] round_pos_r; // index (0..14) to round at, from LSB side (15-1-index)
  logic carry_r;
  logic carry_out_r;
  logic rounding_found_r;
  logic [119:0] work_r; // working copy of grade (ASCII)
  logic [3:0] nibbles_r [0:14]; // numeric digits (0-9) for [0]=MSB ... [14]=LSB
  logic [3:0] dec_after_trim_r;
  logic [3:0] first_nonzero_trim_r;

  // Helper functions for ASCII conversion
  function [3:0] ascii_to_digit (input [7:0] a);
    if (a >= "0" && a <= "9") return a - "0";
    else return 4'd0;
  endfunction

  function [3:0] digit_to_ascii (input [3:0] d);
    return 8'(48 + d);
  endfunction

  function is_digit (input [7:0] a);
    return (a >= "0" && a <= "9");
  endfunction

  function is_ws_or_dot_or_digit (input [7:0] a);
    return is_digit(a) || a == "." || a == " " || a == "\t";
  endfunction

  // State register with async reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
    end else begin
      state <= next_state;
      done <= (next_state == IDLE);
    end
  end

  // Combinational next-state logic and datapath
  always @(*) begin
    // Defaults (keep values)
    next_state = state;
    len_r = len_r;
    t_r = t_r;
    decimals_r = decimals_r;
    decimal_found_r = decimal_found_r;
    first_frac_idx_r = first_frac_idx_r;
    last_frac_idx_r = last_frac_idx_r;
    last_non_ws_idx_r = last_non_ws_idx_r;
    round_pos_r = round_pos_r;
    carry_r = carry_r;
    carry_out_r = carry_out_r;
    rounding_found_r = rounding_found_r;
    work_r = work_r;
    dec_after_trim_r = dec_after_trim_r;
    first_nonzero_trim_r = first_nonzero_trim_r;
    for (int i=0;i<15;i++) nibbles_r[i] = nibbles_r[i];

    if (state == IDLE) begin
      // Latch inputs and clear outputs on start pulse
      if (start) begin
        len_r = grade_len;
        t_r = (t_in > MAX_T) ? MAX_T : t_in; // clamp to 4
        work_r = grade_in;
        done = 1'b0;
        // clear caches
        decimal_found_r = 1'b0;
        decimals_r = 4'd0;
        first_frac_idx_r = 4'd0;
        last_frac_idx_r = 4'd0;
        last_non_ws_idx_r = 4'd0;
        round_pos_r = 4'd0;
        carry_r = 1'b0;
        carry_out_r = 1'b0;
        rounding_found_r = 1'b0;
        for (int i=0;i<15;i++) nibbles_r[i] = 4'd0;
        next_state = FIND_POSITION;
      end
    end

    else if (state == FIND_POSITION) begin
      // Scan at most len_r chars to:
      // - convert digits to nibbles
      // - locate decimal (only first '.' considered)
      // - count fractional digits after '.',
      // - find first digit >=5 within t_r steps after decimal
      // - find last non-ws/dot/digit to keep output length bounded
      automatic logic [3:0] idx = 4'd0;
      automatic logic [3:0] dec_start = 4'd0; // first digit after '.'
      automatic logic [3:0] dec_count = 4'd0;
      automatic logic dec_seen = 1'b0;
      automatic logic found = 1'b0;
      automatic logic [3:0] rpos = 4'd0; // rounding position index in 0..14 from LSB side
      for (int k=0;k<15;k++) nibbles_r[k] = 4'd0; // reset nibbles on entry
      for (int i=0; i<15; i++) begin
        if (i < len_r) begin
          automatic logic [7:0] ch = work_r[119 - i*8 -: 8];
          if (is_digit(ch)) begin
            nibbles_r[i] = ascii_to_digit(ch);
            if (dec_seen) dec_count = dec_count + 1;
          end else begin
            nibbles_r[i] = 4'd0;
          end
          // track last non ws/dot/digit (valid visible char) to bound output length
          if (is_ws_or_dot_or_digit(ch)) last_non_ws_idx_r = i;
          // detect first decimal point
          if (!dec_seen && ch == ".") begin
            dec_seen = 1'b1;
            dec_start = i + 1; // first digit index after '.', may exceed len_r
          end
          // find first digit >=5 in allowed steps after decimal
          if (!found && dec_seen && (i >= dec_start) && ((i - dec_start) < t_r) && nibbles_r[i] >= 4'd5) begin
            // rounding at previous digit (i-1). map to LSB-side index:
            if (i > 0) begin
              rpos = 4'(WIDTH - i); // e.g., i=14 -> rpos=1 (LSB), i=13 -> rpos=2, ..., i=1 -> rpos=14
              found = 1'b1;
            end else begin
              // rounding before first character (i==0): all digits are fractional, none exist => no rounding possible
              found = 1'b0;
            end
          end
        end
      end
      decimal_found_r = dec_seen;
      decimals_r = dec_count;
      first_frac_idx_r = dec_start;
      last_frac_idx_r = (dec_seen ? (4'(WIDTH-1) - 4'(len_r - 1) + dec_count - 1) : 4'd0); // last fractional index (0..14 from LSB side)
      rounding_found_r = found;
      round_pos_r = rpos;

      // If no rounding needed, trim and finish this cycle (2-cycle finish)
      if (!rounding_found_r) begin
        // Prepare to trim trailing zeros after decimal: keep at least one fractional digit
        // Compute boundaries and minimal index after decimal for next cycle
        automatic logic [3:0] dec_after = decimals_r;
        automatic logic [3:0] first_nz = 4'd15; // default off-scale
        automatic logic last_digit_idx = 4'(WIDTH-1) - 4'(len_r - 1); // LSB index
        for (int j=0;j<15;j++) begin
          // consider only indices >= first_frac_idx_r and <= last_digit_idx
          if (j >= first_frac_idx_r && j <= last_digit_idx) begin
            if (nibbles_r[j] != 4'd0 && first_nz == 4'd15) first_nz = j;
          end
        end
        dec_after_trim_r = dec_after;
        first_nonzero_trim_r = (first_nz == 4'd15) ? 4'd0 : first_nz;
        next_state = TRIM_TRAILING;
      end else begin
        next_state = ROUND_PROPAGATE;
      end
    end

    else if (state == ROUND_PROPAGATE) begin
      // Rounding + ripple carry
      // Carry into LSB; round_pos_r in 1..14 (no wrap at MSB allowed by constraints)
      automatic logic [3:0] carry = 4'd1; // we know rounding_found_r implies >=5, so add 1
      for (int i=14; i>=0; i--) begin
        automatic logic [3:0] new_sum = nibbles_r[i] + carry;
        if (new_sum >= 4'd10) begin
          nibbles_r[i] = new_sum - 4'd10;
          carry = 4'd1;
        end else begin
          nibbles_r[i] = new_sum;
          carry = 4'd0;
        end
        if (i == round_pos_r) carry = 4'd0; // stop propagation after the rounding position
      end
      carry_out_r = (carry != 4'd0);

      // Reset all digits after rounding position (towards LSB)
      for (int j=1; j<15; j++) begin
        if (j > round_pos_r) nibbles_r[WIDTH - j] = 4'd0;
      end

      // Prepare for trimming: compute boundaries and minimal fractional index kept
      automatic logic [3:0] dec_after = decimals_r;
      automatic logic [3:0] first_nz = 4'd15;
      automatic logic [3:0] last_digit_idx = 4'(WIDTH-1) - 4'(len_r - 1);
      for (int j=0;j<15;j++) begin
        if (j >= first_frac_idx_r && j <= last_digit_idx) begin
          if (nibbles_r[j] != 4'd0 && first_nz == 4'd15) first_nz = j;
        end
      end
      dec_after_trim_r = dec_after;
      first_nonzero_trim_r = (first_nz == 4'd15) ? 4'd0 : first_nz;
      next_state = TRIM_TRAILING;
    end

    else if (state == TRIM_TRAILING) begin
      // Build ASCII result: convert nibbles to ASCII and set to spaces outside visible range.
      // Then trim trailing zeros after decimal but keep at least one fractional digit if decimal exists.
      automatic logic [3:0] visible_len = last_non_ws_idx_r + 1;
      automatic logic [3:0] end_trim = visible_len; // exclusive index in nibble space
      if (decimal_found_r) begin
        automatic logic [3:0] min_frac_idx;
        if (dec_after_trim_r == 4'd0) begin
          // No fractional digits kept, keep at least one zero ('.0' at LSB)
          min_frac_idx = WIDTH - 1; // LSB index
        end else begin
          // Keep fractional digits up to first nonzero; if none, keep only one zero
          if (first_nonzero_trim_r == 4'd0) begin
            // all zeros after decimal; keep one digit at LSB
            min_frac_idx = WIDTH - 1;
          end else begin
            // keep digits up to first_nonzero_trim_r (inclusive)
            min_frac_idx = first_nonzero_trim_r;
          end
        end
        // Trim trailing characters after min_frac_idx
        for (int k=WIDTH-1; k>min_frac_idx; k--) begin
          if (k < visible_len) end_trim = k; // shrink visible length to k
        end
      end else begin
        // No decimal: no trimming (keep all)
        end_trim = visible_len;
      end

      // Build output bytes
      for (int i=0; i<WIDTH; i++) begin
        if (i < end_trim) begin
          work_r[119 - i*8 -: 8] = digit_to_ascii(nibbles_r[i]);
        end else begin
          work_r[119 - i*8 -: 8] = 8'd32; // space
        end
      end
      grade_out = work_r;
      out_len = end_trim;
      next_state = IDLE;
    end

    else begin
      next_state = IDLE;
    end
  end
endmodule
