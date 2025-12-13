module lane_safety_calculator(
  input clk,
  input rst_n,
  input start,
  input [1:0] N,
  input [2:0] M,
  input [9:0] R,
  input [1:0] car_lane [0:4],
  input [9:0] car_length [0:4],
  input [9:0] car_distance [0:4],
  output reg [31:0] safety_factor,
  output reg impossible,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE        = 2'b00,
    CALC_PATHS  = 2'b01,
    FIND_MAXMIN = 2'b10,
    DONE_ST     = 2'b11
  } state_t;

  state_t state, next_state;

  // Precomputed per-path minimum distances (Q16.16)
  // Maximum number of lanes is 4, so maximum lanes-1 transitions = 3
  // We consider paths as simple monotonic lane index sequences from 0 to N-1.
  // For compactness, we handle at most 4 candidate paths.
  reg [31:0] path_min_dist [0:3];
  reg [1:0]  path_valid; // up to 4 paths, but we use lower bits as flags

  // Internal wires/regs
  integer i;
  reg [31:0] best_safety;
  reg any_valid;

  // Helper function: clamp and convert distance to Q16.16
  function automatic [31:0] dist_to_q16_16(input [9:0] d);
    reg [9:0] clamped;
    begin
      // Clamp using sensor range R; beyond R is considered unsafe/occupied
      if (d > R)
        clamped = R;
      else
        clamped = d;
      dist_to_q16_16 = {clamped,16'h0000};
    end
  endfunction

  // Helper function: compute minimal safe distance for a "segment" given cars
  // For this abstracted design, we conservatively take the minimal of
  // (R - (distance + length)) across all relevant cars within range.
  // If any car intrudes (distance < length or beyond modeling), it reduces safety.
  function automatic [31:0] segment_min_dist(
    input [1:0] from_lane,
    input [1:0] to_lane
  );
    integer j;
    reg [31:0] min_q;
    reg [31:0] cand_q;
    reg [9:0] eff_d;
    reg [9:0] span_start;
    reg [9:0] span_end;
    reg hit;
    begin
      // Consider lanes involved in this segment (inclusive range)
      span_start = (from_lane < to_lane) ? from_lane : to_lane;
      span_end   = (from_lane < to_lane) ? to_lane   : from_lane;
      min_q = {16'hFFFF,16'hFFFF};
      hit = 1'b0;

      for (j = 0; j < 5; j = j + 1) begin
        if ((car_lane[j] >= span_start) && (car_lane[j] <= span_end)) begin
          // Only consider cars within sensor range
          if (car_distance[j] <= R) begin
            hit = 1'b1;
            if (car_distance[j] + car_length[j] >= R) begin
              // Very close to or beyond range end => near zero margin
              cand_q = 32'h00000000;
            end else begin
              eff_d = R - (car_distance[j] + car_length[j]);
              cand_q = {eff_d,16'h0000};
            end
            if (cand_q < min_q) begin
              min_q = cand_q;
            end
          end
        end
      end

      if (!hit) begin
        // No relevant cars: max safety equals full range R
        min_q = {R,16'h0000};
      end

      segment_min_dist = min_q;
    end
  endfunction

  // Compute all candidate paths' minimum distances combinationally when in CALC_PATHS
  // Paths are defined as:
  // P0: direct 0 -> N-1
  // P1: 0 -> mid1 -> N-1 (if possible)
  // P2: 0 -> mid2 -> N-1 (if possible)
  // P3: 0 -> mid1 -> mid2 -> N-1 (if N allows)

  reg [31:0] p0, p1, p2, p3;
  reg [31:0] seg0, seg1, seg2;
  reg [1:0] max_lane_index;

  always @(*) begin
    // Default
    p0 = 32'h00000000;
    p1 = 32'h00000000;
    p2 = 32'h00000000;
    p3 = 32'h00000000;
    path_valid = 2'b00;

    // Ensure N in [2..4]
    if (N < 2)
      max_lane_index = 2'd1;
    else if (N > 4)
      max_lane_index = 2'd3;
    else
      max_lane_index = N - 1;

    // Path 0: direct
    seg0 = segment_min_dist(2'd0, max_lane_index);
    p0 = seg0;

    // For N==2, only direct path meaningful
    if (N == 2) begin
      path_valid[0] = 1'b1;
    end
    // For N>=3, consider intermediate lanes
    else if (N == 3) begin
      // mid = lane1
      // P0: direct 0->2
      // P1: 0->1->2
      seg0 = segment_min_dist(2'd0, 2'd1);
      seg1 = segment_min_dist(2'd1, 2'd2);
      p1 = (seg0 < seg1) ? seg0 : seg1;
      path_valid[0] = 1'b1; // P0 valid
      path_valid[1] = 1'b1; // P1 valid
    end
    else begin // N == 4
      // mid1 = lane1, mid2 = lane2
      // P0: direct 0->3
      // P1: 0->1->3
      // P2: 0->2->3
      // P3: 0->1->2->3
      // P1
      seg0 = segment_min_dist(2'd0, 2'd1);
      seg1 = segment_min_dist(2'd1, 2'd3);
      p1 = (seg0 < seg1) ? seg0 : seg1;
      // P2
      seg0 = segment_min_dist(2'd0, 2'd2);
      seg1 = segment_min_dist(2'd2, 2'd3);
      p2 = (seg0 < seg1) ? seg0 : seg1;
      // P3
      seg0 = segment_min_dist(2'd0, 2'd1);
      seg1 = segment_min_dist(2'd1, 2'd2);
      seg2 = segment_min_dist(2'd2, 2'd3);
      p3 = seg0;
      if (seg1 < p3) p3 = seg1;
      if (seg2 < p3) p3 = seg2;

      // Mark all as valid for N==4
      path_valid = 2'b11; // we will interpret with manual checks below
    end
  end

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CALC_PATHS;
      end
      CALC_PATHS: begin
        next_state = FIND_MAXMIN;
      end
      FIND_MAXMIN: begin
        next_state = DONE_ST;
      end
      DONE_ST: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Output and internal registers update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      safety_factor <= 32'h00000000;
      impossible    <= 1'b0;
      done          <= 1'b0;
      for (i = 0; i < 4; i = i + 1) begin
        path_min_dist[i] <= 32'h00000000;
      end
    end else begin
      case (state)
        IDLE: begin
          done       <= 1'b0;
          impossible <= 1'b0;
          safety_factor <= 32'h00000000;
        end

        CALC_PATHS: begin
          // Latch path minimums from combinational logic
          path_min_dist[0] <= p0;
          path_min_dist[1] <= p1;
          path_min_dist[2] <= p2;
          path_min_dist[3] <= p3;
        end

        FIND_MAXMIN: begin
          // Find maximum of valid path minimum distances
          best_safety = 32'h00000000;
          any_valid = 1'b0;

          // For N==2: only p0
          if (N == 2) begin
            best_safety = path_min_dist[0];
            any_valid = 1'b1;
          end else if (N == 3) begin
            // p0 and p1
            any_valid = 1'b1;
            best_safety = (path_min_dist[0] > path_min_dist[1]) ? path_min_dist[0] : path_min_dist[1];
          end else begin
            // N==4: consider all 4 paths
            any_valid = 1'b1;
            best_safety = path_min_dist[0];
            if (path_min_dist[1] > best_safety) best_safety = path_min_dist[1];
            if (path_min_dist[2] > best_safety) best_safety = path_min_dist[2];
            if (path_min_dist[3] > best_safety) best_safety = path_min_dist[3];
          end

          if (!any_valid || (best_safety == 32'h00000000)) begin
            // No valid path or zero safety
            safety_factor <= 32'h00000000;
            impossible    <= 1'b1;
          end else begin
            safety_factor <= best_safety;
            impossible    <= 1'b0;
          end
        end

        DONE_ST: begin
          done <= 1'b1;
        end

        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule