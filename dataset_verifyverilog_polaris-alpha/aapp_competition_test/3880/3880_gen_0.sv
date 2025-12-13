module max_array_sum(
  input              clk,
  input              rst_n,
  input              start,
  input      [3:0]   n_mode,
  input      [15:0]  data [14:0],
  output reg [15:0]  max_sum,
  output reg         done
);

  // Internal registers
  reg        [4:0]   idx;          // index up to 14
  reg        [4:0]   valid_len;    // 2*n_mode-1 (max 15)
  reg        [4:0]   neg_count;    // count of negative elements
  reg        [16:0]  sum_abs;      // sum of abs (max 15 * 32768 = 20 bits, but we later clip to 16)
  reg        [15:0]  min_abs;      // minimum absolute value
  reg        [4:0]   cycle;        // for fixed 20-cycle schedule
  reg                processing;   // high during active operation

  // Helper wires
  wire               start_pulse;
  reg                start_d;

  // Start pulse detection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end

  assign start_pulse = start & ~start_d;

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      idx        <= 5'd0;
      valid_len  <= 5'd0;
      neg_count  <= 5'd0;
      sum_abs    <= 17'd0;
      min_abs    <= 16'd32767;
      cycle      <= 5'd0;
      processing <= 1'b0;
      max_sum    <= 16'd0;
      done       <= 1'b0;
    end else begin
      // Default done de-assert unless held after completion
      if (start_pulse) begin
        // Initialize on new start
        valid_len  <= (n_mode << 1) - 1;   // 2*n_mode - 1
        idx        <= 5'd0;
        neg_count  <= 5'd0;
        sum_abs    <= 17'd0;
        min_abs    <= 16'd32767;
        cycle      <= 5'd0;
        processing <= 1'b1;
        done       <= 1'b0;
      end else if (processing) begin
        cycle <= cycle + 5'd1;

        // Phase 0-14: iterate through elements
        if (cycle < 5'd15) begin
          if (idx < valid_len) begin
            // interpret data[idx] as signed
            // sign-extend for absolute computation
            wire signed [15:0] val_s;
            assign val_s = data[idx];
            wire [15:0] abs_val;
            assign abs_val = val_s[15] ? (~val_s + 16'd1) : val_s;

            // accumulate absolute sum
            sum_abs <= sum_abs + abs_val;

            // count negatives
            if (val_s[15]) begin
              neg_count <= neg_count + 5'd1;
            end

            // track minimum absolute value
            if (abs_val < min_abs) begin
              min_abs <= abs_val;
            end
          end

          idx <= idx + 5'd1;
        end
        // Phase 15-18: compute result (3 cycles available, but simple combinational here)
        else if (cycle == 5'd15) begin
          // Compute max_sum based on parity rules
          // Condition: if n is odd OR number of negatives is even -> use sum_abs
          // else -> sum_abs - 2*min_abs
          if (n_mode[0] == 1'b1 || neg_count[0] == 1'b0) begin
            // clip to 16 bits (sum_abs fit expected constraints)
            max_sum <= sum_abs[15:0];
          end else begin
            // subtract 2*min_abs
            // result fits in 17 bits; clip to 16 bits
            max_sum <= (sum_abs - {1'b0, (min_abs << 1)})[15:0];
          end
        end else if (cycle == 5'd16) begin
          // Hold computed result
          max_sum <= max_sum;
        end else if (cycle == 5'd17) begin
          // Assert done
          done <= 1'b1;
        end else if (cycle >= 5'd19) begin
          // End processing at cycle 19 (20 cycles total: 0..19)
          processing <= 1'b0;
          cycle      <= 5'd19;
        end
      end
      // When not processing, hold last result and done until next start
    end
  end

endmodule