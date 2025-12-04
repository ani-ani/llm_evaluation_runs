module castle_danger_detector (
  input clk,
  input rst_n,
  input load,
  input [15:0] x_i,
  input [15:0] y_i,
  input is_castle_i,
  input start,
  output reg [1:0] danger_count,
  output reg done
);

  // Constants
  localparam MAX_TROOPS = 4;  // Need at least 4 troops to form a quadrilateral
  localparam MAX_CASTLES = 4;
  localparam COL_EPS = 32;    // Tolerance for collinearity (empirical for timing)

  // Storage for points
  reg [15:0] troop_x [0:MAX_TROOPS-1];
  reg [15:0] troop_y [0:MAX_TROOPS-1];
  reg [15:0] castle_x [0:MAX_CASTLES-1];
  reg [15:0] castle_y [0:MAX_CASTLES-1];

  // Counters
  reg [3:0] troop_cnt;   // up to 4 (but we allow 0..4, requires >=4 to check)
  reg [3:0] castle_cnt;  // 0..4
  reg [1:0] castle_idx;  // which castle we are checking
  reg [1:0] c0, c1, c2, c3; // indices of the 4 troops in current quad
  reg found_danger;

  // FSM state
  typedef enum logic [2:0] {IDLE, LOADING, CHECK_CASTLE, CHECK_QUAD, DONE} state_t;
  state_t state, next_state;

  // Pipelined geometry signals (CHECK_QUAD stage)
  // Stage 0: differences
  reg signed [16:0] a0_dx, a0_dy, a1_dx, a1_dy, a2_dx, a2_dy, a3_dx, a3_dy;
  reg signed [33:0] a0_cross, a1_cross, a2_cross, a3_cross;
  reg col_012, col_013, col_023, col_123;

  // Stage 1: segment coordinates and cross products for intersections
  reg signed [16:0] p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y;
  reg signed [16:0] q1x, q1y, q2x, q2y, q3x, q3y, q4x, q4y;
  reg signed [33:0] r1_cross, r2_cross, s1_cross, s2_cross;

  // Stage 2: intersection result
  reg seg01_23_int, seg02_13_int, seg03_12_int;

  // Stage 3: inside-polygon checks for current castle
  reg signed [33:0] b0_cross, b1_cross, b2_cross, b3_cross;
  reg poly_ok, quad_inside, any_danger;

  // State progression in CHECK_QUAD
  // s0: compute collinearity of triplets
  // s1: compute intersections (r1,r2,s1,s2)
  // s2: gather intersection results
  // s3: inside test for current castle
  // s4: evaluate and commit decision
  reg [2:0] subquad_state;
  reg s_valid, s_prev_valid;
  reg s_intersects, s_prev_intersects;
  reg s_inside, s_prev_inside;

  // FSM sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      danger_count <= 2'b0;
      done <= 1'b0;
      troop_cnt <= 4'b0;
      castle_cnt <= 4'b0;
      castle_idx <= 2'b0;
      found_danger <= 1'b0;
      // Reset geometry pipeline
      a0_dx <= 0; a0_dy <= 0; a1_dx <= 0; a1_dy <= 0; a2_dx <= 0; a2_dy <= 0; a3_dx <= 0; a3_dy <= 0;
      a0_cross <= 0; a1_cross <= 0; a2_cross <= 0; a3_cross <= 0;
      col_012 <= 1'b0; col_013 <= 1'b0; col_023 <= 1'b0; col_123 <= 1'b0;
      p1x <= 0; p1y <= 0; p2x <= 0; p2y <= 0; p3x <= 0; p3y <= 0; p4x <= 0; p4y <= 0;
      q1x <= 0; q1y <= 0; q2x <= 0; q2y <= 0; q3x <= 0; q3y <= 0; q4x <= 0; q4y <= 0;
      r1_cross <= 0; r2_cross <= 0; s1_cross <= 0; s2_cross <= 0;
      seg01_23_int <= 1'b0; seg02_13_int <= 1'b0; seg03_12_int <= 1'b0;
      b0_cross <= 0; b1_cross <= 0; b2_cross <= 0; b3_cross <= 0;
      poly_ok <= 1'b0; quad_inside <= 1'b0; any_danger <= 1'b0;
      subquad_state <= 3'd0;
      s_valid <= 1'b0; s_prev_valid <= 1'b0;
      s_intersects <= 1'b0; s_prev_intersects <= 1'b0;
      s_inside <= 1'b0; s_prev_inside <= 1'b0;
    end else begin
      // Default: advance FSM, overridden by state blocks below where necessary
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          danger_count <= 2'b0;
          troop_cnt <= 4'b0;
          castle_cnt <= 4'b0;
          castle_idx <= 2'b0;
          found_danger <= 1'b0;
          // reset pipeline
          a0_dx <= 0; a0_dy <= 0; a1_dx <= 0; a1_dy <= 0; a2_dx <= 0; a2_dy <= 0; a3_dx <= 0; a3_dy <= 0;
          a0_cross <= 0; a1_cross <= 0; a2_cross <= 0; a3_cross <= 0;
          col_012 <= 1'b0; col_013 <= 1'b0; col_023 <= 1'b0; col_123 <= 1'b0;
          p1x <= 0; p1y <= 0; p2x <= 0; p2y <= 0; p3x <= 0; p3y <= 0; p4x <= 0; p4y <= 0;
          q1x <= 0; q1y <= 0; q2x <= 0; q2y <= 0; q3x <= 0; q3y <= 0; q4x <= 0; q4y <= 0;
          r1_cross <= 0; r2_cross <= 0; s1_cross <= 0; s2_cross <= 0;
          seg01_23_int <= 1'b0; seg02_13_int <= 1'b0; seg03_12_int <= 1'b0;
          b0_cross <= 0; b1_cross <= 0; b2_cross <= 0; b3_cross <= 0;
          poly_ok <= 1'b0; quad_inside <= 1'b0; any_danger <= 1'b0;
          subquad_state <= 3'd0;
          s_valid <= 1'b0; s_prev_valid <= 1'b0;
          s_intersects <= 1'b0; s_prev_intersects <= 1'b0;
          s_inside <= 1'b0; s_prev_inside <= 1'b0;
          if (load) begin
            // first load arrives
            troop_cnt <= (is_castle_i ? 1'b0 : 1'b1);
            castle_cnt <= (is_castle_i ? 1'b1 : 1'b0);
            if (!is_castle_i) begin
              troop_x[0] <= x_i;
              troop_y[0] <= y_i;
            end else begin
              castle_x[0] <= x_i;
              castle_y[0] <= y_i;
            end
            next_state <= LOADING;
          end else begin
            next_state <= IDLE;
          end
        end

        LOADING: begin
          done <= 1'b0;
          if (load) begin
            if (!is_castle_i && troop_cnt < MAX_TROOPS) begin
              troop_x[troop_cnt] <= x_i;
              troop_y[troop_cnt] <= y_i;
              troop_cnt <= troop_cnt + 1;
            end else if (is_castle_i && castle_cnt < MAX_CASTLES) begin
              castle_x[castle_cnt] <= x_i;
              castle_y[castle_cnt] <= y_i;
              castle_cnt <= castle_cnt + 1;
            end
            next_state <= LOADING;
          end else if (start) begin
            // Start computation
            if (troop_cnt < MAX_TROOPS || castle_cnt == 0) begin
              danger_count <= 2'b0;
              done <= 1'b1;
              next_state <= DONE;
            end else begin
              castle_idx <= 2'b0;
              found_danger <= 1'b0;
              next_state <= CHECK_CASTLE;
              // initialize quad indices
              c0 <= 2'd0; c1 <= 2'd1; c2 <= 2'd2; c3 <= 2'd3;
              subquad_state <= 3'd0;
              // reset pipeline control signals
              s_valid <= 1'b0; s_prev_valid <= 1'b0;
              s_intersects <= 1'b0; s_prev_intersects <= 1'b0;
              s_inside <= 1'b0; s_prev_inside <= 1'b0;
            end
          end else begin
            next_state <= LOADING;
          end
        end

        CHECK_CASTLE: begin
          // Check if current castle is already in danger
          if (found_danger) begin
            // Mark done for this castle, move to next
            if (castle_idx < (castle_cnt - 1)) begin
              castle_idx <= castle_idx + 1;
              found_danger <= 1'b0;
              // reset quad indices to start
              c0 <= 2'd0; c1 <= 2'd1; c2 <= 2'd2; c3 <= 2'd3;
              subquad_state <= 3'd0;
              s_valid <= 1'b0; s_prev_valid <= 1'b0;
              s_intersects <= 1'b0; s_prev_intersects <= 1'b0;
              s_inside <= 1'b0; s_prev_inside <= 1'b0;
              next_state <= CHECK_CASTLE;
            end else begin
              next_state <= DONE;
            end
          end else begin
            // Start checking quadrilaterals of troops
            next_state <= CHECK_QUAD;
            // Substate machine cycles while !found_danger
            subquad_state <= 3'd0;
            s_valid <= 1'b0; s_prev_valid <= 1'b0;
            s_intersects <= 1'b0; s_prev_intersects <= 1'b0;
            s_inside <= 1'b0; s_prev_inside <= 1'b0;
          end
        end

        CHECK_QUAD: begin
          // Advance sub-quad state machine
          s_prev_valid <= s_valid;
          s_prev_intersects <= s_intersects;
          s_prev_inside <= s_inside;

          if (subquad_state == 3'd0) begin
            // Stage 0: non-degeneracy via collinearity of triplets (A,B,C) etc.
            // Use points A=c0, B=c1, C=c2, D=c3
            a0_dx <= $signed(troop_x[c1]) - $signed(troop_x[c0]);
            a0_dy <= $signed(troop_y[c1]) - $signed(troop_y[c0]);
            a1_dx <= $signed(troop_x[c2]) - $signed(troop_x[c1]);
            a1_dy <= $signed(troop_y[c2]) - $signed(troop_y[c1]);
            a2_dx <= $signed(troop_x[c3]) - $signed(troop_x[c0]);
            a2_dy <= $signed(troop_y[c3]) - $signed(troop_y[c0]);
            a3_dx <= $signed(troop_x[c3]) - $signed(troop_x[c2]);
            a3_dy <= $signed(troop_y[c3]) - $signed(troop_y[c2]);
            subquad_state <= 3'd1;
            next_state <= CHECK_QUAD;
          end else if (subquad_state == 3'd1) begin
            // Compute 3-point cross products for collinearity
            // col012: (B-A) x (C-A)
            a0_cross <= a0_dx * a2_dy - a0_dy * a2_dx;
            // col013: (B-A) x (D-A)
            a1_cross <= a0_dx * a3_dy - a0_dy * a3_dx;
            // col023: (C-A) x (D-A)
            a2_cross <= a2_dx * a3_dy - a2_dy * a3_dx;
            // col123: (C-B) x (D-B)
            a3_cross <= a1_dx * (a3_dy - a1_dy) - a1_dy * (a3_dx - a1_dx); // (C-B) x (D-B)
            subquad_state <= 3'd2;
            next_state <= CHECK_QUAD;
          end else if (subquad_state == 3'd2) begin
            // Evaluate collinearity with tolerance
            col_012 <= (a0_cross >= -$signed(COL_EPS) && a0_cross <= $signed(COL_EPS));
            col_013 <= (a1_cross >= -$signed(COL_EPS) && a1_cross <= $signed(COL_EPS));
            col_023 <= (a2_cross >= -$signed(COL_EPS) && a2_cross <= $signed(COL_EPS));
            col_123 <= (a3_cross >= -$signed(COL_EPS) && a3_cross <= $signed(COL_EPS));
            // Prepare stage 1 for segment intersection: points of segments
            p1x <= $signed(troop_x[c0]); p1y <= $signed(troop_y[c0]);
            p2x <= $signed(troop_x[c1]); p2y <= $signed(troop_y[c1]);
            p3x <= $signed(troop_x[c2]); p3y <= $signed(troop_y[c2]);
            p4x <= $signed(troop_x[c3]); p4y <= $signed(troop_y[c3]);
            q1x <= p1x; q1y <= p1y; q2x <= p2x; q2y <= p2y;
            q3x <= p3x; q3y <= p3y; q4x <= p4x; q4y <= p4y;
            subquad_state <= 3'd3;
            next_state <= CHECK_QUAD;
          end else if (subquad_state == 3'd3) begin
            // Compute r = (q3 - p1) x (p2 - p1) and s = (q3 - p1) x (q2 - q1)
            r1_cross <= (q3x - p1x) * (p2y - p1y) - (q3y - p1y) * (p2x - p1x);
            r2_cross <= (q3x - p1x) * (p4y - p3y) - (q3y - p1y) * (p4x - p3x);
            s1_cross <= (q1x - p1x) * (p2y - p1y) - (q1y - p1y) * (p2x - p1x);
            s2_cross <= (q1x - p1x) * (p4y - p3y) - (q1y - p1y) * (p4x - p3x);
            subquad_state <= 3'd4;
            next_state <= CHECK_QUAD;
          end else if (subquad_state == 3'd4) begin
            // Evaluate intersection conditions (segments p1-p2 vs p3-p4)
            // Proper intersection: r1 and r2 have opposite signs, s1 and s2 have opposite signs
            // Collinear cases are also treated as intersecting to ensure non-self-intersecting quads
            seg01_23_int <= ((r1_cross > 0 && r2_cross < 0) || (r1_cross < 0 && r2_cross > 0) ||
                             (s1_cross > 0 && s2_cross < 0) || (s1_cross < 0 && s2_cross > 0) ||
                             (r1_cross >= -$signed(COL_EPS) && r1_cross <= $signed(COL_EPS) &&
                              r2_cross >= -$signed(COL_EPS) && r2_cross <= $signed(COL_EPS)) ||
                             (s1_cross >= -$signed(COL_EPS) && s1_cross <= $signed(COL_EPS) &&
                              s2_cross >= -$signed(COL_EPS) && s2_cross <= $signed(COL_EPS)));

            // Now compute intersections for the remaining two segment pairs
            // 02-13 (p1-p3 vs p2-p4)
            r1_cross <= (p3x - p1x) * (p2y - p1y) - (p3y - p1y) * (p2x - p1x);
            r2_cross <= (p3x - p1x) * (p4y - p3y) - (p3y - p1y) * (p4x - p3x);
            s1_cross <= (p3x - p1x) * (p4y - p2y) - (p3y - p1y) * (p4x - p2x);
            s2_cross <= (p3x - p1x) * (p3y - p1y) - (p3y - p1y) * (p3x - p1x); // zero
            subquad_state <= 3'd5;
            next_state <= CHECK_QUAD;
          end else if (subquad_state == 3'd5) begin
            seg02_13_int <= ((r1_cross > 0 && r2_cross < 0) || (r1_cross < 0 && r2_cross > 0) ||
                             (s1_cross > 0 && s2_cross < 0) || (s1_cross < 0 && s2_cross > 0) ||
                             (r1_cross >= -$signed(COL_EPS) && r1_cross <= $signed(COL_EPS) &&
                              r2_cross >= -$signed(COL_EPS) && r2_cross <= $signed(COL_EPS)) ||
                             (s1_cross >= -$signed(COL_EPS) && s1_cross <= $signed(COL_EPS) &&
                              s2_cross >= -$signed(COL_EPS) && s2_cross <= $signed(COL_EPS)));

            // 03-12 (p1-p4 vs p2-p3)
            r1_cross <= (p4x - p1x) * (p2y - p1y) - (p4y - p1y) * (p2x - p1x);
            r2_cross <= (p4x - p1x) * (p3y - p2y) - (p4y - p2y) * (p3x - p2x);
            s1_cross <= (p4x - p1x) * (p3y - p1y) - (p4y - p1y) * (p3x - p1x);
            s2_cross <= (p4x - p1x) * (p2y - p1y) - (p4y - p1y) * (p2x - p1x); // zero
            subquad_state <= 3'd6;
            next_state <= CHECK_QUAD;
          end else if (subquad_state == 3'd6) begin
            seg03_12_int <= ((r1_cross > 0 && r2_cross < 0) || (r1_cross < 0 && r2_cross > 0) ||
                             (s1_cross > 0 && s2_cross < 0) || (s1_cross < 0 && s2_cross > 0) ||
                             (r1_cross >= -$signed(COL_EPS) && r1_cross <= $signed(COL_EPS) &&
                              r2_cross >= -$signed(COL_EPS) && r2_cross <= $signed(COL_EPS)) ||
                             (s1_cross >= -$signed(COL_EPS) && s1_cross <= $signed(COL_EPS) &&
                              s2_cross >= -$signed(COL_EPS) && s2_cross <= $signed(COL_EPS)));
            // Now compute barycentric tests for point-in-convex-quad
            // Use (A,B,C,D) with A=c0, B=c1, C=c2, D=c3
            a0_dx <= $signed(troop_x[c1]) - $signed(troop_x[c0]);
            a0_dy <= $signed(troop_y[c1]) - $signed(troop_y[c0]);
            a1_dx <= $signed(troop_x[c2]) - $signed(troop_x[c0]);
            a1_dy <= $signed(troop_y[c2]) - $signed(troop_y[c0]);
            a2_dx <= $signed(troop_x[c3]) - $signed(troop_x[c0]);
            a2_dy <= $signed(troop_y[c3]) - $signed(troop_y[c0]);
            // Precompute P - A where P is current castle point
            p1x <= $signed(castle_x[castle_idx]);
            p1y <= $signed(castle_y[castle_idx]);
            subquad_state <= 3'd7;
            next_state <= CHECK_QUAD;
          end else if (subquad_state == 3'd7) begin
            // Cross products for inside check: (B-A)x(P-A), (C-B)x(P-B), (D-C)x(P-C), (A-D)x(P-D)
            b0_cross <= a0_dx * (p1y - $signed(troop_y[c0])) - a0_dy * (p1x - $signed(troop_x[c0]));
            b1_cross <= ($signed(troop_x[c2]) - $signed(troop_x[c1])) * (p1y - $signed(troop_y[c1])) -
                        ($signed(troop_y[c2]) - $signed(troop_y[c1])) * (p1x - $signed(troop_x[c1]));
            b2_cross <= ($signed(troop_x[c3]) - $signed(troop_x[c2])) * (p1y - $signed(troop_y[c2])) -
                        ($signed(troop_y[c3]) - $signed(troop_y[c2])) * (p1x - $signed(troop_x[c2]));
            b3_cross <= ($signed(troop_x[c0]) - $signed(troop_x[c3])) * (p1y - $signed(troop_y[c3])) -
                        ($signed(troop_y[c0]) - $signed(troop_y[c3])) * (p1x - $signed(troop_x[c3]));
            subquad_state <= 3'd8;
            next_state <= CHECK_QUAD;
          end else if (subquad_state == 3'd8) begin
            // Evaluate results from previous stages (non-degenerate, no intersections, inside)
            // Non-degenerate test: none of the triplet cross products near zero
            poly_ok <= (~col_012) & (~col_013) & (~col_023) & (~col_123);
            // No edge intersection for quadrilateral
            s_intersects <= seg01_23_int | seg02_13_int | seg03_12_int;
            // Point inside convex quad: all cross products must be non-negative (allowing border)
            quad_inside <= ((b0_cross >= -$signed(COL_EPS)) && (b1_cross >= -$signed(COL_EPS)) &&
                            (b2_cross >= -$signed(COL_EPS)) && (b3_cross >= -$signed(COL_EPS)));
            s_valid <= 1'b1;
            s_inside <= quad_inside;
            subquad_state <= 3'd9;
            next_state <= CHECK_QUAD;
          end else if (subquad_state == 3'd9) begin
            // Commit decision using previous-cycle signals to avoid combinational loops
            if (s_prev_valid) begin
              if (poly_ok && (~s_prev_intersects) && s_prev_inside) begin
                found_danger <= 1'b1;
                any_danger <= 1'b1;
                // Will return to CHECK_CASTLE to mark this castle as done
                subquad_state <= 3'd0;
                next_state <= CHECK_CASTLE;
              end else begin
                // Advance to next combination of 4 troops (lexicographic increment)
                // c3, c2, c1, c0 cascade
                if (c3 < (troop_cnt - 1)) begin
                  c3 <= c3 + 1;
                end else begin
                  c3 <= 2'd0;
                  if (c2 < (troop_cnt - 1)) begin
                    c2 <= c2 + 1;
                  end else begin
                    c2 <= 2'd0;
                    if (c1 < (troop_cnt - 1)) begin
                      c1 <= c1 + 1;
                    end else begin
                      c1 <= 2'd0;
                      if (c0 < (troop_cnt - 1)) begin
                        c0 <= c0 + 1;
                      end else begin
                        // no more combinations for this castle
                        subquad_state <= 3'd0;
                        next_state <= CHECK_CASTLE;
                      end
                    end
                  end
                end
                // reset control signals for next quad
                s_valid <= 1'b0; s_prev_valid <= 1'b0;
                s_intersects <= 1'b0; s_prev_intersects <= 1'b0;
                s_inside <= 1'b0; s_prev_inside <= 1'b0;
                subquad_state <= 3'd0; // restart checks for next quad
                next_state <= CHECK_QUAD;
              end
            end else begin
              // Haven't computed yet, continue
              subquad_state <= 3'd0;
              next_state <= CHECK_QUAD;
            end
          end else begin
            subquad_state <= 3'd0;
            next_state <= CHECK_QUAD;
          end
        end

        DONE: begin
          done <= 1'b1;
          danger_count <= any_danger ? (danger_count + 1'b1) : danger_count;
          // If more castles remain, count them on the fly
          if (castle_idx < (castle_cnt - 1)) begin
            danger_count <= any_danger ? (danger_count + 1'b1) : danger_count;
            // Move to next castle and continue counting if not already in danger
            if (!found_danger) begin
              castle_idx <= castle_idx + 1;
              found_danger <= 1'b0;
              any_danger <= 1'b0;
              next_state <= CHECK_CASTLE;
              // reset quad indices
              c0 <= 2'd0; c1 <= 2'd1; c2 <= 2'd2; c3 <= 2'd3;
              subquad_state <= 3'd0;
              s_valid <= 1'b0; s_prev_valid <= 1'b0;
              s_intersects <= 1'b0; s_prev_intersects <= 1'b0;
              s_inside <= 1'b0; s_prev_inside <= 1'b0;
            end else begin
              // This castle already in danger, move on
              castle_idx <= castle_idx + 1;
              found_danger <= 1'b0;
              any_danger <= 1'b0;
              next_state <= DONE; // remain here, we will accumulate counts in the next cycles
            end
          end else begin
            // all castles processed
            next_state <= DONE;
          end
        end

        default: begin
          next_state <= IDLE;
        end
      endcase
    end
  end

  // Next-state logic (combinational) to handle direct transitions not covered above
  always_comb begin
    // Default keep current state
    next_state = state;
    // Overrides are handled in the sequential block already,
    // but we keep this block for completeness if needed in future extensions.
  end

endmodule
