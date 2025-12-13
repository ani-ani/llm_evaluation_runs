module cake_partition_checker(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [1:0] m,
  input [15:0] r,
  input [15:0] candle_x [0:7],
  input [15:0] candle_y [0:7],
  input [7:0]  cut_a   [0:3],
  input [7:0]  cut_b   [0:3],
  input [15:0] cut_c   [0:3],
  output reg result,
  output reg done
);

  // Internal registers
  reg [4:0] cycle_cnt;              // 0..24
  reg [2:0] cand_idx;               // 0..7
  reg [1:0] cut_idx;                // 0..3
  reg [3:0] sig [0:7];              // signature per candle
  reg       fail_flag;

  // Signed operands for 30-bit computation
  reg  signed [7:0]  a_s;
  reg  signed [7:0]  b_s;
  reg  signed [15:0] x_s;
  reg  signed [15:0] y_s;
  reg  signed [15:0] c_s;

  reg  signed [23:0] ax;
  reg  signed [23:0] by;
  reg  signed [24:0] sum_ab;
  reg  signed [29:0] total;

  reg         phase_mul;            // 0: compute ax/by, 1: finalize & set bit

  // Control for signature bit position
  wire [3:0] bit_pos = (4'd1 << cut_idx);

  // Combinational: evaluate sign and update bit in next cycle via regs
  reg bit_set;

  always @(*) begin
    bit_set = 1'b0;
    if (phase_mul) begin
      // sum_ab = ax + by (already registered), then add c_s
      // total is formed in sequential always block; here only determine sign
      if (total > 0)
        bit_set = 1'b1;
      else
        bit_set = 1'b0;
    end
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt  <= 5'd0;
      cand_idx   <= 3'd0;
      cut_idx    <= 2'd0;
      phase_mul  <= 1'b0;
      fail_flag  <= 1'b0;
      done       <= 1'b0;
      result     <= 1'b0;
      ax         <= 24'sd0;
      by         <= 24'sd0;
      sum_ab     <= 25'sd0;
      total      <= 30'sd0;
      a_s        <= 8'sd0;
      b_s        <= 8'sd0;
      x_s        <= 16'sd0;
      y_s        <= 16'sd0;
      c_s        <= 16'sd0;
    end else begin
      // Default: hold
      done <= 1'b0;

      // Start condition re-initializes internal state
      if (start && cycle_cnt == 5'd0) begin
        cycle_cnt <= 5'd1;          // begin pipeline after start
        cand_idx  <= 3'd0;
        cut_idx   <= 2'd0;
        phase_mul <= 1'b0;
        fail_flag <= 1'b0;
        result    <= 1'b0;
        ax        <= 24'sd0;
        by        <= 24'sd0;
        sum_ab    <= 25'sd0;
        total     <= 30'sd0;
        a_s       <= 8'sd0;
        b_s       <= 8'sd0;
        x_s       <= 16'sd0;
        y_s       <= 16'sd0;
        c_s       <= 16'sd0;
        // clear signatures
        sig[0]    <= 4'd0;
        sig[1]    <= 4'd0;
        sig[2]    <= 4'd0;
        sig[3]    <= 4'd0;
        sig[4]    <= 4'd0;
        sig[5]    <= 4'd0;
        sig[6]    <= 4'd0;
        sig[7]    <= 4'd0;
      end else if (cycle_cnt != 5'd0 && cycle_cnt < 5'd25) begin
        cycle_cnt <= cycle_cnt + 5'd1;

        // Phase 0/1: compute signatures over cycles 1-24
        if (cycle_cnt <= 5'd24) begin
          if (!phase_mul) begin
            // Setup operands and perform ax, by
            a_s <= cut_a[cut_idx];
            b_s <= cut_b[cut_idx];
            x_s <= candle_x[cand_idx];
            y_s <= candle_y[cand_idx];
            c_s <= cut_c[cut_idx];

            ax  <= $signed(cut_a[cut_idx]) * $signed(candle_x[cand_idx]);
            by  <= $signed(cut_b[cut_idx]) * $signed(candle_y[cand_idx]);

            phase_mul <= 1'b1;
          end else begin
            // Finish: sum and determine sign
            sum_ab <= ax + by;
            total  <= {{5{sum_ab[24]}}, sum_ab} + {{14{c_s[15]}}, c_s};

            // Update signature bit for this candle and cut
            if (bit_set) begin
              sig[cand_idx] <= sig[cand_idx] | bit_pos;
            end

            // Advance indices
            if (cut_idx == (m - 1)) begin
              cut_idx <= 2'd0;
              if (cand_idx == (n - 1)) begin
                cand_idx <= 3'd0; // done all needed; remaining cycles idle
              end else begin
                cand_idx <= cand_idx + 3'd1;
              end
            end else begin
              cut_idx <= cut_idx + 2'd1;
            end

            phase_mul <= 1'b0;
          end
        end

        // At cycle 25 (next state), we will do uniqueness check
        if (cycle_cnt == 5'd24) begin
          // Perform uniqueness check combinationally here and latch on next
          // But requirement says 25 cycles total; we'll check at 25th cycle
        end
      end else if (cycle_cnt == 5'd25) begin
        // Uniqueness check at fixed cycle 25
        // Compare signatures for first n candles
        integer i, j;
        fail_flag <= 1'b0;
        for (i = 0; i < 8; i = i + 1) begin
          if (i < n) begin
            for (j = i + 1; j < 8; j = j + 1) begin
              if (j < n) begin
                if (sig[i] == sig[j]) begin
                  fail_flag <= 1'b1;
                end
              end
            end
          end
        end

        result <= (fail_flag == 1'b0) ? 1'b1 : 1'b0;
        done   <= 1'b1;
        cycle_cnt <= 5'd0; // ready for next start
      end
    end
  end

endmodule