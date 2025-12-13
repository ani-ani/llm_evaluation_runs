module max_payout(
  input clk,
  input rst_n,
  input start,
  input [7:0] card_count,
  input [31:0] card0,
  input [31:0] card1,
  input [31:0] card2,
  input [31:0] card3,
  input [31:0] card4,
  input [31:0] card5,
  input [31:0] card6,
  input [31:0] card7,
  output reg [31:0] max_avg,
  output reg done
);

  // Parameters
  localparam Q = 16;

  // State encoding
  localparam IDLE      = 2'b00;
  localparam CALC      = 2'b01;
  localparam DONE      = 2'b10;

  reg [1:0] state, next_state;

  // Indices
  reg [3:0] stop_idx;
  reg [3:0] start_idx;

  // Sum and counts
  reg signed [35:0] prefix_sum [0:8]; // signed sums for 0..i-1
  reg [3:0] prefix_cnt  [0:8];        // counts for 0..i-1

  reg signed [35:0] suffix_sum [0:8]; // signed sums for i..7
  reg [3:0] suffix_cnt  [0:8];        // counts for i..7

  reg prefix_valid;
  reg suffix_valid;

  reg [7:0] total_cards;

  reg [3:0] ps_idx; // prefix build index
  reg [3:0] ss_idx; // suffix build index

  // Per-pair computation
  reg signed [35:0] sum_val;
  reg [4:0] cnt_val; // up to 8

  reg [63:0] avg_val;

  // Max tracking
  reg [63:0] max_avg_ext;

  // Card array for easier access
  wire signed [31:0] cards [0:7];
  assign cards[0] = card0;
  assign cards[1] = card1;
  assign cards[2] = card2;
  assign cards[3] = card3;
  assign cards[4] = card4;
  assign cards[5] = card5;
  assign cards[6] = card6;
  assign cards[7] = card7;

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CALC;
        end
      end
      CALC: begin
        // Transition to DONE when all stop/start pairs processed
        if (prefix_valid && suffix_valid && (stop_idx == 4'd8)) begin
          next_state = DONE;
        end
      end
      DONE: begin
        // Return to IDLE after one cycle done pulse
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      done         <= 1'b0;
      max_avg      <= 32'd0;
      max_avg_ext  <= 64'd0;
      stop_idx     <= 4'd0;
      start_idx    <= 4'd0;
      prefix_valid <= 1'b0;
      suffix_valid <= 1'b0;
      ps_idx       <= 4'd0;
      ss_idx       <= 4'd0;
      total_cards  <= 8'd0;
      // Initialize prefix/suffix
      for (i = 0; i <= 8; i = i + 1) begin
        prefix_sum[i] <= 36'sd0;
        prefix_cnt[i] <= 4'd0;
        suffix_sum[i] <= 36'sd0;
        suffix_cnt[i] <= 4'd0;
      end
    end else begin
      state <= next_state;
      done  <= 1'b0; // default, pulsed in DONE

      case (state)
        IDLE: begin
          if (start) begin
            // Latch card_count and initialize
            total_cards  <= (card_count > 8'd8) ? 8'd8 : card_count;

            max_avg_ext  <= 64'd0;
            max_avg      <= 32'd0;

            // Initialize prefix index and base
            prefix_sum[0] <= 36'sd0;
            prefix_cnt[0] <= 4'd0;
            ps_idx        <= 4'd0;
            prefix_valid  <= 1'b0;

            // Initialize suffix index and will build from end
            ss_idx        <= 4'd0;
            suffix_valid  <= 1'b0;

            // Clear suffix arrays
            for (i = 0; i <= 8; i = i + 1) begin
              suffix_sum[i] <= 36'sd0;
              suffix_cnt[i] <= 4'd0;
            end

            stop_idx      <= 4'd0;
            start_idx     <= 4'd0;
          end
        end

        CALC: begin
          // Build prefix sums (0..i-1) for i from 1 to total_cards, rest mirror last
          if (!prefix_valid) begin
            if (ps_idx < total_cards) begin
              // Next index ps_idx+1
              // prefix_sum[i+1] = prefix_sum[i] + cards[i]
              // prefix_cnt[i+1] = prefix_cnt[i] + 1
              prefix_sum[ps_idx + 1] <= prefix_sum[ps_idx] + cards[ps_idx];
              prefix_cnt[ps_idx + 1] <= prefix_cnt[ps_idx] + 1'b1;
              ps_idx <= ps_idx + 1'b1;
            end else begin
              // For indices beyond total_cards up to 8, just mirror total_cards
              for (i = total_cards; i <= 8; i = i + 1) begin
                prefix_sum[i] <= prefix_sum[total_cards];
                prefix_cnt[i] <= prefix_cnt[total_cards];
              end
              prefix_valid <= 1'b1;
            end
          end

          // Build suffix sums for indices 0..8 representing from index to end
          // We'll treat missing cards (index >= total_cards) as none.
          if (!suffix_valid) begin
            if (ss_idx <= 8) begin
              // Build from end once when ss_idx == 0
              // We'll compute suffix from position 7 downto 0, but respecting total_cards.
              // Use ss_idx as a simple step counter: we do one suffix construction pass.
              if (ss_idx == 0) begin
                // Base at 8: no cards after index 8
                suffix_sum[8] <= 36'sd0;
                suffix_cnt[8] <= 4'd0;

                // Build downward combinationally in this cycle using blocking assignments
                // to keep under 100 cycles and avoid extra states.
                // Note: use a for-loop with temporary regs.
                integer j;
                reg signed [35:0] tmp_sum;
                reg [3:0] tmp_cnt;
                tmp_sum = 36'sd0;
                tmp_cnt = 4'd0;
                for (j = 7; j >= 0; j = j - 1) begin
                  if (j < total_cards) begin
                    tmp_sum = tmp_sum + cards[j];
                    tmp_cnt = tmp_cnt + 1'b1;
                    suffix_sum[j] <= tmp_sum;
                    suffix_cnt[j] <= tmp_cnt;
                  end else begin
                    suffix_sum[j] <= tmp_sum;
                    suffix_cnt[j] <= tmp_cnt;
                  end
                end
              end
              ss_idx <= ss_idx + 1'b1;
              if (ss_idx == 8) begin
                suffix_valid <= 1'b1;
              end
            end
          end

          // Once prefix and suffix tables are ready, iterate stop/start pairs
          if (prefix_valid && suffix_valid) begin
            if (stop_idx < 4'd8) begin
              if (start_idx <= 4'd8) begin
                if (start_idx > stop_idx) begin
                  // Compute sum and count for this (stop_idx, start_idx)
                  sum_val = prefix_sum[stop_idx] + suffix_sum[start_idx];
                  cnt_val = prefix_cnt[stop_idx] + suffix_cnt[start_idx];

                  if (cnt_val != 0) begin
                    // Fixed-point average: (sum << Q) / cnt
                    // Extend sign before shift
                    avg_val = ({{28{sum_val[35]}}, sum_val} <<< Q) / cnt_val;
                  end else begin
                    avg_val = 64'd0;
                  end

                  // Track maximum (treat as signed compare)
                  if ($signed(avg_val) > $signed(max_avg_ext)) begin
                    max_avg_ext <= avg_val;
                  end
                end

                // Next start_idx
                if (start_idx == 4'd8) begin
                  // End of start loop for this stop, move to next stop
                  start_idx <= 4'd0;
                  stop_idx  <= stop_idx + 1'b1;
                end else begin
                  start_idx <= start_idx + 1'b1;
                end
              end
            end
          end
        end

        DONE: begin
          // Drive outputs based on max_avg_ext
          max_avg <= max_avg_ext[31:0];
          done    <= 1'b1;
          // Next_state returns to IDLE (handled in FSM), no other changes here
        end

        default: begin
        end
      endcase
    end
  end

endmodule