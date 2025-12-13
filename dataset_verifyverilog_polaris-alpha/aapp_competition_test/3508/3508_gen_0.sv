module pillar_collapse(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [3:0] n, // Number of pillars (1-8)
  input [15:0] b [0:7], // Pillar strengths (8 elements, 16-bit each)
  output reg [3:0] max_damage, // Max destruction count
  output reg [3:0] pillar_idx, // Optimal pillar index (0-7)
  output reg done // High when computation complete
);

  // Assumptions for pressure model:
  // - Uniform load along horizontal axis.
  // - Each pillar at position i supports load proportional to half distance
  //   to its neighbors (adjacent surviving pillars) or structure edges.
  // - When a pillar is removed (or collapses), neighbors / nearest survivors
  //   take over the span; if any pillar's pressure exceeds its strength,
  //   it collapses, and redistribution is recomputed until stable.
  // - Distances between adjacent pillars and between edge and first/last
  //   pillars are 1 unit. Pressure per unit area = 1000 kN.
  // Therefore, for surviving pillar i with nearest surviving neighbors L,R:
  //   left_span  = (i - L) / 2 if L exists else i
  //   right_span = (R - i) / 2 if R exists else (last_idx - i)
  //   total_span = left_span + right_span
  //   pressure   = total_span * 1000
  // Compare pressure to b[i]; if pressure > strength, pillar collapses.

  // FSM states
  localparam S_IDLE   = 2'd0;
  localparam S_INIT   = 2'd1;
  localparam S_SIM    = 2'd2;
  localparam S_DONE   = 2'd3;

  reg [1:0] state, next_state;

  // Iteration variables
  reg [3:0] cur_pillar;       // candidate pillar index being tested
  reg [3:0] best_idx;         // best pillar index so far
  reg [3:0] best_damage;      // max destruction so far

  // Simulation data
  reg alive [0:7];            // current alive map for simulation
  reg [3:0] alive_count;      // number of alive pillars

  reg [3:0] sim_step;         // iteration count within stabilization
  reg       changed;          // flag: any collapse in last iteration
  reg [3:0] collapse_count;   // number of collapsed pillars for candidate

  // temp arrays for next state in iteration
  reg next_alive [0:7];
  reg [3:0] i_idx;

  // Combinational: compute next_state
  always @(*) begin
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
        else
          next_state = S_IDLE;
      end
      S_INIT: begin
        // directly go to simulation for current pillar
        next_state = S_SIM;
      end
      S_SIM: begin
        // In S_SIM we iterate until stabilization; state change decided
        // sequentially using flags; here keep S_SIM by default
        next_state = S_SIM;
        if (sim_step != 0 && !changed) begin
          // stabilization reached, move either to next pillar or done
          if (cur_pillar + 1 < n)
            next_state = S_INIT;
          else
            next_state = S_DONE;
        end
      end
      S_DONE: begin
        // Wait for next start (level-sensitive)
        if (start)
          next_state = S_INIT;
        else
          next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  integer j;
  integer k;
  integer L;
  integer R;
  integer last_idx;
  integer span_left;
  integer span_right;
  integer span_total;
  integer pressure;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      max_damage   <= 4'd0;
      pillar_idx   <= 4'd0;
      done         <= 1'b0;
      cur_pillar   <= 4'd0;
      best_idx     <= 4'd0;
      best_damage  <= 4'd0;
      sim_step     <= 4'd0;
      collapse_count <= 4'd0;
      alive_count  <= 4'd0;
      for (j = 0; j < 8; j = j + 1) begin
        alive[j]     <= 1'b0;
        next_alive[j]<= 1'b0;
      end
      changed      <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done        <= 1'b0;
          max_damage  <= max_damage; // hold
          pillar_idx  <= pillar_idx; // hold
          if (start) begin
            // Initialize search
            best_damage <= 4'd0;
            best_idx    <= 4'd0;
            cur_pillar  <= 4'd0;
          end
        end

        S_INIT: begin
          // Configure initial alive set for candidate cur_pillar
          last_idx = (n == 0) ? 0 : (n - 1);
          for (j = 0; j < 8; j = j + 1) begin
            if (j < n && j != cur_pillar)
              alive[j] <= 1'b1;
            else
              alive[j] <= 1'b0;
          end
          // initial collapse_count: removed pillar counts as one destruction
          collapse_count <= (cur_pillar < n) ? 4'd1 : 4'd0;

          // Count alive after initial removal
          alive_count = 0;
          for (j = 0; j < 8; j = j + 1) begin
            if (j < n && j != cur_pillar)
              alive_count = alive_count + 1;
          end

          sim_step <= 4'd0;
          changed  <= 1'b1; // force at least one sim round
        end

        S_SIM: begin
          // Run iterative redistribution until no more changes
          if (sim_step == 0) begin
            sim_step <= sim_step + 1'b1;
            changed  <= 1'b1; // start first iteration
          end else if (changed) begin
            // compute one iteration based on current alive[]
            last_idx = (n == 0) ? 0 : (n - 1);
            changed  <= 1'b0;

            // default: copy alive to next_alive
            for (j = 0; j < 8; j = j + 1) begin
              next_alive[j] = alive[j];
            end

            // For each alive pillar, compute pressure and decide collapse
            for (j = 0; j < 8; j = j + 1) begin
              if (alive[j]) begin
                // find nearest alive to the left
                L = -1;
                for (k = j - 1; k >= 0; k = k - 1) begin
                  if (alive[k]) begin
                    L = k;
                    k = -1; // break
                  end
                end
                // find nearest alive to the right
                R = -1;
                for (k = j + 1; k < n; k = k + 1) begin
                  if (alive[k]) begin
                    R = k;
                    k = n; // break
                  end
                end

                // compute spans
                if (L >= 0)
                  span_left = (j - L) >> 1;
                else
                  span_left = j; // from edge (index 0) to j

                if (R >= 0)
                  span_right = (R - j) >> 1;
                else
                  span_right = (last_idx - j); // from j to right edge

                span_total = span_left + span_right;
                pressure   = span_total * 1000;

                if (pressure > b[j]) begin
                  if (next_alive[j]) begin
                    next_alive[j] = 1'b0;
                    changed       = 1'b1;
                    collapse_count <= collapse_count + 1'b1;
                  end
                end
              end
            end

            // Commit next_alive to alive
            for (j = 0; j < 8; j = j + 1) begin
              alive[j] <= next_alive[j];
            end

            sim_step <= sim_step + 1'b1;
          end else begin
            // No changes in last iteration: finalize this candidate
            // Ensure we don't re-enter here due to state pipelining
            if (cur_pillar < n) begin
              // Update best if needed
              if (collapse_count > best_damage) begin
                best_damage <= collapse_count;
                best_idx    <= cur_pillar;
              end
            end

            // Move to next candidate or to DONE will be handled by next_state
            if (cur_pillar + 1 < n) begin
              cur_pillar <= cur_pillar + 1'b1;
            end
          end
        end

        S_DONE: begin
          // Latch results
          max_damage <= best_damage;
          pillar_idx <= best_idx;
          done       <= 1'b1;
          // If a new start is issued, re-init via next_state=S_INIT
          if (start) begin
            done        <= 1'b0;
            best_damage <= 4'd0;
            best_idx    <= 4'd0;
            cur_pillar  <= 4'd0;
            sim_step    <= 4'd0;
          end
        end

        default: ;
      endcase
    end
  end

endmodule