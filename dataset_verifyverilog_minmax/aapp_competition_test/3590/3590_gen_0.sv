module polygon_cutter(
  input clk,
  input rst_n,
  input start,
  input [2:0] a_count,
  input [2:0] b_count,
  input [7:0][15:0] a_x,
  input [7:0][15:0] a_y,
  input [7:0][15:0] b_x,
  input [7:0][15:0] b_y,
  output reg [31:0] total_cost,
  output reg done
);

  // Internal signals and state machine
  typedef enum logic [2:0] {IDLE, FIND_TANGENTS, CALC_DISTANCES, SQRT, ACCUMULATE, FINISH} state_t;
  state_t state, next_state;

  // Latched inputs
  reg [2:0] sa_count, sb_count;
  logic [15:0] la_x [0:7];
  logic [15:0] la_y [0:7];
  logic [15:0] lb_x [0:7];
  logic [15:0] lb_y [0:7];

  // Tangent search (B -> A)
  reg [2:0] s_bi;
  reg [2:0] s_tcnt; // 0..sb_count
  logic [2:0] s_tidx [0:7]; // indices on A of tangent points in CCW order

  // Distance/accumulation path
  reg [2:0] e_count; // number of edges between tangent points (>=1)
  reg [3:0] s_ei;    // current edge pipeline index (0..e_count-1)
  logic [3:0] next_ei;
  logic last_iter;   // last iteration of 4-cycle sqrt pipeline

  // Per-edge registers
  reg signed [16:0] dx; // Q8.8 +/- 256 max range
  reg signed [16:0] dy;
  reg [31:0] x2y2;      // Q16.16 squared length
  reg [31:0] sqrt_in;   // Q16.16 input to sqrt

  // Newton-Raphson sqrt pipeline (4 iterations, 1 per cycle)
  reg [31:0] g0, g1, g2, g3; // iterative approximations

  // Accumulator and done pulse
  reg [31:0] cost_acc;
  reg done_next;

  // State registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      total_cost <= 32'h0;
      done <= 1'b0;
      cost_acc <= 32'h0;
    end else begin
      state <= next_state;
      total_cost <= cost_acc;
      done <= done_next;
    end
  end

  // Latch inputs on start
  always_ff @(posedge clk) begin
    if (next_state == FIND_TANGENTS) begin
      sa_count <= a_count;
      sb_count <= b_count;
      for (int i=0; i<8; i++) begin
        la_x[i] <= a_x[i];
        la_y[i] <= a_y[i];
        lb_x[i] <= b_x[i];
        lb_y[i] <= b_y[i];
      end
      // Defaults in case of early exit
      s_tcnt <= '0;
      s_bi <= '0;
    end
  end

  // Tangent search and pipeline progression
  always_ff @(posedge clk) begin
    case (next_state)
      FIND_TANGENTS: begin
        // Compute tangent from B[ s_bi ] to convex polygon A
        // Leftmost tangent j: s.t. B is to the right of edge (A[j-1], A[j]) and to the left of (A[j], A[j+1])
        logic [2:0] j, jm1, jp1;
        logic left_a_jp1_b, left_b_aj, left_b_ajm1;
        j = 3'(s_tcnt); // target index in A to examine
        jm1 = (j == 3'd0) ? (sa_count - 1) : (j - 1);
        jp1 = (j + 1 >= sa_count) ? 3'd0 : (j + 1);
        left_a_jp1_b = is_left(la_x[jp1], la_y[jp1], lb_x[s_bi], lb_y[s_bi], la_x[j], la_y[j]);
        left_b_aj     = is_left(lb_x[s_bi], lb_y[s_bi], la_x[j], la_y[j], la_x[jm1], la_y[jm1]);
        left_b_ajm1   = is_left(lb_x[s_bi], lb_y[s_bi], la_x[jm1], la_y[jm1], la_x[j], la_y[j]);
        // If B is right of (A[j-1]->A[j]) and left of (A[j]->A[j+1]), j is a left tangent
        if (!left_b_aj && left_a_jp1_b) begin
          s_tidx[s_tcnt] <= j;
          s_tcnt <= s_tcnt + 1;
        end
        s_bi <= s_bi + 1;
      end

      CALC_DISTANCES: begin
        // One edge per cycle: between consecutive tangent points s_tidx[s_ei] -> s_tidx[s_ei+1]
        logic [2:0] i0, i1;
        i0 = s_tidx[s_ei];
        i1 = (s_ei + 1 >= s_tcnt) ? s_tidx[0] : s_tidx[s_ei + 1];
        dx <= $signed({1'b0, la_x[i1]}) - $signed({1'b0, la_x[i0]});
        dy <= $signed({1'b0, la_y[i1]}) - $signed({1'b0, la_y[i0]});
        // Iterate to next edge
        s_ei <= next_ei;
        last_iter <= (next_ei == 4'd0); // when s_ei wraps, last iteration starts this cycle
      end

      SQRT: begin
        // Pipeline 4 Newton iterations per edge; g3 is current sqrt approximation
        g0 <= g1;
        g1 <= g2;
        g2 <= g3;
        g3 <= newton_iter(sqrt_in, g2);
        // Hold dx, dy, x2y2 constant for the 4-cycle sqrt window per edge
        // (already stable from CALC_DISTANCES stage)
      end

      ACCUMULATE: begin
        cost_acc <= cost_acc + g3; // accumulate per-edge sqrt results (Q16.16)
      end

      FINISH: begin
        // total_cost already set from cost_acc; done is pulsed outside
      end

      default: begin
        // IDLE: nothing
      end
    endcase
  end

  // Compute new edge index and detect end of edge list
  always_comb begin
    if (state == CALC_DISTANCES) begin
      logic [3:0] ei_next;
      if (e_count == 4'd0) begin
        ei_next = 4'd0;
      end else begin
        ei_next = s_ei + 1;
        if (ei_next >= e_count) ei_next = 4'd0;
      end
      next_ei = ei_next;
    end else begin
      next_ei = s_ei; // unused in other states
    end
  end

  // Newton-Raphson square root iteration for 32-bit Q16.16
  function [31:0] newton_iter;
    input [31:0] x;     // Q16.16 radicand (>=0)
    input [31:0] guess; // current guess
    reg [31:0] prod;
    begin
      // Avoid division by zero
      if (guess == 0) begin
        newton_iter = 0;
      end else begin
        prod = (guess * guess) >> 16; // Q16.16 * Q16.16 -> Q32.32, keep Q16.16 part
        // x/guess (Q16.16 / Q16.16) -> Q16.16, approx: (x << 16) / guess
        newton_iter = (guess + ((x << 16) / guess)) >> 1;
      end
    end
  endfunction

  // Orientation test: >0 if P->Q is left of P->R (CCW), <=0 otherwise
  function is_left;
    input [15:0] px, py, qx, qy, rx, ry;
    logic [32:0] cross;
    begin
      cross = $signed({1'b0, qx, 8'h00}) * $signed({1'b0, ry, 8'h00}) -
              $signed({1'b0, qx, 8'h00}) * $signed({1'b0, py, 8'h00}) +
              $signed({1'b0, rx, 8'h00}) * $signed({1'b0, py, 8'h00}) -
              $signed({1'b0, rx, 8'h00}) * $signed({1'b0, qy, 8'h00}) +
              $signed({1'b0, px, 8'h00}) * $signed({1'b0, qy, 8'h00}) -
              $signed({1'b0, px, 8'h00}) * $signed({1'b0, ry, 8'h00});
      is_left = (cross > 0);
    end
  endfunction

  // State machine combinational logic
  always_comb begin
    // Defaults
    next_state = state;
    done_next = 1'b0;
    // Edge count is (t2 - t1 + n) mod n for t1->t2 forward walk on A
    // Initialize to 0 in other states
    e_count = '0;
    s_ei = '0;
    sqrt_in = '0;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = FIND_TANGENTS;
        end
      end

      FIND_TANGENTS: begin
        // One vertex of B per cycle
        if (s_bi >= (sb_count - 1)) begin
          // After last B vertex has been processed, proceed
          // Determine number of supporting edges: count of left tangents in order
          // Edges in A = sum over k of (t_{k+1} - t_k + n) mod n for consecutive tangents
          e_count = '0;
          for (int k=0; k<8; k++) begin
            if (k < s_tcnt) begin
              logic [2:0] t0, t1;
              t0 = s_tidx[k];
              if ((k+1) < s_tcnt) t1 = s_tidx[k+1];
              else t1 = s_tidx[0];
              if (t1 >= t0) e_count = e_count + (t1 - t0);
              else e_count = e_count + (sa_count - (t0 - t1));
            end
          end
          next_state = CALC_DISTANCES;
        end
      end

      CALC_DISTANCES: begin
        // Prepare current edge for sqrt pipeline
        dx = $signed({1'b0, la_x[s_tidx[s_ei]]) - $signed({1'b0, la_x[s_tidx[(s_ei+1 >= s_tcnt) ? 3'd0 : (s_ei+1)]]});
        dy = $signed({1'b0, la_y[s_tidx[s_ei]]) - $signed({1'b0, la_y[s_tidx[(s_ei+1 >= s_tcnt) ? 3'd0 : (s_ei+1)]]});
        x2y2 = ($unsigned(dx) * $unsigned(dx)) + ($unsigned(dy) * $unsigned(dy)); // Q16.16
        sqrt_in = x2y2;

        // Initialize Newton iteration seed for this edge
        g0 = 32'h010000; // initial guess 1.0 in Q16.16
        g1 = 32'h0; // not used on the first cycle of this edge
        g2 = 32'h0;
        g3 = newton_iter(sqrt_in, g0);

        // Walk through edges one per cycle
        if (e_count == 0) begin
          next_state = SQRT; // degenerate (no edges), skip to clean up
        end else begin
          // Move to SQRT after all edges are queued into the 4-stage pipeline.
          // The last edge is fully out of the pipeline when (s_ei == e_count-4)
          // Because we advance s_ei each CALC_DISTANCES cycle, transition when true.
          if (e_count >= 4) begin
            if (s_ei == (e_count - 4)) next_state = SQRT;
          end else begin
            if (s_ei == 0) next_state = SQRT;
          end
        end
      end

      SQRT: begin
        // Continue Newton iterations
        g0 <= g1;
        g1 <= g2;
        g2 <= g3;
        g3 <= newton_iter(sqrt_in, g2);
        // After 4 iterations from the last edge, go to ACCUMULATE
        if (last_iter) next_state = ACCUMULATE;
      end

      ACCUMULATE: begin
        // Accumulate last edge's sqrt result; if more edges remain, continue on SQRT
        // Note: at entry, g3 holds the last edge's sqrt result from SQRT stage
        cost_acc <= cost_acc + g3;
        if (e_count == 1) begin
          next_state = FINISH;
        end else begin
          // We have consumed one edge from the queue; adjust e_count and s_ei to proceed with next.
          // To keep control simple, we simply re-enter SQRT to advance the pipeline for the next edge.
          // However, because sqrt_in/dx/dy are not updated here, we must instead process the next edge now.
          // A simpler approach: on ACCUMULATE, we reenter CALC_DISTANCES for next edge until e_count=0.
          next_state = CALC_DISTANCES;
          // Decrement edges left by one; s_ei will be advanced in CALC_DISTANCES.
          e_count <= e_count - 1;
        end
      end

      FINISH: begin
        done_next = 1'b1;
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
