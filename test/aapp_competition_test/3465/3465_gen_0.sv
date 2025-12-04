module road_assignment(
  input              clk,
  input              rst_n,
  input              start,
  input       [2:0]  num_cities,
  input       [7:0][5:0] roads, // {city_a[2:0], city_b[2:0]}
  output reg  [7:0][5:0] assignments,
  output reg         done
);

  // Internal state machine
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_SEARCH    = 3'd2,
    S_BACKTRACK = 3'd3,
    S_DONE      = 3'd4,
    S_FAIL      = 3'd5
  } state_t;

  state_t state, next_state;

  // Latched inputs
  reg [2:0] num_cities_q;
  reg [7:0][5:0] roads_q;

  // Selection state
  reg [2:0] level;                    // current city index [0..num_cities_q-1]
  reg [2:0] used_cities_mask;         // bit i=1 if city i already assigned as building
  reg [7:0] used_roads_mask;          // bit r=1 if road r already used
  reg [2:0] sel_road   [7:0];         // selected road index per level
  reg       sel_flip   [7:0];         // 1 if using road with swapped endpoints at level

  // Helper wires
  wire [2:0] curr_city = level;

  // Functions to extract endpoints
  function automatic [2:0] get_a(input [5:0] r);
    get_a = r[5:3];
  endfunction

  function automatic [2:0] get_b(input [5:0] r);
    get_b = r[2:0];
  endfunction

  // Search for next candidate road for current level
  // We do simple linear scan each cycle from (previous selected+1) or from 0.
  reg  [2:0] prev_sel_road;
  reg        had_prev_sel;
  reg  [2:0] next_r_idx;
  reg        next_flip;
  reg        found_candidate;

  integer i;

  // Combinational search logic
  always @* begin
    // Determine starting index for search
    if (had_prev_sel)
      next_r_idx = prev_sel_road + 3'd1;
    else
      next_r_idx = 3'd0;

    found_candidate = 1'b0;
    next_flip       = 1'b0;

    // Scan through all 8 roads at most
    for (i = 0; i < 8; i = i + 1) begin
      if (!found_candidate) begin
        // Wrap index within [0..7]
        logic [2:0] idx;
        idx = (next_r_idx + i[2:0]) & 3'b111;

        // Only consider if road unused
        if (!used_roads_mask[idx]) begin
          logic [5:0] r;
          logic [2:0] a, b;
          r = roads_q[idx];
          a = get_a(r);
          b = get_b(r);

          // Candidate if either endpoint matches current city
          // and the building city (output[5:3]) is unused
          if (a == curr_city) begin
            if (!used_cities_mask[a]) begin
              found_candidate = 1'b1;
              next_r_idx     = idx;
              next_flip      = 1'b0; // keep as is: a becomes building
            end
          end else if (b == curr_city) begin
            if (!used_cities_mask[b]) begin
              found_candidate = 1'b1;
              next_r_idx     = idx;
              next_flip      = 1'b1; // swap so b becomes building
            end
          end
        end
      end
    end
  end

  // State machine next-state logic and control
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        // Move to search if num_cities in valid range, else FAIL
        if (num_cities_q >= 3'd2 && num_cities_q <= 3'd8)
          next_state = S_SEARCH;
        else
          next_state = S_FAIL;
      end

      S_SEARCH: begin
        // If all cities assigned, we are done
        if (level == num_cities_q)
          next_state = S_DONE;
        else begin
          // If candidate exists: stay in SEARCH to advance level
          // If no candidate: need to backtrack or fail
          if (found_candidate)
            next_state = S_SEARCH; // progression handled in seq always
          else
            next_state = S_BACKTRACK;
        end
      end

      S_BACKTRACK: begin
        // If no previous level to backtrack, fail
        if (level == 3'd0)
          next_state = S_FAIL;
        else begin
          // After undoing one level, go back to SEARCH to try next candidate
          next_state = S_SEARCH;
        end
      end

      S_DONE: begin
        // Stay DONE until new start or reset
        if (start)
          next_state = S_INIT;
      end

      S_FAIL: begin
        // On failure, signal done (no valid assignments). Restart on new start.
        if (start)
          next_state = S_INIT;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  integer k;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= S_IDLE;
      num_cities_q   <= 3'd0;
      roads_q        <= '0;
      level          <= 3'd0;
      used_cities_mask <= 3'd0;
      used_roads_mask  <= 8'd0;
      for (k = 0; k < 8; k = k + 1) begin
        sel_road[k] <= 3'd0;
        sel_flip[k] <= 1'b0;
      end
      assignments    <= '0;
      done           <= 1'b0;
      prev_sel_road  <= 3'd0;
      had_prev_sel   <= 1'b0;
    end else begin
      state <= next_state;
      done  <= 1'b0; // default, overridden in DONE/FAIL

      case (state)
        S_IDLE: begin
          if (start) begin
            // Latch inputs
            num_cities_q   <= num_cities;
            roads_q        <= roads;
            // Clear previous solution
            level          <= 3'd0;
            used_cities_mask <= 3'd0;
            used_roads_mask  <= 8'd0;
            for (k = 0; k < 8; k = k + 1) begin
              sel_road[k] <= 3'd0;
              sel_flip[k] <= 1'b0;
            end
            assignments    <= '0;
            prev_sel_road  <= 3'd0;
            had_prev_sel   <= 1'b0;
          end
        end

        S_INIT: begin
          // Reset tracking for new search
          level            <= 3'd0;
          used_cities_mask <= 3'd0;
          used_roads_mask  <= 8'd0;
          for (k = 0; k < 8; k = k + 1) begin
            sel_road[k] <= 3'd0;
            sel_flip[k] <= 1'b0;
          end
          prev_sel_road  <= 3'd0;
          had_prev_sel   <= 1'b0;
        end

        S_SEARCH: begin
          if (level == num_cities_q) begin
            // All assigned: move to DONE in next_state, nothing to change here
          end else begin
            // Determine previous selection at this level (if any)
            if (used_cities_mask[curr_city]) begin
              // city already had an assignment at this level (from prior try)
              had_prev_sel   <= 1'b1;
              prev_sel_road  <= sel_road[curr_city];
            end else begin
              had_prev_sel   <= 1'b0;
              prev_sel_road  <= 3'd0;
            end

            if (found_candidate) begin
              // Accept candidate
              sel_road[curr_city] <= next_r_idx;
              sel_flip[curr_city] <= next_flip;

              // Mark building city used (curr_city) and road used
              used_cities_mask[curr_city] <= 1'b1;
              used_roads_mask[next_r_idx] <= 1'b1;

              // Advance to next city
              level <= level + 3'd1;

              // Reset hints for next level
              had_prev_sel  <= 1'b0;
              prev_sel_road <= 3'd0;
            end else begin
              // No candidate found at this level, will backtrack in S_BACKTRACK
            end
          end
        end

        S_BACKTRACK: begin
          // Undo previous level assignment and prepare to search further
          if (level != 3'd0) begin
            // Step back one level
            level <= level - 3'd1;

            // Identify the level we are reverting
            // Because level has old value in this cycle, use (level-1)
            logic [2:0] back_level;
            back_level = level - 3'd1;

            // Clear used masks corresponding to reverted choice
            used_cities_mask[back_level] <= 1'b0;
            used_roads_mask[ sel_road[back_level] ] <= 1'b0;

            // Setup to continue search at that back_level with next road index
            had_prev_sel  <= 1'b1;
            prev_sel_road <= sel_road[back_level];
          end
        end

        S_DONE: begin
          // Build assignments output based on selected roads
          // Only for num_cities_q entries; others set to zero
          for (k = 0; k < 8; k = k + 1) begin
            if (k < num_cities_q) begin
              logic [5:0] r;
              r = roads_q[sel_road[k]];
              if (sel_flip[k]) begin
                // Swap endpoints so city k is at [5:3]
                assignments[k][5:3] <= r[2:0];
                assignments[k][2:0] <= r[5:3];
              end else begin
                assignments[k] <= r;
              end
            end else begin
              assignments[k] <= 6'd0;
            end
          end
          done <= 1'b1;
        end

        S_FAIL: begin
          // No valid assignment found; output zeros and assert done
          assignments <= '0;
          done        <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

endmodule