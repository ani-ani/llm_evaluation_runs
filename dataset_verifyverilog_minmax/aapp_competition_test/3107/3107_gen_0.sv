module truck_encounter_counter (
  input clk,
  input rst_n,
  input start,
  input [3:0] truck1_segments,     // 2-4
  input [3:0] truck2_segments,     // 2-4
  input [9:0] truck1_route [0:3],  // city positions (Q10.2 integer part)
  input [9:0] truck2_route [0:3],  // city positions (Q10.2 integer part)

  output reg [7:0] encounter_count, // number of meetings
  output reg done                   // high when calculation complete
);

  // Q10.2 fixed-point: 10-bit integer, 2-bit fractional
  // Positions are stored as integer-part only (city nodes).
  // Progress is tracked in [0, 1) using a 2-bit fraction representing 0, 0.25, 0.5, 0.75.

  typedef enum logic [1:0] {
    IDLE     = 2'b00,
    VALIDATE = 2'b01,
    SIMULATE = 2'b10,
    COMPLETE = 2'b11
  } state_t;

  state_t state, next_state;

  // Simulation control
  reg sim_enable;        // 1 when simulation is running
  reg [11:0] time_cnt;   // minutes, up to 4095

  // Inputs sampled at start
  reg [3:0] s_t1_seg, s_t2_seg;
  reg [9:0] s_t1_route [0:3];
  reg [9:0] s_t2_route [0:3];

  // Route analysis
  reg route_valid;           // both routes zigzag-valid
  reg [7:0] t1_total_len;    // total segments length (minutes)
  reg [7:0] t2_total_len;

  // Current position (fractional progress within current segment)
  reg [1:0] t1_frac;  // 0,1,2,3 => 0.00, 0.25, 0.50, 0.75
  reg [1:0] t2_frac;

  // Per-segment state
  reg [6:0] t1_seg_len; // length of current segment in minutes (0..100)
  reg [6:0] t2_seg_len;
  reg [1:0] t1_seg_idx; // which city -> city+1 we are moving along (0..(Nseg-1))
  reg [1:0] t2_seg_idx;

  // Combinatorial encounter detection (used in SIMULATE state)
  wire same_pos;
  wire both_non_integer;
  assign same_pos = (s_t1_route[t1_seg_idx] == s_t2_route[t2_seg_idx]) &&
                    (t1_frac == t2_frac);
  assign both_non_integer = (t1_frac != 2'b00) || (t2_frac != 2'b00);

  // State machine sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      sim_enable   <= 1'b0;
      time_cnt     <= 12'h0;
      encounter_count <= 8'h0;
      done         <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          encounter_count <= 8'h0;
          done            <= 1'b0;
          time_cnt        <= 12'h0;
          sim_enable      <= 1'b0;
          if (start) begin
            // Sample inputs
            s_t1_seg <= truck1_segments;
            s_t2_seg <= truck2_segments;
            s_t1_route[0] <= truck1_route[0];
            s_t1_route[1] <= truck1_route[1];
            s_t1_route[2] <= truck1_route[2];
            s_t1_route[3] <= truck1_route[3];
            s_t2_route[0] <= truck2_route[0];
            s_t2_route[1] <= truck2_route[1];
            s_t2_route[2] <= truck2_route[2];
            s_t2_route[3] <= truck2_route[3];
            state <= VALIDATE;
          end else begin
            state <= IDLE;
          end
        end

        VALIDATE: begin
          // Compute validity and parameters combinatorially
          analyze_route(s_t1_route, s_t1_seg, 1'b1);  // sets route_valid_t1, t1_total_len
          analyze_route(s_t2_route, s_t2_seg, 1'b1);  // sets route_valid_t2, t2_total_len
          // route_valid becomes 1 only if both are valid (done in compute block below)
          state <= SIMULATE;
        end

        SIMULATE: begin
          if (!sim_enable) begin
            // Initialize simulation only if routes are valid
            sim_enable   <= route_valid;
            time_cnt     <= 12'h0;
            encounter_count <= 8'h0;
            t1_frac      <= 2'b00;
            t2_frac      <= 2'b00;
            t1_seg_idx   <= 2'd0;
            t2_seg_idx   <= 2'd0;
            // Precompute first segment lengths
            t1_seg_len   <= (route_valid ? seg_len(s_t1_route[0], s_t1_route[1]) : 7'd0);
            t2_seg_len   <= (route_valid ? seg_len(s_t2_route[0], s_t2_route[1]) : 7'd0);
          end else begin
            // Advance time by 1 minute
            time_cnt <= time_cnt + 1;

            // Per-truck progress update
            // Truck 1
            if (t1_seg_len == 0) begin
              // Guard: no movement; freeze fraction
              t1_frac <= t1_frac;
            end else if (t1_frac == 2'b11) begin
              // 0.75 -> 1.00: segment complete
              t1_frac <= 2'b00;
              if ((t1_seg_idx + 1) < (s_t1_seg - 1)) begin
                t1_seg_idx <= t1_seg_idx + 1;
                t1_seg_len <= seg_len(s_t1_route[t1_seg_idx+1], s_t1_route[t1_seg_idx+2]);
              end else begin
                // Finished last segment
                t1_seg_len <= 7'd0;
              end
            end else begin
              // 0.00->0.25, 0.25->0.50, 0.50->0.75
              t1_frac <= t1_frac + 1;
            end

            // Truck 2
            if (t2_seg_len == 0) begin
              t2_frac <= t2_frac;
            end else if (t2_frac == 2'b11) begin
              t2_frac <= 2'b00;
              if ((t2_seg_idx + 1) < (s_t2_seg - 1)) begin
                t2_seg_idx <= t2_seg_idx + 1;
                t2_seg_len <= seg_len(s_t2_route[t2_seg_idx+1], s_t2_route[t2_seg_idx+2]);
              end else begin
                t2_seg_len <= 7'd0;
              end
            end else begin
              t2_frac <= t2_frac + 1;
            end

            // Combinatorial encounter check (same non-integer position)
            if (route_valid && same_pos && both_non_integer) begin
              encounter_count <= encounter_count + 1;
            end

            // Determine completion: both done and within 4096+100 cycles
            // A truck is done when it reached end of its last segment and fraction rolled to 0.
            // Use 12-bit time limit (4095) + cap at 4096+99 in the next_state logic.
            if (time_cnt >= 12'd4095) begin
              sim_enable <= 1'b0;
              state <= COMPLETE;
            end else begin
              if ((t1_seg_len == 0) && (t2_seg_len == 0) &&
                  (t1_frac == 2'b00) && (t2_frac == 2'b00)) begin
                sim_enable <= 1'b0;
                state <= COMPLETE;
              end else begin
                state <= SIMULATE;
              end
            end
          end
        end

        COMPLETE: begin
          // Hold done for 1 cycle, result is stable in encounter_count
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

  // Continuous route validity aggregation (used in VALIDATE and SIMULATE init)
  // Evaluate both trucks' routes and set route_valid and total lengths.
  // This compute block is read by the state machine when leaving VALIDATE
  // and when initializing SIMULATE.
  reg route_valid_t1, route_valid_t2;
  reg [7:0] t1_total_len_compute, t2_total_len_compute;

  always_comb begin
    analyze_route(s_t1_route, s_t1_seg, 1'b0);
    route_valid_t1 = route_valid_t1_compute;
    t1_total_len_compute = t1_total_len_compute_reg;
    analyze_route(s_t2_route, s_t2_seg, 1'b0);
    route_valid_t2 = route_valid_t2_compute;
    t2_total_len_compute = t2_total_len_compute_reg;
    route_valid = (route_valid_t1 && route_valid_t2);
    t1_total_len = t1_total_len_compute;
    t2_total_len = t2_total_len_compute;
  end

  // --- Helper functions and internals for route analysis ---
  // Manhattan distance between two city positions (clamped to 100)
  function [6:0] seg_len;
    input [9:0] a, b;
    integer dx, dy, dist;
    begin
      dx = $signed({1'b0, b[9:5]}) - $signed({1'b0, a[9:5]});
      dy = $signed({1'b0, b[4:0]}) - $signed({1'b0, a[4:0]});
      if (dx < 0) dx = -dx;
      if (dy < 0) dy = -dy;
      dist = dx + dy;
      if (dist > 100) dist = 100;
      seg_len = 7'(dist);
    end
  endfunction

  // Analyze a route (zigzag validation, non-zero segments, total length)
  // Uses a compute-reg pattern to export results to the always_comb block above.
  reg route_valid_t1_compute;
  reg route_valid_t2_compute;
  reg [7:0] t1_total_len_compute_reg;
  reg [7:0] t2_total_len_compute_reg;

  task analyze_route;
    input [9:0] r [0:3];
    input [3:0] segs;
    input dummy; // not used, kept for future extensions
    reg ok;
    integer orient;  // 0=x, 1=y, -1=unset
    reg [6:0] len;
    reg [7:0] total;
    integer dx, dy;
  begin
    ok = 1'b1;
    orient = -1;
    total = 8'd0;

    if ((segs < 4'd2) || (segs > 4'd4)) ok = 1'b0;

    // Check each segment and that it is axis-aligned, non-zero length
    for (int i = 0; i < 3; i = i + 1) begin
      dx = $signed({1'b0, r[i+1][9:5]}) - $signed({1'b0, r[i][9:5]});
      dy = $signed({1'b0, r[i+1][4:0]}) - $signed({1'b0, r[i][4:0]});

      // Both trucks may have unused trailing cities, only check up to segs-1
      if (i < (segs - 1)) begin
        if ((dx != 0 && dy != 0) || (dx == 0 && dy == 0)) begin
          ok = 1'b0; // not axis-aligned or zero length
        end else begin
          len = seg_len(r[i], r[i+1]);
          if (len == 0) ok = 1'b0;
          total = total + len;
          if (orient == -1) begin
            orient = (dx != 0) ? 0 : 1; // 0:x, 1:y
          end else begin
            // Enforce zigzag: orientation must change at each segment
            if ((dx != 0 && orient != 0) || (dy != 0 && orient != 1)) begin
              ok = 1'b0;
            end
            // Flip orientation for next segment
            orient = (orient == 0) ? 1 : 0;
          end
        end
      end
    end

    // Assign into compute regs (this task is called twice in the always_comb)
    // Distinguish by reading segs from the s_* regs available in scope.
    if (segs === s_t1_seg) begin
      route_valid_t1_compute = ok;
      t1_total_len_compute_reg = total;
    end else begin
      route_valid_t2_compute = ok;
      t2_total_len_compute_reg = total;
    end
  end
  endtask

endmodule
