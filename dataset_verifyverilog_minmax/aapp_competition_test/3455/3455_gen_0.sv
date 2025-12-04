module lane_safety_calculator(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start computation
  input [1:0] N, // number of lanes (2-4) - 2 bits
  input [2:0] M, // total cars (1-5) - 3 bits
  input [9:0] R, // sensor range (1-1024) - 10 bits
  input [1:0] car_lane [0:4], // 5 cars, 2 bits each
  input [9:0] car_length [0:4], // 5 cars, 10 bits each
  input [9:0] car_distance [0:4], // 5 cars, 10 bits each
  output reg [31:0] safety_factor, // Q16.16 fixed-point
  output reg impossible, // 1 if no path exists
  output reg done // high when computation complete
);

  // State machine
  typedef enum logic [1:0] {IDLE = 2'b00, CALC_PATHS = 2'b01, FIND_MAX_MIN = 2'b10, DONE = 2'b11} state_t;
  state_t state, state_next;
  logic start_sync, start_d1, start_d2;
  logic start_rising;

  // Fixed-point conversion constants
  localparam INTBITS = 16;
  localparam FRACBITS = 16;
  localparam Q16_16_ONE = 32'h00010000; // 1.0 in Q16.16

  // Latches to stabilize input across 2 cycles
  logic [1:0] N_r;                 // number of lanes (2-4)
  logic [2:0] M_r;                 // total cars (1-5)
  logic [9:0] R_r;                 // sensor range
  logic [1:0] car_lane_r [0:4];    // 5 cars, 2 bits each
  logic [9:0] car_length_r [0:4];  // 5 cars, 10 bits each
  logic [9:0] car_distance_r [0:4];// 5 cars, 10 bits each

  // Latch lane data for both lanes 0 and target lane, for 3 cycles
  // We need both current and previous values for the 3-cycle algorithm
  logic [9:0] lane0_dist [0:2];   // index: 0=current, 1=prev, 2=prev2
  logic [9:0] lane0_len  [0:2];
  logic [1:0] target_lane_dist [0:2]; // target lane number (0..3), latch for 3 cycles
  logic [9:0] target_dist [0:2];
  logic [9:0] target_len  [0:2];

  // Pipeline for path feasibility (occupied) and minimum distance (Q16.16)
  // max 3 lanes -> 6 two-step paths (e.g., for 4 lanes: 0-1,0-2,0-3,1-2,1-3,2-3)
  localparam MAX_PATHS = 6;
  logic path_occupied [0:1][0:MAX_PATHS-1]; // 2 cycles x 6 paths
  logic [31:0] min_q16  [0:1][0:MAX_PATHS-1];
  logic [31:0] min_q16_r1 [0:MAX_PATHS-1]; // registered in FIND_MAX_MIN cycle

  // Max-min computation registers
  logic [31:0] cur_max, cur_max_next;
  logic cur_impossible, cur_impossible_next;

  // Start pulse detection (synchronous)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_sync <= 1'b0;
      start_d1   <= 1'b0;
      start_d2   <= 1'b0;
    end else begin
      start_sync <= start;
      start_d1   <= start_sync;
      start_d2   <= start_d1;
    end
  end
  assign start_rising = start_sync && !start_d1;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= state_next;
  end

  // Next-state logic + data pipeline
  always @(*) begin
    state_next = state;

    // Default: keep pipeline values (will be overridden in CALC_PATHS)
    N_r = N_r;
    M_r = M_r;
    R_r = R_r;
    car_lane_r = car_lane_r;
    car_length_r = car_length_r;
    car_distance_r = car_distance_r;

    target_lane_dist[0] = target_lane_dist[0];
    target_lane_dist[1] = target_lane_dist[1];
    target_lane_dist[2] = target_lane_dist[2];
    target_dist[0] = target_dist[0];
    target_dist[1] = target_dist[1];
    target_dist[2] = target_dist[2];
    target_len[0] = target_len[0];
    target_len[1] = target_len[1];
    target_len[2] = target_len[2];
    lane0_dist[0] = lane0_dist[0];
    lane0_dist[1] = lane0_dist[1];
    lane0_dist[2] = lane0_dist[2];
    lane0_len[0] = lane0_len[0];
    lane0_len[1] = lane0_len[1];
    lane0_len[2] = lane0_len[2];

    // Default path/accumulation (won't be used unless we re-enter CALC_PATHS)
    cur_max_next = cur_max;
    cur_impossible_next = cur_impossible;

    case (state)
      IDLE: begin
        if (start_rising) begin
          // Latch inputs and start computation
          N_r = N;
          M_r = M;
          R_r = R;
          car_lane_r = car_lane;
          car_length_r = car_length;
          car_distance_r = car_distance;

          // Reset accumulators
          cur_max_next = 32'h0;
          cur_impossible_next = 1'b1; // becomes 0 if any valid path is found

          // Shift lane0/Target registers
          lane0_dist[2] = lane0_dist[1];
          lane0_dist[1] = lane0_dist[0];
          lane0_len[2]  = lane0_len[1];
          lane0_len[1]  = lane0_len[0];
          target_lane_dist[2] = target_lane_dist[1];
          target_lane_dist[1] = target_lane_dist[0];
          target_dist[2] = target_dist[1];
          target_dist[1] = target_dist[0];
          target_len[2]  = target_len[1];
          target_len[1]  = target_len[0];

          // Compute current lane0 and target-lane data for cycle 0
          lane0_dist[0] = 10'h0;   // lane 0 is at sensor origin
          lane0_len[0]  = 10'h0;
          // Determine target lane from latched N (target lane = N-1)
          target_lane_dist[0] = (N_r === 2'd0) ? 2'd0 : (N_r - 2'd1);

          // Find any car in lane0 or target lane for this cycle
          // Lane0 (fixed origin)
          lane0_len[0]  = 10'h0;  // no car defines origin, but set len=0 (used only if car present)
          lane0_dist[0] = 10'h0;  // origin position for lane 0
          begin
            logic found0;
            found0 = 1'b0;
            for (int i = 0; i < 5; i++) begin
              if (!found0 && i < M_r && car_lane_r[i] === 2'd0) begin
                lane0_len[0]  = car_length_r[i];
                lane0_dist[0] = car_distance_r[i];
                found0 = 1'b1;
              end
            end
            if (!found0) begin
              lane0_len[0]  = 10'h0; // no car at lane0
              lane0_dist[0] = 10'h0;
            end
          end

          // Target lane (N-1)
          target_len[0]  = 10'h0;
          target_dist[0] = 10'h0;
          begin
            logic foundt;
            foundt = 1'b0;
            for (int i = 0; i < 5; i++) begin
              if (!foundt && i < M_r && car_lane_r[i] === target_lane_dist[0]) begin
                target_len[0]  = car_length_r[i];
                target_dist[0] = car_distance_r[i];
                foundt = 1'b1;
              end
            end
            if (!foundt) begin
              target_len[0]  = 10'h0;
              target_dist[0] = 10'h0;
            end
          end

          // Compute paths for this first pair (k=0)
          for (int p = 0; p < MAX_PATHS; p++) begin
            path_occupied[0][p] = 1'b0; // default (unused for k=0 for most p)
            min_q16[0][p] = 32'h0;
          end

          // Only p=0 corresponds to path [0, target] when considering first 'pair'
          // But we compute for all 6; only first computed now; others remain 0.
          begin
            // lane0: if no car present, treat len=0 (origin) for occupancy test
            logic occ0, occt;
            logic [9:0] near0, neart;
            near0 = lane0_dist[0];
            neart = target_dist[0];
            occ0  = (near0 >= R_r);
            occt  = (neart >= R_r);
            path_occupied[0][0] = occ0 || occt;
            if (path_occupied[0][0]) begin
              // Both edges beyond range -> unsafe segment
              min_q16[0][0] = 32'h0;
            end else begin
              // Occupied segments before R, minimum distance among near edges (scaled)
              logic [9:0] mindist;
              mindist = (near0 < neart) ? near0 : neart; // min of two near edges
              min_q16[0][0] = {mindist, {FRACBITS{1'b0}}}; // Q16.16 fixed-point
            end
            // Update accumulators with first path
            cur_impossible_next = 1'b0; // we have at least one path in this cycle
            cur_max_next = min_q16[0][0];
          end

          state_next = CALC_PATHS;
        end else begin
          // Hold pipeline reset when idle
          target_lane_dist[2] = 2'd0;
          target_lane_dist[1] = 2'd0;
          target_lane_dist[0] = 2'd0;
          target_dist[2] = 10'h0;
          target_dist[1] = 10'h0;
          target_dist[0] = 10'h0;
          target_len[2]  = 10'h0;
          target_len[1]  = 10'h0;
          target_len[0]  = 10'h0;
          lane0_dist[2] = 10'h0;
          lane0_dist[1] = 10'h0;
          lane0_dist[0] = 10'h0;
          lane0_len[2]  = 10'h0;
          lane0_len[1]  = 10'h0;
          lane0_len[0]  = 10'h0;
        end
      end

      CALC_PATHS: begin
        // Shift lane0/Target registers
        lane0_dist[2] = lane0_dist[1];
        lane0_dist[1] = lane0_dist[0];
        lane0_len[2]  = lane0_len[1];
        lane0_len[1]  = lane0_len[0];
        target_lane_dist[2] = target_lane_dist[1];
        target_lane_dist[1] = target_lane_dist[0];
        target_dist[2] = target_dist[1];
        target_dist[1] = target_dist[0];
        target_len[2]  = target_len[1];
        target_len[1]  = target_len[0];

        // Compute lane0 (always origin) - no car in origin lane for path segments (len=0, dist=0)
        lane0_dist[0] = 10'h0;
        lane0_len[0]  = 10'h0;

        // Determine next intermediate target lane: target_lane_dist[0] = target_lane_dist[1] + 1
        target_lane_dist[0] = target_lane_dist[1] + 2'd1;

        // Find car in this target lane if any
        target_len[0]  = 10'h0;
        target_dist[0] = 10'h0;
        begin
          logic foundt;
          foundt = 1'b0;
          for (int i = 0; i < 5; i++) begin
            if (!foundt && i < M_r && car_lane_r[i] === target_lane_dist[0]) begin
              target_len[0]  = car_length_r[i];
              target_dist[0] = car_distance_r[i];
              foundt = 1'b1;
            end
          end
          if (!foundt) begin
            target_len[0]  = 10'h0;
            target_dist[0] = 10'h0;
          end
        end

        // Compute occupancy and min distance for segment (prev_target -> new_target)
        // Map this to path index p = (k*3 + (target_lane_dist[1] - 1)) for k=1 here (second cycle)
        // At this point:
        //  - lane0 data is not relevant (origin lane0 used only for first segment in k=0)
        //  - We use prev target (target_dist[1], target_len[1]) and current target (target_dist[0], target_len[0])
        for (int p = 0; p < MAX_PATHS; p++) begin
          path_occupied[0][p] = 1'b0; // compute only meaningful ones; others remain 0
          min_q16[0][p] = 32'h0;
        end
        begin
          // Determine path index for this segment: k=1, so base = 3; p = 3 + (prev_target - 1) = 2 + prev_target
          int p_idx;
          p_idx = 2 + target_lane_dist[1];
          if (p_idx >= 0 && p_idx < MAX_PATHS) begin
            logic occ_prev, occ_cur;
            logic [9:0] near_prev, near_cur;
            near_prev = target_dist[1];
            near_cur  = target_dist[0];
            occ_prev  = (near_prev >= R_r);
            occ_cur   = (near_cur  >= R_r);
            path_occupied[0][p_idx] = occ_prev || occ_cur;
            if (path_occupied[0][p_idx]) begin
              min_q16[0][p_idx] = 32'h0;
            end else begin
              logic [9:0] mindist;
              mindist = (near_prev < near_cur) ? near_prev : near_cur;
              min_q16[0][p_idx] = {mindist, {FRACBITS{1'b0}}}; // Q16.16
            end
          end
        end

        // Prepare for next cycle: move current computations to stage 1, then go to FIND_MAX_MIN
        state_next = FIND_MAX_MIN;
      end

      FIND_MAX_MIN: begin
        // Move stage-0 results to stage-1 and also consider k=0 results
        // Combine results from previous cycles into min_q16_r1, then compute max/min
        for (int p = 0; p < MAX_PATHS; p++) begin
          min_q16_r1[p] = 32'h0;
        end
        // k=0: path index 0 (lane0->target lane N-1)
        if (path_occupied[0][0]) begin
          min_q16_r1[0] = 32'h0;
        end else begin
          min_q16_r1[0] = min_q16[0][0];
        end
        // k=1: path index 2 + target_lane (of prev target lane), which is target_lane_dist[1] at this cycle
        begin
          int p_idx;
          p_idx = 2 + target_lane_dist[1];
          if (p_idx >= 0 && p_idx < MAX_PATHS) begin
            if (path_occupied[0][p_idx]) begin
              min_q16_r1[p_idx] = 32'h0;
            end else begin
              min_q16_r1[p_idx] = min_q16[0][p_idx];
            end
          end
        end

        // Compute max of mins and track impossibility
        cur_max_next = 32'h0;
        cur_impossible_next = 1'b1; // becomes 0 if any path not fully occupied
        // Paths valid only up to N-2 for two-step transition (0 -> N-1 via intermediate)
        // We only have computed the two segments needed, so consider only indices < 2
        for (int p = 0; p < 2; p++) begin
          // Path is valid only if both lanes exist (we ensured by construction)
          // and it is not fully occupied; min_q16_r1[p] == 0 means either occupied or min distance 0
          if (min_q16_r1[p] != 32'h0) begin
            // valid path with positive min distance
            cur_impossible_next = 1'b0;
            cur_max_next = (min_q16_r1[p] > cur_max_next) ? min_q16_r1[p] : cur_max_next;
          end
        end
        // If cur_max_next is still 0, check if any min>0 exists; if not, remains impossible
        // Done is set in next cycle
        state_next = DONE;
      end

      DONE: begin
        // Hold outputs; return to IDLE on next cycle (latency = 3 cycles from start)
        state_next = IDLE;
      end

      default: state_next = IDLE;
    endcase
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      safety_factor <= 32'h0;
      impossible    <= 1'b0;
      done          <= 1'b0;
      cur_max       <= 32'h0;
      cur_impossible<= 1'b1;
      // Initialize pipeline/registers
      N_r <= 2'd0; M_r <= 3'd0; R_r <= 10'h0;
      for (int i=0;i<5;i++) begin
        car_lane_r[i]   <= 2'd0;
        car_length_r[i] <= 10'h0;
        car_distance_r[i]<=10'h0;
      end
      for (int i=0;i<3;i++) begin
        target_lane_dist[i] <= 2'd0;
        target_dist[i] <= 10'h0;
        target_len[i]  <= 10'h0;
        lane0_dist[i]  <= 10'h0;
        lane0_len[i]   <= 10'h0;
      end
      for (int k=0;k<2;k++) begin
        for (int p=0;p<MAX_PATHS;p++) begin
          path_occupied[k][p] <= 1'b0;
          min_q16[k][p] <= 32'h0;
        end
      end
      for (int p=0;p<MAX_PATHS;p++) begin
        min_q16_r1[p] <= 32'h0;
      end
    end else begin
      // Update accumulators from next-state logic
      cur_max       <= cur_max_next;
      cur_impossible<= cur_impossible_next;

      // Update done and results on cycle transitions
      if (state === FIND_MAX_MIN) begin
        done          <= 1'b0; // will be 1 in DONE cycle
        impossible    <= cur_impossible_next;
        safety_factor <= (cur_impossible_next ? 32'h0 : cur_max_next);
      end else if (state === DONE) begin
        done          <= 1'b1;
        impossible    <= cur_impossible;
        safety_factor <= (cur_impossible ? 32'h0 : cur_max);
      end else begin
        done          <= 1'b0;
        impossible    <= 1'b0;
        safety_factor <= 32'h0;
      end

      // Maintain pipeline/registers with current-state values
      // These are written in the combinational block appropriately per state.
      // Here we just keep the latest values stable.
    end
  end

endmodule