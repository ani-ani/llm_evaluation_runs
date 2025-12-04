module loop_validator(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_points,
  input [15:0] x_in,
  input [15:0] y_in,
  input point_valid,
  output reg valid_loop,
  output reg done
);

  // Parameters
  localparam IDLE       = 2'b00;
  localparam LOADING    = 2'b01;
  localparam PROCESSING = 2'b10;
  localparam DONE       = 2'b11;

  // Internal storage for up to 8 points
  reg [15:0] x_mem [0:7];
  reg [15:0] y_mem [0:7];

  reg [1:0] state, next_state;

  reg [2:0] load_idx;
  reg [2:0] N; // latched num_points

  // Cycle counter to enforce done timing: 10 + 2*N cycles after start
  reg [5:0] cycle_cnt; // enough for max 10 + 2*8 = 26
  reg       started;

  // Control flags
  reg load_done;

  // Validation flags
  reg rule_neighbors_ok;
  reg rule_alt_dir_ok;
  reg rule_closed_ok;
  reg rule_no_self_intersect;

  // Combinational signals
  integer i, j, k;

  // Helper wires/regs
  reg [2:0] neigh_x_cnt [0:7];
  reg [2:0] neigh_y_cnt [0:7];

  // Segment representations for intersection checks
  // Segment i connects point i to point (i+1)%N
  // Classify as horizontal or vertical (axis-aligned) and store ranges
  reg [7:0] seg_is_h;
  reg [7:0] seg_is_v;

  // FSM sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      load_idx   <= 3'd0;
      N          <= 3'd0;
      cycle_cnt  <= 6'd0;
      started    <= 1'b0;
      valid_loop <= 1'b0;
      done       <= 1'b0;
    end else begin
      state <= next_state;

      // Start edge: latch N and reset counters
      if (start && !started) begin
        started    <= 1'b1;
        N          <= num_points;
        load_idx   <= 3'd0;
        cycle_cnt  <= 6'd0;
        valid_loop <= 1'b0;
        done       <= 1'b0;
      end else if (state != IDLE || started) begin
        // Increment cycle counter after start until we assert done
        if (!done)
          cycle_cnt <= cycle_cnt + 6'd1;
      end

      // Loading points
      if (state == LOADING) begin
        if (point_valid && (load_idx < N)) begin
          x_mem[load_idx] <= x_in;
          y_mem[load_idx] <= y_in;
          load_idx        <= load_idx + 3'd1;
        end
      end

      // DONE state: latch outputs when reaching required latency
      if (state == PROCESSING) begin
        // Outputs driven when transitioning to DONE (combinational next_state)
      end

      if (state == DONE) begin
        // Hold done and valid_loop until next start/reset
      end

      // Clear started flag when returning to IDLE without an active start
      if (state == DONE && next_state == IDLE) begin
        started <= 1'b0;
      end
    end
  end

  // Combinational FSM next state and validation logic
  always @* begin
    next_state           = state;
    load_done            = 1'b0;

    // Defaults
    rule_neighbors_ok        = 1'b0;
    rule_alt_dir_ok          = 1'b0;
    rule_closed_ok           = 1'b0;
    rule_no_self_intersect   = 1'b0;

    // Local copies for calculations (not storage)
    for (i = 0; i < 8; i = i + 1) begin
      neigh_x_cnt[i] = 3'd0;
      neigh_y_cnt[i] = 3'd0;
    end

    // Default: no segments until PROCESSING with valid N
    seg_is_h = 8'd0;
    seg_is_v = 8'd0;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = LOADING;
        end
      end

      LOADING: begin
        // Move to PROCESSING once all N points are captured
        if (load_idx == N) begin
          load_done  = 1'b1;
          next_state = PROCESSING;
        end
      end

      PROCESSING: begin
        // Perform all checks combinationally based on stored points
        // Only meaningful if N >= 3 and N <= 8
        if (N >= 3 && N <= 8) begin
          integer i_next;

          // Build segments and classify axis alignment
          for (i = 0; i < 8; i = i + 1) begin
            if (i < N) begin
              i_next = (i == N-1) ? 0 : (i + 1);
              if (i_next < N) begin
                if (y_mem[i] == y_mem[i_next] && x_mem[i] != x_mem[i_next]) begin
                  seg_is_h[i] = 1'b1;
                  seg_is_v[i] = 1'b0;
                end else if (x_mem[i] == x_mem[i_next] && y_mem[i] != y_mem[i_next]) begin
                  seg_is_h[i] = 1'b0;
                  seg_is_v[i] = 1'b1;
                end else begin
                  // Non-axis-aligned or zero-length => invalid
                  seg_is_h[i] = 1'b0;
                  seg_is_v[i] = 1'b0;
                end
              end
            end
          end

          // a) Neighbor check: each point must have exactly one same-x neighbor
          //    and one same-y neighbor among all other points
          for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
              if (i != j) begin
                if (x_mem[i] == x_mem[j])
                  neigh_x_cnt[i] = neigh_x_cnt[i] + 3'd1;
                if (y_mem[i] == y_mem[j])
                  neigh_y_cnt[i] = neigh_y_cnt[i] + 3'd1;
              end
            end
          end

          rule_neighbors_ok = 1'b1;
          for (i = 0; i < N; i = i + 1) begin
            if (neigh_x_cnt[i] != 3'd1 || neigh_y_cnt[i] != 3'd1)
              rule_neighbors_ok = 1'b0;
          end

          // b) Alternate horizontal/vertical segments for consecutive edges
          rule_alt_dir_ok = 1'b1;
          for (i = 0; i < N; i = i + 1) begin
            i_next = (i == N-1) ? 0 : (i + 1);
            if (seg_is_h[i] == 1'b0 && seg_is_v[i] == 1'b0)
              rule_alt_dir_ok = 1'b0; // invalid segment
            if (seg_is_h[i] == seg_is_h[i_next]) // same orientation or both 0
              rule_alt_dir_ok = 1'b0;
          end

          // c) Loop closed is implicitly guaranteed by using segment (i)->(i+1)%N
          // Additional sanity: all segments must be valid axis-aligned
          rule_closed_ok = 1'b1;
          for (i = 0; i < N; i = i + 1) begin
            if (!(seg_is_h[i] ^ seg_is_v[i])) // must be exactly one of H/V
              rule_closed_ok = 1'b0;
          end

          // d) No self-intersections except at shared endpoints
          rule_no_self_intersect = 1'b1;
          for (i = 0; i < N; i = i + 1) begin
            integer i_n;
            reg [15:0] x1, y1, x2, y2;
            reg [15:0] min_x_i, max_x_i, min_y_i, max_y_i;
            i_n = (i == N-1) ? 0 : (i + 1);
            x1 = x_mem[i];
            y1 = y_mem[i];
            x2 = x_mem[i_n];
            y2 = y_mem[i_n];
            if (x1 < x2) begin
              min_x_i = x1; max_x_i = x2;
            end else begin
              min_x_i = x2; max_x_i = x1;
            end
            if (y1 < y2) begin
              min_y_i = y1; max_y_i = y2;
            end else begin
              min_y_i = y2; max_y_i = y1;
            end

            for (j = 0; j < N; j = j + 1) begin
              integer j_n;
              reg [15:0] x3, y3, x4, y4;
              reg [15:0] min_x_j, max_x_j, min_y_j, max_y_j;

              j_n = (j == N-1) ? 0 : (j + 1);
              if (j <= i+1 && j_n <= i+1 && (i == j || i == j_n || i_n == j || i_n == j_n)) begin
                // Skip same or adjacent segments (they share endpoints by design)
              end

              x3 = x_mem[j];
              y3 = y_mem[j];
              x4 = x_mem[j_n];
              y4 = y_mem[j_n];

              if (x3 < x4) begin
                min_x_j = x3; max_x_j = x4;
              end else begin
                min_x_j = x4; max_x_j = x3;
              end
              if (y3 < y4) begin
                min_y_j = y3; max_y_j = y4;
              end else begin
                min_y_j = y4; max_y_j = y3;
              end

              // Intersection checks only if non-adjacent
              if (!((i == j) || (i == j_n) || (i_n == j) || (i_n == j_n))) begin
                // Case 1: perpendicular intersection between horizontal and vertical
                if (seg_is_h[i] && seg_is_v[j]) begin
                  if ((x3 >= min_x_i) && (x3 <= max_x_i) &&
                      (y1 >= min_y_j) && (y1 <= max_y_j)) begin
                    rule_no_self_intersect = 1'b0;
                  end
                end else if (seg_is_v[i] && seg_is_h[j]) begin
                  if ((x1 >= min_x_j) && (x1 <= max_x_j) &&
                      (y3 >= min_y_i) && (y3 <= max_y_i)) begin
                    rule_no_self_intersect = 1'b0;
                  end
                end

                // Case 2: collinear overlap beyond shared endpoints
                if (seg_is_h[i] && seg_is_h[j] && (y1 == y3)) begin
                  if (!((max_x_i < min_x_j) || (max_x_j < min_x_i))) begin
                    // Overlap exists; ensure they only meet at endpoints
                    if (!((x1 == x3 && (y1 == y3)) || (x1 == x4 && (y1 == y4)) ||
                          (x2 == x3 && (y2 == y3)) || (x2 == x4 && (y2 == y4)))) begin
                      rule_no_self_intersect = 1'b0;
                    end
                  end
                end
                if (seg_is_v[i] && seg_is_v[j] && (x1 == x3)) begin
                  if (!((max_y_i < min_y_j) || (max_y_j < min_y_i))) begin
                    if (!((x1 == x3 && (y1 == y3)) || (x1 == x4 && (y1 == y4)) ||
                          (x2 == x3 && (y2 == y3)) || (x2 == x4 && (y2 == y4)))) begin
                      rule_no_self_intersect = 1'b0;
                    end
                  end
                end
              end
            end
          end
        end else begin
          // Invalid N
          rule_neighbors_ok      = 1'b0;
          rule_alt_dir_ok        = 1'b0;
          rule_closed_ok         = 1'b0;
          rule_no_self_intersect = 1'b0;
        end

        // Determine transition to DONE based on required latency
        // done must be asserted at cycle = 10 + 2*N after start.
        // Here we transition when the counter reaches that value.
        if (cycle_cnt >= (10 + (N << 1))) begin
          next_state = DONE;
        end
      end

      DONE: begin
        // Wait for either a new start or remain until reset
        if (start) begin
          next_state = LOADING;
        end else if (!started) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Output logic: synchronous with reaching DONE state at correct cycle
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_loop <= 1'b0;
      done       <= 1'b0;
    end else begin
      if (state == PROCESSING && next_state == DONE) begin
        valid_loop <= rule_neighbors_ok & rule_alt_dir_ok & rule_closed_ok & rule_no_self_intersect;
        done       <= 1'b1;
      end else if (state != DONE) begin
        // Clear done before final decision
        if (!(state == PROCESSING && next_state == DONE)) begin
          done <= 1'b0;
        end
      end
    end
  end

endmodule