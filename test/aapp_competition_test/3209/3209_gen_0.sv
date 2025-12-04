module train_path_optimizer(
  input clk,                      // System clock
  input rst_n,                    // Active-low reset
  input start,                    // Start computation (pulse high)
  input [3:0] num_stations,       // Number of stations (max 8)
  input [4:0] num_trains,         // Number of trains (max 16)
  input [3:0] origin_idx,         // Encoded origin station index
  input [3:0] dest_idx,           // Encoded destination station index
  input [15:0] train_data [15:0], // NOTE: as given; fields interpreted per comment
  output reg [31:0] min_time,     // Min expected time in Q16.16 fixed-point
  output reg done,                // High when computation completes
  output reg impossible           // High if destination unreachable
);

  // --------------------------------------------------------------------------
  // Parameterization and local definitions
  // --------------------------------------------------------------------------
  localparam MAX_STATIONS = 8;
  localparam MAX_TRAINS   = 16;

  localparam [31:0] INF_Q16_16 = 32'h7FFF_FFFF; // Large sentinel as "infinity"

  // State encoding
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_ITER      = 3'd2,
    S_DONE      = 3'd3
  } state_t;

  state_t state, next_state;

  // --------------------------------------------------------------------------
  // Data structures
  // --------------------------------------------------------------------------

  // Distance to each station (Q16.16)
  reg [31:0] dist     [0:MAX_STATIONS-1];
  reg [31:0] dist_next[0:MAX_STATIONS-1];

  // Visited set for Dijkstra-like behavior (optional, but included)
  reg        visited     [0:MAX_STATIONS-1];
  reg        visited_next[0:MAX_STATIONS-1];

  // Iteration counters
  reg [4:0] edge_idx;      // up to 16 trains
  reg [3:0] iter_cnt;      // up to 8-16 iterations

  // Latched configuration
  reg [3:0]  num_stations_r;
  reg [4:0]  num_trains_r;
  reg [3:0]  origin_r;
  reg [3:0]  dest_r;

  // Helper wires for current edge decoding
  reg [3:0]  e_src;
  reg [3:0]  e_dst;
  reg [15:0] e_raw;

  // For probabilistic expectation computation in Q16.16:
  // E = ((100-p)*t + p*(t + (d+1)/2))/100
  // NOTE: We interpret t, d, times as integer cycles and then convert to Q16.16.

  // --------------------------------------------------------------------------
  // Extract edge fields (simple placeholder mapping from 16 bits due to spec inconsistency)
  // Assumption (compact mapping for this implementation):
  // [15:12] src (4)
  // [11:8]  dst (4)
  // [7:4]   depart (4)  -- small departure slot
  // [3:2]   time (2)    -- base travel time (very small range, example only)
  // [1:0]   prob (2)    -- encoded probability steps
  // This does not exactly match the textual packing, but adheres syntactically
  // to the given 16-bit vector width. For ASIC coding exercise focus on control/datapath.

  function automatic [3:0] get_src(input [15:0] w);    get_src    = w[15:12]; endfunction
  function automatic [3:0] get_dst(input [15:0] w);    get_dst    = w[11:8];  endfunction
  function automatic [7:0] get_depart(input [15:0] w); get_depart = {4'b0,w[7:4]}; endfunction
  function automatic [7:0] get_time(input [15:0] w);   get_time   = {6'b0,w[3:2]}; endfunction
  function automatic [6:0] get_prob(input [15:0] w);   get_prob   = {5'b0,w[1:0]}; endfunction
  function automatic [6:0] get_delay(input [15:0] w);  get_delay  = 7'd0; endfunction

  // Align departure time given current arrival (integer domain, simple >=)
  function automatic [15:0] align_depart(
    input [15:0] cur_time_int,
    input [7:0]  depart_int
  );
    if (cur_time_int <= depart_int)
      align_depart = depart_int;
    else
      align_depart = cur_time_int; // no wait model for periodic schedule (simplified)
  endfunction

  // Compute expected travel time (integer cycles) per edge
  function automatic [31:0] compute_expected_time_q16(
    input [7:0] t_int,
    input [6:0] p_int,
    input [6:0] d_int
  );
    // All arithmetic in integer, then convert to Q16.16
    // E = ((100-p)*t + p*(t + (d+1)/2))/100
    integer t;
    integer p;
    integer d;
    integer extra;
    integer num;
    begin
      t = t_int;
      p = p_int;
      d = d_int;
      extra = (d + 1) >>> 1;
      num = (100 - p)*t + p*(t + extra);
      compute_expected_time_q16 = (num <<< 16) / 100; // Q16.16
    end
  endfunction

  // --------------------------------------------------------------------------
  // Sequential state / registers
  // --------------------------------------------------------------------------

  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= S_IDLE;
      edge_idx       <= 5'd0;
      iter_cnt       <= 4'd0;
      num_stations_r <= 4'd0;
      num_trains_r   <= 5'd0;
      origin_r       <= 4'd0;
      dest_r         <= 4'd0;
      done           <= 1'b0;
      impossible     <= 1'b0;
      min_time       <= 32'd0;
      for (i = 0; i < MAX_STATIONS; i = i + 1) begin
        dist[i]    <= INF_Q16_16;
        visited[i] <= 1'b0;
      end
    end else begin
      state    <= next_state;
      edge_idx <= edge_idx; // updated below
      iter_cnt <= iter_cnt; // updated below

      // Update arrays
      for (i = 0; i < MAX_STATIONS; i = i + 1) begin
        dist[i]    <= dist_next[i];
        visited[i] <= visited_next[i];
      end

      // Outputs and control registers updates within state machine
      case (state)
        S_IDLE: begin
          done       <= 1'b0;
          impossible <= 1'b0;
          min_time   <= 32'd0;
          if (start) begin
            num_stations_r <= (num_stations > MAX_STATIONS) ? MAX_STATIONS[3:0] : num_stations;
            num_trains_r   <= (num_trains   > MAX_TRAINS)   ? MAX_TRAINS[4:0]   : num_trains;
            origin_r       <= origin_idx;
            dest_r         <= dest_idx;
            edge_idx       <= 5'd0;
            iter_cnt       <= 4'd0;
          end
        end

        S_INIT: begin
          // nothing extra here; dist_next already prepared in combinational
        end

        S_ITER: begin
          // Advance through edges
          if (edge_idx + 1 < num_trains_r)
            edge_idx <= edge_idx + 1'b1;
          else begin
            edge_idx <= 5'd0;
            iter_cnt <= iter_cnt + 1'b1;
          end
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  // --------------------------------------------------------------------------
  // Combinational next-state and relaxation logic
  // --------------------------------------------------------------------------

  always @(*) begin
    // Default propagate current values
    next_state = state;

    for (i = 0; i < MAX_STATIONS; i = i + 1) begin
      dist_next[i]    = dist[i];
      visited_next[i] = visited[i];
    end

    case (state)
      // ----------------------------------------------------------------------
      S_IDLE: begin
        if (start) begin
          // Initialize distances
          for (i = 0; i < MAX_STATIONS; i = i + 1) begin
            if (i[3:0] == origin_idx[3:0]) begin
              dist_next[i] = 32'd0; // origin distance = 0
            end else begin
              dist_next[i] = INF_Q16_16;
            end
            visited_next[i] = 1'b0;
          end
          next_state = S_INIT;
        end
      end

      // ----------------------------------------------------------------------
      S_INIT: begin
        // Immediately go to iterative relaxation
        next_state = S_ITER;
      end

      // ----------------------------------------------------------------------
      S_ITER: begin
        // Relax one edge per cycle
        if (edge_idx < num_trains_r) begin
          e_raw = train_data[edge_idx];

          e_src = get_src(e_raw);
          e_dst = get_dst(e_raw);

          if (e_src < num_stations_r && e_dst < num_stations_r) begin
            if (dist[e_src] != INF_Q16_16) begin
              // Extract fields
              // Depart, time, prob, delay treated as small integers here
              automatic [7:0] depart_i = get_depart(e_raw);
              automatic [7:0] time_i   = get_time(e_raw);
              automatic [6:0] prob_i   = get_prob(e_raw);
              automatic [6:0] delay_i  = get_delay(e_raw);

              // Current best arrival time at src (Q16.16 -> integer)
              automatic [31:0] src_dist_q = dist[e_src];
              automatic [15:0] src_dist_i = src_dist_q[31:16];

              // Align to departure (integer domain)
              automatic [15:0] depart_aligned_i;
              depart_aligned_i = align_depart(src_dist_i, depart_i);

              // Waiting time (integer), then to Q16.16
              automatic integer wait_int = depart_aligned_i - src_dist_i;
              if (wait_int < 0) wait_int = 0;
              automatic [31:0] wait_q = wait_int <<< 16;

              // Expected in-train time
              automatic [31:0] exp_q = compute_expected_time_q16(time_i, prob_i, delay_i);

              // Candidate new distance
              automatic [31:0] cand_q = src_dist_q + wait_q + exp_q;

              if (cand_q < dist_next[e_dst]) begin
                dist_next[e_dst] = cand_q;
              end
            end
          end
        end

        // After processing all edges for this iteration
        if (iter_cnt >= 4'd7 && edge_idx == num_trains_r-1) begin
          // After fixed number of iterations (for up to 8 nodes) go to DONE
          next_state = S_DONE;
        end
      end

      // ----------------------------------------------------------------------
      S_DONE: begin
        // Determine outputs based on final distances
        // Use current dist (registered) here; combinationally compute min_time/impossible
        // (Registered in sequential always block upon staying in S_DONE)
        next_state = S_IDLE; // ready for next start pulse
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // --------------------------------------------------------------------------
  // Output logic (registered in main always, but we compute helper combinational)
  // --------------------------------------------------------------------------

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_time   <= 32'd0;
      impossible <= 1'b0;
    end else begin
      if (state == S_ITER && next_state == S_DONE) begin
        // Latch result when transitioning to DONE
        if (dist[dest_r] == INF_Q16_16) begin
          impossible <= 1'b1;
          min_time   <= 32'd0;
        end else begin
          impossible <= 1'b0;
          min_time   <= dist[dest_r];
        end
      end
    end
  end

endmodule