module max_payout(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start computation when high
  input [7:0] card_count, // number of cards (0-8)
  input [31:0] card0, // card value (signed)
  input [31:0] card1, // card value (signed)
  input [31:0] card2, // card value (signed)
  input [31:0] card3, // card value (signed)
  input [31:0] card4, // card value (signed)
  input [31:0] card5, // card value (signed)
  input [31:0] card6, // card value (signed)
  input [31:0] card7, // card value (signed)
  output reg [31:0] max_avg, // maximum average payout in Q16.16 format
  output reg done // high when computation completes
);

  parameter Q = 16; // fractional bits for fixed-point
  localparam N = 8;

  // State machine
  typedef enum logic [1:0] {IDLE, CALC, DONE} state_t;
  state_t state, next_state;

  // Pipelined/combinational path registers
  reg [7:0] count_r, stop_r, start_r;
  reg pre_zero_r, post_zero_r;
  reg [63:0] pre_sum_r, post_sum_r; // signed sums (up to ~34 bits for 8 * 2^31)

  // Iteration counters
  reg [3:0] stop_idx, next_stop_idx;
  reg [3:0] start_idx, next_start_idx;

  // Feedback accumulators for partial sums
  reg [63:0] pre_acc, next_pre_acc;
  reg [63:0] post_acc, next_post_acc;

  // Current best
  reg [31:0] best, next_best;

  // Current candidate (Q16.16)
  wire [31:0] cur_avg;
  wire [63:0] numer = (pre_sum_r + post_sum_r) << Q; // scaled numerator
  wire [7:0] denom = (stop_r - (pre_zero_r ? 0 : 0)) + ((~post_zero_r) ? (count_r - start_r) : 0);

  // Fixed-point division: cur_avg = numer / denom (Q16.16)
  assign cur_avg = (denom == 8'b0) ? 32'sh0 : $signed(numer[63:0]) / $signed(denom);

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      max_avg <= 32'sh0;
      stop_idx <= 4'b0;
      start_idx <= 4'b0;
      pre_acc <= 64'sh0;
      post_acc <= 64'sh0;
      best <= 32'sh0;
      // pipeline stage
      count_r <= 8'b0;
      stop_r <= 8'b0;
      start_r <= 8'b0;
      pre_zero_r <= 1'b0;
      post_zero_r <= 1'b0;
      pre_sum_r <= 64'sh0;
      post_sum_r <= 64'sh0;
    end else begin
      state <= next_state;
      done <= (next_state == DONE);
      max_avg <= next_best;
      stop_idx <= next_stop_idx;
      start_idx <= next_start_idx;
      pre_acc <= next_pre_acc;
      post_acc <= next_post_acc;
      best <= next_best;

      // pipeline stage update (sample inputs for this cycle)
      count_r <= card_count;
      stop_r <= stop_idx;
      start_r <= start_idx;
      pre_zero_r <= (stop_idx == 8'b0);
      post_zero_r <= (start_idx == count_r);
      pre_sum_r <= next_pre_acc;
      post_sum_r <= next_post_acc;
    end
  end

  // Combinational next-state logic
  always_comb begin
    // defaults
    next_state = state;
    next_stop_idx = stop_idx;
    next_start_idx = start_idx;
    next_pre_acc = pre_acc;
    next_post_acc = post_acc;
    next_best = best;

    case (state)
      IDLE: begin
        next_stop_idx = 4'b0;
        next_start_idx = 4'b0;
        next_pre_acc = 64'sh0;
        next_post_acc = 64'sh0;
        next_best = 32'sh0;
        if (start) begin
          // Start new computation
          next_state = CALC;
        end
      end

      CALC: begin
        // Load new candidate into pipeline
        next_stop_idx = stop_idx;
        next_start_idx = start_idx;

        // Update partial sums for the next (stop, start) pair
        // pre_acc accumulates sum of cards[0..stop-1]
        next_pre_acc = pre_acc + ((stop_idx < card_count) ? $signed({32'h0, card0, card1, card2, card3, card4, card5, card6, card7}[stop_idx * 32 +: 32]) : 64'sh0);

        // post_acc accumulates sum of cards[start..count-1]
        next_post_acc = post_acc + ((start_idx < card_count) ? $signed({32'h0, card0, card1, card2, card3, card4, card5, card6, card7}[start_idx * 32 +: 32]) : 64'sh0);

        // Compare with best using the pipelined candidate
        if (denom != 8'b0) begin
          if ($signed(cur_avg) > $signed(best)) begin
            next_best = cur_avg;
          end else begin
            next_best = best;
          end
        end else begin
          next_best = best;
        end

        // Iterate start first (inner loop)
        if (start_idx < count_r) begin
          next_start_idx = start_idx + 1;
          next_state = CALC;
        end else begin
          // Finish this stop, advance stop
          if (stop_idx < count_r) begin
            next_stop_idx = stop_idx + 1;
            next_start_idx = 4'b0;
            // reset post accumulator for the new stop index
            next_post_acc = 64'sh0;
            next_state = CALC;
          end else begin
            // All pairs processed
            next_state = DONE;
          end
        end
      end

      DONE: begin
        // Hold the result for 1 cycle, then return to IDLE
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
