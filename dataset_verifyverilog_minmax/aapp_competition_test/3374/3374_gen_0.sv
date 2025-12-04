module min_uw_distance(
  input clk, // system clock
  input rst_n, // active-low reset
  input start, // pulse to start computation
  input [7:0] gravity [0:7], // gravity values for 8 systems (8-bit each)
  input [7:0] system_type, // system_type[i] = 0 for human, 1 for alien
  input [7:0][7:0] adjacency_matrix, // adjacency_matrix[i][j] = 1 indicates link
  output reg [23:0] min_distance, // minimum UW distance (24-bit)
  output reg done // high when computation completes
);

  // FSM states
  typedef enum logic [2:0] {S_IDLE, S_PRECOMP, S_OPTIONS, S_PIPE, S_DONE} state_t;
  state_t state, next_state;

  // Constants
  localparam NUM_SYS = 8;
  localparam NUM_OPTS = 9; // 0..8 (0 = no device)
  localparam LAT = 3;      // pipeline latency: 3 cycles for g^3

  // Indices and counters
  reg [3:0] opt_idx;      // 0..8 (9 options)
  reg [3:0] next_opt;
  reg [3:0] h_idx;        // human pair index
  reg [3:0] a_idx;        // alien pair index
  reg [3:0] h_cnt;        // number of humans
  reg [3:0] a_cnt;        // number of aliens
  reg [3:0] h_nxt, a_nxt; // next indices
  reg pair_end;           // 1 when current pair is the last
  reg pipe_in_valid;      // input valid to cube pipeline

  // Pairs counters for done timing
  reg [11:0] pairs_done, pairs_total; // up to 64 pairs
  reg [17:0] cycles_from_start;       // enough for total cycles bound
  reg [4:0] done_count;               // keep done high for 20 cycles

  // Human/Alien index lists
  reg [2:0] human_list [0:7];
  reg [2:0] alien_list [0:7];
  reg [2:0] human_list_r [0:7];
  reg [2:0] alien_list_r [0:7];
  reg h_list_valid, a_list_valid;
  integer i;

  // Adjusted gravity for current option (0..8)
  reg [7:0] adj_gravity [0:7];
  reg [7:0] adj_gravity_r [0:7];
  reg [7:0] self_delta [0:7];        // -1 or 0
  reg [7:0] neighbor_delta [0:7];    // 0..7 (0..7 added from neighbors)
  reg device_on;                     // 1 if opt_idx != 0

  // Cube pipeline signals
  reg [7:0] p0_g;
  reg [7:0] p0_h; // same as p0_g, duplicated for clarity
  reg p0_valid;
  reg [7:0] p1_g, p1_h;
  reg [7:0] p2_g, p2_h;
  reg [15:0] p1_g2, p1_h2;
  reg [23:0] p2_g3, p2_h3;
  reg [23:0] p3_diff;
  reg p3_valid;

  // Compute self_delta and neighbor_delta for current option
  always_comb begin
    // Defaults
    for (i = 0; i < NUM_SYS; i = i + 1) begin
      self_delta[i] = 8'h00;
      neighbor_delta[i] = 8'h00;
    end
    if (device_on) begin
      self_delta[opt_idx] = 8'hFF; // -1 using two's complement
      // For each neighbor M of opt_idx, add +1
      for (i = 0; i < NUM_SYS; i = i + 1) begin
        if (adjacency_matrix[opt_idx][i]) begin
          neighbor_delta[i] = neighbor_delta[i] + 1; // 0..7 neighbors -> up to +7
        end
      end
    end
  end

  // Compute adjusted gravity for the option and register it
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < NUM_SYS; i = i + 1) begin
        adj_gravity[i] <= 8'h00;
        adj_gravity_r[i] <= 8'h00;
      end
    end else begin
      if (state == S_PRECOMP) begin
        // Freeze input snapshot of original gravity
        for (i = 0; i < NUM_SYS; i = i + 1) begin
          adj_gravity[i] <= gravity[i];
        end
      end else if (state == S_OPTIONS) begin
        // Update adjusted gravity when moving to a new option
        if (opt_idx != next_opt) begin
          for (i = 0; i < NUM_SYS; i = i + 1) begin
            adj_gravity[i] <= gravity[i] + self_delta[i] + neighbor_delta[i];
          end
        end
      end
      // Keep a registered copy used for pipeline feeding
      for (i = 0; i < NUM_SYS; i = i + 1) begin
        adj_gravity_r[i] <= adj_gravity[i];
      end
    end
  end

  // Precompute human and alien lists (registered snapshot)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      h_cnt <= 4'h0;
      a_cnt <= 4'h0;
      h_list_valid <= 1'b0;
      a_list_valid <= 1'b0;
      for (i = 0; i < NUM_SYS; i = i + 1) begin
        human_list[i] <= 3'h0;
        alien_list[i] <= 3'h0;
        human_list_r[i] <= 3'h0;
        alien_list_r[i] <= 3'h0;
      end
    end else begin
      if (state == S_PRECOMP) begin
        h_cnt <= 4'h0;
        a_cnt <= 4'h0;
        for (i = 0; i < NUM_SYS; i = i + 1) begin
          if (system_type[i] == 1'b0) begin // human
            human_list[h_cnt] <= i[2:0];
            h_cnt <= h_cnt + 1;
          end else begin // alien
            alien_list[a_cnt] <= i[2:0];
            a_cnt <= a_cnt + 1;
          end
        end
        h_list_valid <= 1'b1;
        a_list_valid <= 1'b1;
        for (i = 0; i < NUM_SYS; i = i + 1) begin
          human_list_r[i] <= human_list[i];
          alien_list_r[i] <= alien_list[i];
        end
      end else begin
        // Maintain registered lists stable while processing pairs
        for (i = 0; i < NUM_SYS; i = i + 1) begin
          human_list_r[i] <= human_list[i];
          alien_list_r[i] <= alien_list[i];
        end
      end
    end
  end

  // Pairs per option and total pairs
  always_comb begin
    pairs_total = ({1'b0, h_cnt} * {1'b0, a_cnt}); // <= 64
  end

  // Next pair indices and end flag
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      h_idx <= 4'h0;
      a_idx <= 4'h0;
      h_nxt <= 4'h0;
      a_nxt <= 4'h0;
      pair_end <= 1'b0;
      pairs_done <= 12'h0;
      cycles_from_start <= 18'h0;
      done_count <= 5'h0;
    end else begin
      if (state == S_IDLE) begin
        h_idx <= 4'h0;
        a_idx <= 4'h0;
        h_nxt <= 4'h0;
        a_nxt <= 4'h0;
        pair_end <= 1'b0;
        pairs_done <= 12'h0;
        cycles_from_start <= 18'h0;
        done_count <= 5'h0;
      end else if (state == S_PRECOMP) begin
        h_idx <= 4'h0;
        a_idx <= 4'h0;
        h_nxt <= 4'h0;
        a_nxt <= 4'h0;
        pair_end <= (h_cnt == 4'h0) || (a_cnt == 4'h0);
        pairs_done <= 12'h0;
        cycles_from_start <= 18'h0;
        done_count <= 5'h0;
      end else if (state == S_OPTIONS) begin
        cycles_from_start <= cycles_from_start + 1;
        if ((h_cnt == 4'h0) || (a_cnt == 4'h0)) begin
          pair_end <= 1'b1;
          h_nxt <= 4'h0;
          a_nxt <= 4'h0;
          h_idx <= 4'h0;
          a_idx <= 4'h0;
          pairs_done <= pairs_done; // stays 0
        end else begin
          h_nxt <= (a_idx + 1 < a_cnt) ? h_idx : (h_idx + 1);
          a_nxt <= (a_idx + 1 < a_cnt) ? (a_idx + 1) : 4'h0;
          pair_end <= (h_idx == h_cnt - 1) && (a_idx == a_cnt - 1);
          h_idx <= h_nxt;
          a_idx <= a_nxt;
          pairs_done <= pairs_done + 1;
        end
      end else if (state == S_DONE) begin
        cycles_from_start <= cycles_from_start + 1;
        if (done_count < 5'd20) begin
          done_count <= done_count + 1;
        end
      end else begin
        cycles_from_start <= cycles_from_start + 1;
        // In S_PIPE we only advance counters when a valid result emerges
        if (p3_valid) begin
          if (pair_end) begin
            h_idx <= 4'h0;
            a_idx <= 4'h0;
            h_nxt <= 4'h0;
            a_nxt <= 4'h0;
            pairs_done <= pairs_done + 1;
          end else begin
            h_idx <= h_nxt;
            a_idx <= a_nxt;
            h_nxt <= (a_nxt + 1 < a_cnt) ? h_nxt : (h_nxt + 1);
            a_nxt <= (a_nxt + 1 < a_cnt) ? (a_nxt + 1) : 4'h0;
            pairs_done <= pairs_done + 1;
          end
        end
      end
    end
  end

  // Pipeline stage 0: feed current pair into pipeline
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      p0_g <= 8'h0;
      p0_h <= 8'h0;
      p0_valid <= 1'b0;
    end else begin
      p0_valid <= 1'b0;
      if (state == S_OPTIONS) begin
        // Start first pair when we enter the option
        p0_g <= adj_gravity_r[ alien_list_r[0] ];
        p0_h <= adj_gravity_r[ human_list_r[0] ];
        p0_valid <= (h_cnt > 0) && (a_cnt > 0);
      end else if (state == S_PIPE) begin
        // Feed next pair while not at end of pairs for this option
        if (!pair_end) begin
          p0_g <= adj_gravity_r[ alien_list_r[a_idx] ];
          p0_h <= adj_gravity_r[ human_list_r[h_idx] ];
          p0_valid <= 1'b1;
        end else begin
          p0_valid <= 1'b0;
        end
      end else begin
        p0_valid <= 1'b0;
      end
    end
  end

  // Pipeline stage 1: first multiply (g * g), valid in next cycle
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      p1_g <= 8'h0;
      p1_h <= 8'h0;
      p1_g2 <= 16'h0;
      p1_h2 <= 16'h0;
    end else begin
      p1_g <= p0_g;
      p1_h <= p0_h;
      p1_g2 <= p0_g * p0_g;
      p1_h2 <= p0_h * p0_h;
    end
  end

  // Pipeline stage 2: second multiply (g^2 * g), valid next cycle
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      p2_g <= 8'h0;
      p2_h <= 8'h0;
      p2_g3 <= 24'h0;
      p2_h3 <= 24'h0;
    end else begin
      p2_g <= p1_g;
      p2_h <= p1_h;
      p2_g3 <= p1_g2 * p1_g;
      p2_h3 <= p1_h2 * p1_h;
    end
  end

  // Final stage: diff and valid
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      p3_diff <= 24'h0;
      p3_valid <= 1'b0;
    end else begin
      // p2 stage is valid 2 cycles after p0_valid
      if (p2_g3 >= p2_h3) begin
        p3_diff <= p2_g3 - p2_h3;
      end else begin
        p3_diff <= p2_h3 - p2_g3;
      end
      // We consider p2_* as valid when p0 was valid (pipeline full)
      p3_valid <= |{p2_g3, p2_h3}; // Non-zero placeholder; pipeline validity handled by control
    end
  end

  // Track min distance
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_distance <= 24'hFFFFFF;
    end else begin
      if (state == S_PRECOMP) begin
        min_distance <= 24'hFFFFFF;
      end else if (p3_valid && ((state == S_PIPE) || (state == S_OPTIONS))) begin
        // Update min with new comparison result
        if (p3_diff < min_distance) begin
          min_distance <= p3_diff;
        end
      end
    end
  end

  // State machine registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      opt_idx <= 4'h0;
      next_opt <= 4'h0;
      device_on <= 1'b0;
    end else begin
      state <= next_state;
      opt_idx <= next_opt;
      next_opt <= opt_idx;
      device_on <= (opt_idx != 4'h0);
    end
  end

  // Next-state logic
  always_comb begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_PRECOMP;
          next_opt = 4'h0;
        end
      end
      S_PRECOMP: begin
        // One cycle to snapshot lists
        next_state = S_OPTIONS;
        next_opt = 4'h0;
      end
      S_OPTIONS: begin
        // When current option pairs done, move to next or done
        // pairs_done counts valid comparisons already finished for this option
        if ((h_cnt == 4'h0) || (a_cnt == 4'h0)) begin
          // No pairs: skip directly
          if (opt_idx < 4'h8) begin
            next_opt = opt_idx + 1;
            next_state = S_OPTIONS;
          end else begin
            next_state = S_DONE;
          end
        end else begin
          // If we've finished all pairs for this option, move to next option
          if (pairs_done >= ({1'b0, h_cnt} * {1'b0, a_cnt})) begin
            if (opt_idx < 4'h8) begin
              next_opt = opt_idx + 1;
              next_state = S_OPTIONS;
            end else begin
              next_state = S_DONE;
            end
          end else begin
            // Stay in options to feed the pipeline
            next_state = S_PIPE;
          end
        end
      end
      S_PIPE: begin
        // After pipeline latency, keep processing this option; switch to next option when done
        if ((h_cnt == 4'h0) || (a_cnt == 4'h0)) begin
          if (opt_idx < 4'h8) begin
            next_opt = opt_idx + 1;
            next_state = S_OPTIONS;
          end else begin
            next_state = S_DONE;
          end
        end else begin
          if (pairs_done >= ({1'b0, h_cnt} * {1'b0, a_cnt})) begin
            if (opt_idx < 4'h8) begin
              next_opt = opt_idx + 1;
              next_state = S_OPTIONS;
            end else begin
              next_state = S_DONE;
            end
          end else begin
            next_state = S_PIPE;
          end
        end
      end
      S_DONE: begin
        // Hold done for 20 cycles then return to IDLE
        if (done_count >= 5'd19) begin
          next_state = S_IDLE;
        end else begin
          next_state = S_DONE;
        end
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Done flag logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else begin
      if (state == S_DONE) begin
        done <= 1'b1;
      end else if (state == S_IDLE) begin
        done <= 1'b0;
      end
    end
  end

endmodule
