module truck_encounter_counter(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0] truck1_segments,
  input  [3:0] truck2_segments,
  input  [9:0] truck1_route [0:3],
  input  [9:0] truck2_route [0:3],
  output reg [7:0] encounter_count,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE      = 2'b00,
    VALIDATE  = 2'b01,
    SIMULATE  = 2'b10,
    COMPLETE  = 2'b11
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [11:0] time_cnt;          // 12-bit time counter (0-4095)
  reg        route_valid1;
  reg        route_valid2;
  reg        sim_done1;
  reg        sim_done2;

  // Segment indices
  reg [1:0] seg_idx1;
  reg [1:0] seg_idx2;

  // Positions: Q10.2 -> 12 bits (10 integer + 2 fractional)
  reg [11:0] pos1;
  reg [11:0] pos2;

  // Pre-latched segment counts
  reg [3:0] segs1_latched;
  reg [3:0] segs2_latched;

  // Per-truck direction and distance
  reg [9:0] t1_start_city, t1_end_city;
  reg [9:0] t2_start_city, t2_end_city;
  reg [9:0] t1_dist;      // absolute distance in city units
  reg [9:0] t2_dist;
  reg       t1_dir_pos;   // 1: increasing, 0: decreasing
  reg       t2_dir_pos;

  // Fixed-point per-minute step in Q10.2 (12 bits signed magnitude via dir flag)
  reg [11:0] t1_step_mag;
  reg [11:0] t2_step_mag;

  // Local wires for comparisons
  wire both_done = sim_done1 & sim_done2;

  // ------------------------------------------------------------
  // Helper tasks / functions
  // ------------------------------------------------------------

  // Validate zig-zag pattern: strictly alternating direction, valid segment count 2-4
  function automatic logic validate_route(
    input [3:0] segs,
    input [9:0] route [0:3]
  );
    int i;
    logic dir_prev;
    logic dir_cur;
    begin
      validate_route = 1'b0;
      if (segs < 2 || segs > 4)
        return 1'b0;

      // First direction must be non-zero distance
      if (route[1] == route[0])
        return 1'b0;
      dir_prev = (route[1] > route[0]);

      // Check alternating and non-zero for each subsequent
      for (i = 1; i < segs; i++) begin
        if (route[i] == route[i-1])
          return 1'b0;
        dir_cur = (route[i] > route[i-1]);
        if (dir_cur == dir_prev)
          return 1'b0;
        dir_prev = dir_cur;
      end

      validate_route = 1'b1;
    end
  endfunction

  // Compute segment parameters for a given truck
  task automatic load_segment(
    input  [3:0] segs_l,
    input  [9:0] route [0:3],
    input  [1:0] seg_idx,
    output [9:0] c_start,
    output [9:0] c_end,
    output [9:0] dist,
    output       dir_pos,
    output [11:0] step_mag
  );
    reg [9:0] a;
    reg [9:0] b;
    reg [9:0] d;
    begin
      if (seg_idx >= segs_l) begin
        // no active segment
        c_start = route[segs_l-1];
        c_end   = route[segs_l-1];
        dist    = 10'd0;
        dir_pos = 1'b1;
        step_mag = 12'd0;
      end else begin
        a = route[seg_idx];
        b = route[seg_idx+1];
        if (b >= a) begin
          d = b - a;
          dir_pos = 1'b1;
        end else begin
          d = a - b;
          dir_pos = 1'b0;
        end
        c_start = a;
        c_end   = b;
        dist    = d;
        // one minute per city -> step = 1.00 city = 4 in Q10.2
        // Problem statement does not specify varying speeds, so assume 1 city/min.
        // Bound by max time (4096) and small distances.
        step_mag = (d == 0) ? 12'd0 : 12'd4; // 1.00 in Q10.2
      end
    end
  endtask

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= IDLE;
      encounter_count  <= 8'd0;
      done             <= 1'b0;
      time_cnt         <= 12'd0;
      route_valid1     <= 1'b0;
      route_valid2     <= 1'b0;
      sim_done1        <= 1'b0;
      sim_done2        <= 1'b0;
      seg_idx1         <= 2'd0;
      seg_idx2         <= 2'd0;
      pos1             <= 12'd0;
      pos2             <= 12'd0;
      segs1_latched    <= 4'd0;
      segs2_latched    <= 4'd0;
      t1_start_city    <= 10'd0;
      t1_end_city      <= 10'd0;
      t2_start_city    <= 10'd0;
      t2_end_city      <= 10'd0;
      t1_dist          <= 10'd0;
      t2_dist          <= 10'd0;
      t1_dir_pos       <= 1'b1;
      t2_dir_pos       <= 1'b1;
      t1_step_mag      <= 12'd0;
      t2_step_mag      <= 12'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done            <= 1'b0;
          encounter_count <= 8'd0;
          time_cnt        <= 12'd0;
          sim_done1       <= 1'b0;
          sim_done2       <= 1'b0;

          if (start) begin
            // Latch segment counts and initialize
            segs1_latched <= truck1_segments;
            segs2_latched <= truck2_segments;
            seg_idx1      <= 2'd0;
            seg_idx2      <= 2'd0;

            // Validate routes combinationally next cycle
            route_valid1  <= validate_route(truck1_segments, truck1_route);
            route_valid2  <= validate_route(truck2_segments, truck2_route);

            // Initialize starting positions in Q10.2
            pos1 <= {truck1_route[0], 2'b00};
            pos2 <= {truck2_route[0], 2'b00};

            // Load first segments
            load_segment(truck1_segments, truck1_route, 2'd0,
                         t1_start_city, t1_end_city, t1_dist, t1_dir_pos, t1_step_mag);
            load_segment(truck2_segments, truck2_route, 2'd0,
                         t2_start_city, t2_end_city, t2_dist, t2_dir_pos, t2_step_mag);
          end
        end

        VALIDATE: begin
          // If invalid, go directly to COMPLETE with zero result
          if (!(route_valid1 & route_valid2)) begin
            done <= 1'b1;
          end else begin
            // Prepare for simulation
            done       <= 1'b0;
            time_cnt   <= 12'd0;
            sim_done1  <= 1'b0;
            sim_done2  <= 1'b0;
            seg_idx1   <= 2'd0;
            seg_idx2   <= 2'd0;
            pos1       <= {t1_start_city, 2'b00};
            pos2       <= {t2_start_city, 2'b00};
          end
        end

        SIMULATE: begin
          done <= 1'b0;

          // Time progress (limited by 4096)
          if (time_cnt != 12'hFFF)
            time_cnt <= time_cnt + 12'd1;

          // Truck 1 movement
          if (!sim_done1) begin
            if (t1_step_mag == 12'd0 || t1_dist == 10'd0) begin
              // No effective movement, mark done
              sim_done1 <= 1'b1;
            end else begin
              if (t1_dir_pos)
                pos1 <= pos1 + t1_step_mag;
              else
                pos1 <= pos1 - t1_step_mag;

              // Check segment end (position reached or passed)
              if (t1_dir_pos) begin
                if (pos1 >= {t1_end_city, 2'b00}) begin
                  seg_idx1 <= seg_idx1 + 2'd1;
                  if (seg_idx1 + 2'd1 >= segs1_latched) begin
                    pos1      <= {t1_end_city, 2'b00};
                    sim_done1 <= 1'b1;
                  end else begin
                    load_segment(segs1_latched, truck1_route, seg_idx1 + 2'd1,
                                 t1_start_city, t1_end_city, t1_dist, t1_dir_pos, t1_step_mag);
                    pos1 <= {t1_start_city, 2'b00};
                  end
                end
              end else begin
                if (pos1 <= {t1_end_city, 2'b00}) begin
                  seg_idx1 <= seg_idx1 + 2'd1;
                  if (seg_idx1 + 2'd1 >= segs1_latched) begin
                    pos1      <= {t1_end_city, 2'b00};
                    sim_done1 <= 1'b1;
                  end else begin
                    load_segment(segs1_latched, truck1_route, seg_idx1 + 2'd1,
                                 t1_start_city, t1_end_city, t1_dist, t1_dir_pos, t1_step_mag);
                    pos1 <= {t1_start_city, 2'b00};
                  end
                end
              end
            end
          end

          // Truck 2 movement
          if (!sim_done2) begin
            if (t2_step_mag == 12'd0 || t2_dist == 10'd0) begin
              sim_done2 <= 1'b1;
            end else begin
              if (t2_dir_pos)
                pos2 <= pos2 + t2_step_mag;
              else
                pos2 <= pos2 - t2_step_mag;

              if (t2_dir_pos) begin
                if (pos2 >= {t2_end_city, 2'b00}) begin
                  seg_idx2 <= seg_idx2 + 2'd1;
                  if (seg_idx2 + 2'd1 >= segs2_latched) begin
                    pos2      <= {t2_end_city, 2'b00};
                    sim_done2 <= 1'b1;
                  end else begin
                    load_segment(segs2_latched, truck2_route, seg_idx2 + 2'd1,
                                 t2_start_city, t2_end_city, t2_dist, t2_dir_pos, t2_step_mag);
                    pos2 <= {t2_start_city, 2'b00};
                  end
                end
              end else begin
                if (pos2 <= {t2_end_city, 2'b00}) begin
                  seg_idx2 <= seg_idx2 + 2'd1;
                  if (seg_idx2 + 2'd1 >= segs2_latched) begin
                    pos2      <= {t2_end_city, 2'b00};
                    sim_done2 <= 1'b1;
                  end else begin
                    load_segment(segs2_latched, truck2_route, seg_idx2 + 2'd1,
                                 t2_start_city, t2_end_city, t2_dist, t2_dir_pos, t2_step_mag);
                    pos2 <= {t2_start_city, 2'b00};
                  end
                end
              end
            end
          end

          // Encounter detection (combinational compare but registered count)
          // Conditions:
          // - Same non-integer position
          // - Not at city boundaries (ignore departure/turn/pickup integer times)
          if (!both_done) begin
            if ((pos1 == pos2) && (pos1[1:0] != 2'b00)) begin
              encounter_count <= encounter_count + 8'd1;
            end
          end
        end

        COMPLETE: begin
          // Hold done high; encounter_count stable
          done <= 1'b1;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  // ------------------------------------------------------------
  // Next-state logic
  // ------------------------------------------------------------
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = VALIDATE;
      end

      VALIDATE: begin
        if (!(route_valid1 & route_valid2))
          next_state = COMPLETE;
        else
          next_state = SIMULATE;
      end

      SIMULATE: begin
        // End when both trucks done or max time reached
        if (both_done || (time_cnt >= 12'd4095))
          next_state = COMPLETE;
      end

      COMPLETE: begin
        // Wait for next start to re-run
        if (start)
          next_state = VALIDATE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule