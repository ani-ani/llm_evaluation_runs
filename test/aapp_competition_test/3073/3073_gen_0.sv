module knight_pathfinder(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [7:0] num_cards, // number of tarot cards (1-256)
  input [15:0] card_data [0:255][0:4], // [r, c, a, b, p]
  output reg [15:0] min_cost, // minimal cost (0xFFFF if impossible)
  output reg done // high when computation completes
);

  // --------------------------------------------------------------------------
  // Local parameters and type definitions
  // --------------------------------------------------------------------------

  // State encoding for main FSM
  localparam [2:0]
    S_IDLE   = 3'd0,
    S_INIT   = 3'd1,
    S_SELECT = 3'd2,
    S_RELAX  = 3'd3,
    S_CHECK  = 3'd4,
    S_DONE   = 3'd5;

  // Maximum number of nodes in our search space.
  // For simplicity/tractability, we model at most 256 distinct positions.
  localparam int MAX_NODES = 256;

  // Large cost used as infinity (greater than any realistic path here)
  localparam [15:0] INF_COST = 16'hFFFF;

  // Node record fields:
  // - pos_r, pos_c: 16-bit signed position
  // - dist: best-known distance
  // - visited: whether finalized in Dijkstra

  // --------------------------------------------------------------------------
  // Internal storage
  // --------------------------------------------------------------------------

  // Positions for nodes
  reg signed [15:0] node_r [0:MAX_NODES-1];
  reg signed [15:0] node_c [0:MAX_NODES-1];

  // Best known costs
  reg [15:0] dist [0:MAX_NODES-1];

  // Visited flags
  reg visited [0:MAX_NODES-1];

  // Track how many nodes are actually used
  reg [7:0] node_count;

  // Index of current node being processed (u in Dijkstra)
  reg [7:0] cur_idx;
  reg [15:0] cur_dist;
  reg signed [15:0] cur_r;
  reg signed [15:0] cur_c;

  // Iterator indices
  reg [7:0] scan_idx;    // for selecting min dist unvisited node
  reg [7:0] relax_idx;   // for exploring neighbors

  // Min search temporaries
  reg [15:0] best_scan_dist;
  reg [7:0]  best_scan_idx;
  reg        found_unvisited;

  // FSM state
  reg [2:0] state, next_state;

  // Control for staged operations
  reg scan_done;
  reg relax_done;

  // Result tracking
  reg [15:0] best_goal_cost;

  // Start pulse sync / latch
  reg start_d;
  wire start_pulse = start & ~start_d;

  // --------------------------------------------------------------------------
  // Start pulse register
  // --------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end

  // --------------------------------------------------------------------------
  // FSM sequential
  // --------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= S_IDLE;
      done           <= 1'b0;
      min_cost       <= INF_COST;
      node_count     <= 8'd0;
      cur_idx        <= 8'd0;
      cur_dist       <= INF_COST;
      cur_r          <= 16'sd0;
      cur_c          <= 16'sd0;
      scan_idx       <= 8'd0;
      relax_idx      <= 8'd0;
      best_scan_dist <= INF_COST;
      best_scan_idx  <= 8'd0;
      found_unvisited<= 1'b0;
      scan_done      <= 1'b0;
      relax_done     <= 1'b0;
      best_goal_cost <= INF_COST;
    end else begin
      state <= next_state;

      case (state)
        // ------------------------------------------------------
        // IDLE: wait for start
        // ------------------------------------------------------
        S_IDLE: begin
          done           <= 1'b0;
          min_cost       <= INF_COST;
          best_goal_cost <= INF_COST;
          if (start_pulse) begin
            // Initialize on next states in S_INIT
            // (combinational part sets next_state)
          end
        end

        // ------------------------------------------------------
        // INIT: set up node list, distances, visited flags
        // Node 0 is start; initially only that node is defined.
        // ------------------------------------------------------
        S_INIT: begin
          // Initialize all nodes to INF and unvisited once at entry
          // We rely on a simple one-cycle bulk init using for-generate style
          // (synth tools may implement as loops/unrolled)
          integer i;
          for (i = 0; i < MAX_NODES; i = i + 1) begin
            node_r[i]  <= 16'sd0;
            node_c[i]  <= 16'sd0;
            dist[i]    <= INF_COST;
            visited[i] <= 1'b0;
          end

          // Start node from card 0 position
          node_r[0]      <= card_data[0][0];
          node_c[0]      <= card_data[0][1];
          dist[0]        <= 16'd0; // cost 0 at start
          node_count     <= 8'd1;

          // Reset helper variables
          scan_idx       <= 8'd0;
          relax_idx      <= 8'd0;
          best_scan_dist <= INF_COST;
          best_scan_idx  <= 8'd0;
          found_unvisited<= 1'b0;
          scan_done      <= 1'b0;
          relax_done     <= 1'b0;
          best_goal_cost <= INF_COST;
        end

        // ------------------------------------------------------
        // SELECT: multi-cycle linear search for min dist unvisited
        // ------------------------------------------------------
        S_SELECT: begin
          if (!scan_done) begin
            if (scan_idx == 8'd0) begin
              best_scan_dist  <= INF_COST;
              best_scan_idx   <= 8'd0;
              found_unvisited <= 1'b0;
            end

            if (scan_idx < node_count) begin
              if (!visited[scan_idx] && (dist[scan_idx] < best_scan_dist)) begin
                best_scan_dist  <= dist[scan_idx];
                best_scan_idx   <= scan_idx;
                found_unvisited <= 1'b1;
              end
              scan_idx <= scan_idx + 8'd1;
            end else begin
              scan_done <= 1'b1;
            end
          end

          if (scan_done) begin
            if (found_unvisited) begin
              cur_idx  <= best_scan_idx;
              cur_dist <= best_scan_dist;
              cur_r    <= node_r[best_scan_idx];
              cur_c    <= node_c[best_scan_idx];

              // Mark visited in next cycle (RELAX state)
              relax_idx  <= 8'd0;
              relax_done <= 1'b0;
            end
          end
        end

        // ------------------------------------------------------
        // RELAX: explore neighbors using all cards.
        // For this simplified model:
        // - Each card defines a possible "knight-like" displacement (a,b)
        // - From (cur_r,cur_c) we can move to (cur_r +/- a, cur_c +/- b)
        //   and (cur_r +/- b, cur_c +/- a), four directions if non-zero.
        // - Each move cost is p (card_data[i][4]).
        // - We create/find nodes for destinations (up to MAX_NODES).
        // ------------------------------------------------------
        S_RELAX: begin
          // Mark this node visited once at entry
          if (relax_idx == 8'd0) begin
            visited[cur_idx] <= 1'b1;
          end

          if (!relax_done) begin
            if (relax_idx < num_cards) begin
              // Extract card parameters
              reg signed [15:0] a;
              reg signed [15:0] b;
              reg [15:0]       p;
              reg signed [15:0] nr0, nc0;
              reg signed [15:0] nr1, nc1;
              reg signed [15:0] nr2, nc2;
              reg signed [15:0] nr3, nc3;

              a = card_data[relax_idx][2];
              b = card_data[relax_idx][3];
              p = card_data[relax_idx][4];

              // Generate up to 4 knight-style moves (sign-combined)
              nr0 = cur_r + a;
              nc0 = cur_c + b;
              nr1 = cur_r + a;
              nc1 = cur_c - b;
              nr2 = cur_r - a;
              nc2 = cur_c + b;
              nr3 = cur_r - a;
              nc3 = cur_c - b;

              // We handle each destination sequentially in this same cycle
              // using tasks-like inlined logic via local procedures.
              // To ensure synthesizability, we code them explicitly.

              // Helper: process a single neighbor
              automatic void process_neighbor(input signed [15:0] nr, input signed [15:0] nc);
                integer k;
                reg [7:0] found_idx;
                reg found;
                reg [15:0] new_cost;
              begin
                // Bound check for coordinate range is implicit (16-bit signed)

                // Search if position already exists
                found    = 1'b0;
                found_idx= 8'd0;
                for (k = 0; k < node_count; k = k + 1) begin
                  if (!found && node_r[k] == nr && node_c[k] == nc) begin
                    found     = 1'b1;
                    found_idx = k[7:0];
                  end
                end

                new_cost = cur_dist + p;

                if (found) begin
                  if (!visited[found_idx] && new_cost < dist[found_idx]) begin
                    dist[found_idx] <= new_cost;
                  end
                end else begin
                  if (node_count < MAX_NODES) begin
                    node_r[node_count]  <= nr;
                    node_c[node_count]  <= nc;
                    dist[node_count]    <= new_cost;
                    visited[node_count] <= 1'b0;
                    node_count          <= node_count + 8'd1;
                  end
                end
              end
              endtask

              // Apply neighbors
              process_neighbor(nr0, nc0);
              process_neighbor(nr1, nc1);
              process_neighbor(nr2, nc2);
              process_neighbor(nr3, nc3);

              relax_idx <= relax_idx + 8'd1;
            end else begin
              relax_done <= 1'b1;
            end
          end
        end

        // ------------------------------------------------------
        // CHECK: if any node at (0,0) has better cost, store it.
        // Then either loop (SELECT) or finish (DONE) if no more.
        // ------------------------------------------------------
        S_CHECK: begin
          integer j;
          // Update best_goal_cost by scanning all nodes once
          // (simple implementation; could be incremental)
          best_goal_cost <= best_goal_cost; // hold
          for (j = 0; j < node_count; j = j + 1) begin
            if (node_r[j] == 16'sd0 && node_c[j] == 16'sd0) begin
              if (dist[j] < best_goal_cost)
                best_goal_cost <= dist[j];
            end
          end

          // Reset scan for next SELECT
          scan_idx       <= 8'd0;
          scan_done      <= 1'b0;
          best_scan_dist <= INF_COST;
          best_scan_idx  <= 8'd0;
          found_unvisited<= 1'b0;
        end

        // ------------------------------------------------------
        // DONE: latch result; wait for next start
        // ------------------------------------------------------
        S_DONE: begin
          done     <= 1'b1;
          min_cost <= (best_goal_cost == INF_COST) ? INF_COST : best_goal_cost;
          // Stay here until a new start pulse; combinational logic
          // will move us back to INIT when detected.
        end

        default: begin
          // Safe defaults
        end
      endcase
    end
  end

  // --------------------------------------------------------------------------
  // FSM combinational next-state logic
  // --------------------------------------------------------------------------
  always @* begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start_pulse)
          next_state = S_INIT;
      end

      S_INIT: begin
        // Move to first SELECT step after initialization
        next_state = S_SELECT;
      end

      S_SELECT: begin
        if (scan_done) begin
          if (found_unvisited)
            next_state = S_RELAX;
          else
            next_state = S_DONE; // no more nodes to process
        end
      end

      S_RELAX: begin
        if (relax_done)
          next_state = S_CHECK;
      end

      S_CHECK: begin
        // After checking goal, attempt another Dijkstra iteration
        // If no unvisited nodes with finite dist, SELECT will send to DONE
        next_state = S_SELECT;
      end

      S_DONE: begin
        if (start_pulse)
          next_state = S_INIT;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule