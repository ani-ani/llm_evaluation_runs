module arcade_expected_value (
  input clk,
  input rst_n,
  input start,
  input [3:0] num_rows,
  input [7:0] payouts [0:9],
  input [19:0] probs [0:9][0:4],
  output reg signed [31:0] expected_value,
  output reg done
);
  // States
  typedef enum logic [1:0] {IDLE=2'b00, INIT=2'b01, ITERATE=2'b10, DONE=2'd3} state_t;
  state_t state;

  // Constants
  // Probabilities are Q10.10; we use 20-bit signed for easier rounding and alignment.
  localparam QPROB_WIDTH = 20; // signed
  localparam PROB_Q = 10;      // fractional bits for probability (Q10.10)
  localparam EV_Q = 22;        // fractional bits for expected value (Q10.22)
  localparam MAX_ITER = 7'd100; // 1..100 iterations
  localparam THRESHOLD = 20'd1; // 1/1024 in Q10.10 is 1 in integer domain of Q10.10

  // Internal storage
  reg [6:0] iter_cnt;
  reg signed [31:0] E [0:9];       // Expected value per hole, Q10.22
  reg signed [31:0] E_next [0:9];  // Next iterate
  reg signed [19:0] prob_s [0:9][0:4]; // Signed probabilities Q10.10 sign-extended to 20 bits
  reg signed [29:0] sum_prod [0:9];    // Accumulator for sum(prob*E[neighbor]), Q10.10
  reg signed [19:0] delta_q10_10; // Max abs change over all holes in Q10.10
  integer r, d, h;

  // Neighbor index calculation for a 10-column, up-to-4-row board
  // Directions per hole (0..4): 0=self, 1=right, 2=left, 3=down, 4=up
  function [3:0] next_index;
    input [3:0] row;     // 0-based row index
    input [3:0] col;     // 0-based column index (0..9)
    input [2:0] dir;     // 0..4
    begin
      case (dir)
        3'd0: next_index = {row, col};                       // self
        3'd1: next_index = (col < 4'd9) ? {row, col+1} : {row, col}; // right
        3'd2: next_index = (col > 4'd0) ? {row, col-1} : {row, col}; // left
        3'd3: next_index = (row < 3'd3) ? {row+1, col} : {row, col}; // down
        3'd4: next_index = (row > 3'd0) ? {row-1, col} : {row, col}; // up
        default: next_index = {row, col};
      endcase
    end
  endfunction

  // sign-extend probabilities to 20-bit signed for cleaner rounding in Q10.10
  always @(*) begin
    for (h = 0; h < 10; h = h + 1) begin
      for (d = 0; d < 5; d = d + 1) begin
        prob_s[h][d] = $signed({1'b0, probs[h][d]});
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      expected_value <= 0;
      done <= 1'b0;
      iter_cnt <= 7'd0;
      delta_q10_10 <= 20'd0;
      for (h = 0; h < 10; h = h + 1) begin
        E[h] <= 0;
        E_next[h] <= 0;
        sum_prod[h] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= INIT;
            iter_cnt <= 7'd0;
            delta_q10_10 <= 20'd0;
            // Initialize E[h] = payout[h] in Q10.22
            for (h = 0; h < 10; h = h + 1) begin
              E[h] <= $signed({payouts[h], {EV_Q{1'b0}}}); // sign-extend 8-bit payout to 32 bits, then append 22 zeros
            end
          end
        end

        INIT: begin
          state <= ITERATE;
        end

        ITERATE: begin
          // Compute sum of probs * E[neighbor] for each hole
          for (h = 0; h < 10; h = h + 1) begin
            sum_prod[h] <= 0;
            // Directions: 0=self, 1=right, 2=left, 3=down, 4=up
            for (d = 0; d < 5; d = d + 1) begin
              automatic logic [3:0] nb; // SystemVerilog-2012 auto
              nb = next_index(h[3:0], h[3:0], d);
              // prob_s: Q10.10 (20-bit signed)
              // E[nb]: Q10.22 (32-bit signed)
              // Product: Q20.32 -> we need Q10.10 after rounding -> drop 22 bits and round
              // Acc: Q10.10
              // Synthesis may complain about implicit cast; explicit cast is safe.
              sum_prod[h] <= sum_prod[h] + $signed((prob_s[h][d] * E[nb]) >>> 22);
            end
          end

          // Update E and track max change (Q10.10)
          delta_q10_10 <= 0;
          for (h = 0; h < 10; h = h + 1) begin
            // E_next = payout + sum(prob*E[neighbor]) in Q10.22
            E_next[h] <= $signed({payouts[h], {EV_Q{1'b0}}}) + $signed({sum_prod[h], {EV_Q{1'b0}}});
          end
          for (h = 0; h < 10; h = h + 1) begin
            automatic reg signed [19:0] diff_abs_q10_10;
            // delta in Q10.10 = |E_next - E| >> 22
            diff_abs_q10_10 = (E_next[h] >= E[h]) ? ((E_next[h] - E[h]) >>> 22) : ((E[h] - E_next[h]) >>> 22);
            if (diff_abs_q10_10 > delta_q10_10) begin
              delta_q10_10 <= diff_abs_q10_10;
            end
          end

          // Commit next values
          for (h = 0; h < 10; h = h + 1) begin
            E[h] <= E_next[h];
          end

          iter_cnt <= iter_cnt + 1;

          // Stopping condition: 100 iterations or max change < 1/1024 (i.e., < 1 in Q10.10)
          if ((iter_cnt + 1) >= MAX_ITER || delta_q10_10 < THRESHOLD) begin
            state <= DONE;
          end
        end

        DONE: begin
          expected_value <= E[0];
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule