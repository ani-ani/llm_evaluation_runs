module alternating_chain(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [2:0] n,
  input reg [15:0] c,
  input reg [15:0] r,
  input reg signed [7:0] scores [0:7],
  output reg [31:0] min_time,
  output reg done
);

  // Internal storage for inputs latched on start
  reg [2:0] n_reg;
  reg [15:0] c_reg, r_reg;
  reg signed [7:0] scores_reg [0:7];

  // DP state: no kept comment, last kept positive, last kept negative
  reg [31:0] dp_none, dp_pos, dp_neg;
  reg [2:0] i; // index of current comment

  // Constants
  localparam INF = 32'hFFFFFFFF;

  // Edge detection for start pulse
  reg start_d;

  // State machine
  localparam IDLE = 2'b00;
  localparam PROC = 2'b01;
  localparam DONE = 2'b10;
  reg [1:0] state;

  // Combinational logic to compute next DP values for the current comment
  logic [31:0] next_dp_none, next_dp_pos, next_dp_neg;

  always_comb begin
    // Default keep current values (no change)
    next_dp_none = dp_none;
    next_dp_pos  = dp_pos;
    next_dp_neg  = dp_neg;

    if (i < n_reg) begin
      // Removal of the current comment adds cost r to each existing state
      next_dp_none = (dp_none == INF) ? INF : dp_none + r_reg;
      next_dp_pos  = (dp_pos  == INF) ? INF : dp_pos  + r_reg;
      next_dp_neg  = (dp_neg  == INF) ? INF : dp_neg  + r_reg;

      // Determine if we can keep the comment with each sign and the vote cost
      logic keep_pos, keep_neg;
      logic [31:0] cost_keep_pos, cost_keep_neg;
      if (scores_reg[i] == 0) begin
        // Zero can be turned into either sign by voting (cost c)
        keep_pos = 1'b1;
        keep_neg = 1'b1;
        cost_keep_pos = c_reg;
        cost_keep_neg = c_reg;
      end else begin
        // Non‑zero, sign is fixed
        if (scores_reg[i][7] == 1'b0) begin // positive
          keep_pos = 1'b1;
          keep_neg = 1'b0;
          cost_keep_pos = 0;
          cost_keep_neg = 0; // unused
        end else begin // negative
          keep_pos = 1'b0;
          keep_neg = 1'b1;
          cost_keep_pos = 0; // unused
          cost_keep_neg = 0;
        end
      end

      // Starting a new chain from the "none" state
      if (keep_pos) begin
        logic [31:0] cand = (dp_none == INF) ? INF : dp_none + cost_keep_pos;
        next_dp_pos = (cand < next_dp_pos) ? cand : next_dp_pos;
      end
      if (keep_neg) begin
        logic [31:0] cand = (dp_none == INF) ? INF : dp_none + cost_keep_neg;
        next_dp_neg = (cand < next_dp_neg) ? cand : next_dp_neg;
      end

      // Extending an existing chain: transition from the opposite sign
      if (keep_pos && dp_neg != INF) begin
        logic [31:0] cand = dp_neg + cost_keep_pos;
        next_dp_pos = (cand < next_dp_pos) ? cand : next_dp_pos;
      end
      if (keep_neg && dp_pos != INF) begin
        logic [31:0] cand = dp_pos + cost_keep_neg;
        next_dp_neg = (cand < next_dp_neg) ? cand : next_dp_neg;
      end
    end
  end

  // Sequential state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      state <= IDLE;
      done <= 1'b0;
      min_time <= 32'h0;
      i <= 3'h0;
      dp_none <= 32'h0;
      dp_pos  <= INF;
      dp_neg  <= INF;
      n_reg <= 3'h0;
      c_reg <= 16'h0;
      r_reg <= 16'h0;
      for (int k = 0; k < 8; ++k) scores_reg[k] <= 8'h0;
      start_d <= 1'b0;
    end else begin
      start_d <= start; // edge detection

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start && !start_d) begin
            // Latch inputs
            n_reg <= n;
            c_reg <= c;
            r_reg <= r;
            for (int k = 0; k < 8; ++k) scores_reg[k] <= scores[k];
            // Initialise DP
            i <= 3'h0;
            dp_none <= 32'h0;
            dp_pos  <= INF;
            dp_neg  <= INF;
            state <= PROC;
          end
        end

        PROC: begin
          // Update DP using combinational logic (non‑blocking assignment)
          dp_none <= next_dp_none;
          dp_pos  <= next_dp_pos;
          dp_neg  <= next_dp_neg;

          // Increment comment index
          if (i < n_reg) i <= i + 1;

          // If all comments processed, go to DONE
          if (i == n_reg) state <= DONE;
        end

        DONE: begin
          // Compute minimal time from the three DP states
          min_time <= min3(dp_none, dp_pos, dp_neg);
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

  // Helper: minimum of three 32‑bit values
  function [31:0] min3;
    input [31:0] a, b, c;
    logic [31:0] m;
  begin
    m = a < b ? a : b;
    min3 = m < c ? m : c;
  end
  endfunction

endmodule
