module longest_repeating_substring (
  input  clk,
  input  rst_n,
  input  start,
  input  [15:0][7:0] str,
  input  [3:0] length,
  output reg [3:0] max_len,
  output reg done
);

  // Internal state
  reg [3:0] cur_len;
  reg [3:0] i_idx;   // current substring start index for left operand
  reg [3:0] j_idx;   // current substring start index for right operand (must be > i_idx)
  reg [4:0] k;       // character position within the substring (0 .. cur_len-1)
  reg dup [16][16];  // duplicate markers for current length
  reg [8:0] cycle;   // 9-bit counter (0..255) to guarantee completion within 256 cycles

  // Determine if the current compared substrings of length 'cur_len' are equal
  // by checking byte-by-byte from k=0 to cur_len-1.
  // Use generate to avoid invalid 0-width ranges.
  wire equal_prev;
  generate
    if (1 <= 1) begin : G_EQ_1
      assign equal_prev = (k == 0) ? 1'b1 : 1'b0;
    end else begin
      assign equal_prev = 1'b1; // unreachable for this design
    end
  endgenerate

  generate
    for (genvar g = 1; g <= 15; g++) begin : G_EQ
      if (g <= 1) begin
        // k == 0: no previous bytes to compare, equality starts as true
        assign equal_prev = (k == 0) ? 1'b1 : 1'b0;
      end else begin
        // For k >= 1, build equality as (prev_equal && str[j_idx + (k-1)] == str[i_idx + (k-1)])
        // Latches are fine here; value is sampled with clock.
        if (g == 1) begin
          // Base case k==1
          always @(*) equal_prev = (k == 0) ? 1'b1 : (str[j_idx] == str[i_idx]);
        end else begin
          always @(*) equal_prev = (k == 0) ? 1'b1 : ((k == g) ? (str[j_idx + (g-1)] == str[i_idx + (g-1)]) : 1'b0);
        end
      end
    end
  endgenerate

  // Correct equality logic: evaluate dynamically based on current k
  wire eq_char;
  assign eq_char = (k == 0) ? 1'b1 : (str[j_idx + (k-1)] == str[i_idx + (k-1)]);

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_len  <= 4'd0;
      done     <= 1'b0;
      cur_len  <= 4'd0;
      i_idx    <= 4'd0;
      j_idx    <= 4'd0;
      k        <= 5'd0;
      cycle    <= 9'd0;
      // Array reset (Simulation-friendly static initialization)
      for (int a = 0; a < 16; a++) begin
        for (int b = 0; b < 16; b++) begin
          dup[a][b] <= 1'b0;
        end
      end
    end else if (start) begin
      // Initialize for a new run
      max_len  <= 4'd0;
      done     <= 1'b0;
      cur_len  <= (length == 4'd0) ? 4'd0 : ((length - 1) > 4'd15 ? 4'd15 : (length - 1));
      i_idx    <= 4'd0;
      j_idx    <= 4'd1;
      k        <= 5'd0;
      cycle    <= 9'd0;
      for (int a = 0; a < 16; a++) begin
        for (int b = 0; b < 16; b++) begin
          dup[a][b] <= 1'b0;
        end
      end
    end else if (!done) begin
      // Iterate per cycle: advance or advance to the next length
      if (cur_len == 4'd0) begin
        // No possible length -> complete
        max_len  <= 4'd0;
        done     <= 1'b1;
        cycle    <= cycle + 1;
      end else begin
        // 1) Attempt to mark a duplicate pair for current length
        if (i_idx + cur_len <= length && j_idx + cur_len <= length) begin
          dup[j_idx][i_idx] <= eq_char;
          // Advance character position within substring
          k <= k + 1;

          // If finished comparing this pair and equal, we can terminate early
          if ((k + 1) == cur_len && eq_char) begin
            max_len <= cur_len;
            done    <= 1'b1;
          end else begin
            // Move to next pair or next character within the same pair
            if ((k + 1) < cur_len) begin
              // Stay on same i,j; move to next character
              i_idx <= i_idx;
              j_idx <= j_idx;
            end else begin
              // End of current pair -> choose next j; if j exceeds, choose next i
              if (j_idx + 1 < length) begin
                j_idx <= j_idx + 1;
                i_idx <= i_idx;
                k     <= 5'd0;
              end else if (i_idx + 1 + cur_len <= length) begin
                i_idx <= i_idx + 1;
                j_idx <= i_idx + 2; // ensure j > i
                k     <= 5'd0;
              end else begin
                // No more pairs for this length -> check if any duplicates were found
                // If no duplicates, move to next smaller cur_len
                if (|dup) begin
                  max_len <= cur_len;
                  done    <= 1'b1;
                end else begin
                  cur_len <= (cur_len > 1) ? (cur_len - 1) : 4'd0;
                  i_idx   <= 4'd0;
                  j_idx   <= 4'd1;
                  k       <= 5'd0;
                end
              end
            end
          end
          cycle <= cycle + 1;
        end else begin
          // Out-of-bounds for this (i,j) -> move on
          if (j_idx + 1 < length) begin
            j_idx <= j_idx + 1;
            i_idx <= i_idx;
            k     <= 5'd0;
            // No duplicate marked this cycle
            dup[j_idx][i_idx] <= dup[j_idx][i_idx]; // keep
          end else if (i_idx + 1 + cur_len <= length) begin
            i_idx <= i_idx + 1;
            j_idx <= i_idx + 2;
            k     <= 5'd0;
            dup[j_idx][i_idx] <= dup[j_idx][i_idx]; // keep
          end else begin
            if (|dup) begin
              max_len <= cur_len;
              done    <= 1'b1;
            end else begin
              cur_len <= (cur_len > 1) ? (cur_len - 1) : 4'd0;
              i_idx   <= 4'd0;
              j_idx   <= 4'd1;
              k       <= 5'd0;
            end
            dup[j_idx][i_idx] <= dup[j_idx][i_idx]; // keep
          end
          cycle <= cycle + 1;
        end
      end
    end
  end
endmodule
