module good_node_finder(
  input clk,
  input rst_n,
  input start,
  input [2:0] edge_count,
  input [2:0] node_a [0:7],
  input [2:0] node_b [0:7],
  input [2:0] color [0:7],
  output reg [7:0] good_nodes,
  output reg done
);

  // Localparams for state machine
  localparam IDLE   = 3'd0;
  localparam INIT   = 3'd1;
  localparam CHECK_NODE = 3'd2;
  localparam TRAVERSE = 3'd3;
  localparam DONE   = 3'd7;

  // State and counters
  reg [2:0] state;
  reg [2:0] node_idx;     // which node we are checking (0..7)
  reg [2:0] edge_idx;     // scanning edge list for BFS initialization
  reg [7:0] queued;       // bitmask of nodes already in queue
  reg [7:0] visited;      // bitmask of nodes visited in BFS from current root
  reg [2:0] q_head;       // queue head pointer (0..8)
  reg [2:0] q_tail;       // queue tail pointer (0..8)
  reg [3:0] q_depth;      // max queue depth reached (0..8), for capacity

  // BFS queue entry: {last_color[2:0], node_id[2:0]}
  reg [5:0] q_items [0:7];

  // Packed queue (for synthesis friendliness)
  // Each entry: [5:3] = last_color, [2:0] = node_id
  reg [5:0] queue_pack [0:7];
  wire [2:0] curr_node_from_q;
  wire [2:0] curr_last_color_from_q;
  assign curr_node_from_q = queue_pack[q_head][2:0];
  assign curr_last_color_from_q = queue_pack[q_head][5:3];

  // Internal control signals
  reg good_node;          // '1' if current node passes all path checks
  reg last_color_eq;      // combinatorial: 1 if current edge color equals last color

  integer i; // loop variable for reset

  // Keep track of max depth reached for statistics (not strictly required)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) q_depth <= 4'd0;
    else begin
      if ((state == INIT) && (q_tail > q_depth))
        q_depth <= q_tail;
      else if (state != INIT)
        q_depth <= q_depth; // hold
    end
  end

  // Combinational equality check for colors
  always @(*) begin
    if (edge_idx < edge_count) begin
      last_color_eq = (color[edge_idx] == queue_pack[q_head][5:3]);
    end else begin
      last_color_eq = 1'b0;
    end
  end

  // Main state machine and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      good_nodes <= 8'h0;
      node_idx <= 3'd0;
      edge_idx <= 3'd0;
      queued <= 8'h0;
      visited <= 8'h0;
      q_head <= 3'd0;
      q_tail <= 3'd0;
      good_node <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        q_items[i] <= 6'd0;
        queue_pack[i] <= 6'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          good_nodes <= 8'h0;
          node_idx <= 3'd0;
          edge_idx <= 3'd0;
          queued <= 8'h0;
          visited <= 8'h0;
          q_head <= 3'd0;
          q_tail <= 3'd0;
          for (i = 0; i < 8; i = i + 1) begin
            q_items[i] <= 6'd0;
            queue_pack[i] <= 6'd0;
          end
          if (start) begin
            state <= CHECK_NODE;
          end else begin
            state <= IDLE;
          end
        end

        // Initialize BFS for the current node (node_idx)
        INIT: begin
          // Clear flags for this root
          visited <= 8'h0;
          queued <= 8'h0;
          q_head <= 3'd0;
          q_tail <= 3'd0;
          good_node <= 1'b1; // assume good until we find a violation
          // Seed queue with current node with no prior color (use 3'b111 as sentinel)
          queue_pack[0] <= {3'b111, node_idx};
          q_tail <= 3'd1; // one item enqueued
          state <= TRAVERSE;
        end

        // Select the node to test (0..7)
        CHECK_NODE: begin
          if (node_idx < 3'd8) begin
            state <= INIT;
          end else begin
            state <= DONE;
          end
        end

        // Traverse all paths starting from node_idx, checking no consecutive same colors
        TRAVERSE: begin
          if (q_head == q_tail) begin
            // Queue empty: done with this node
            // Record the result of the current node
            if (good_node) begin
              good_nodes[node_idx] <= 1'b1;
            end else begin
              good_nodes[node_idx] <= 1'b0;
            end
            node_idx <= node_idx + 1;
            state <= CHECK_NODE;
          end else begin
            // Process the head item
            if (visited[curr_node_from_q]) begin
              // Already processed this node, skip it (no cycles)
              q_head <= q_head + 1;
              state <= TRAVERSE;
            end else begin
              // Mark this node as visited
              visited <= visited | (1 << curr_node_from_q);
              // Explore all edges from this node
              edge_idx <= 3'd0;
              state <= TRAVERSE; // stay in TRAVERSE to process edges
            end
          end
        end

        DONE: begin
          done <= 1'b1;
          if (start) begin
            // Hold done high while start is asserted
            state <= DONE;
          end else begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

  // Edge expansion cycle (processes one edge per cycle when inside TRAVERSE)
  always @(posedge clk) begin
    if (state == TRAVERSE) begin
      // If queue empty, transition is handled in TRAVERSE state block above
      if (q_head != q_tail) begin
        // If current node wasn't visited, we just marked visited above; now explore edges
        if (edge_idx < edge_count) begin
          if (node_a[edge_idx] == curr_node_from_q) begin
            // Check color constraint before enqueue
            if (curr_last_color_from_q == 3'b111) begin
              // Root has no previous color; any color is fine
              if (!queued[node_b[edge_idx]]) begin
                // Enqueue new item with this edge color
                queue_pack[q_tail] <= {color[edge_idx], node_b[edge_idx]};
                queued <= queued | (1 << node_b[edge_idx]);
                q_tail <= q_tail + 1;
              end
            end else if (color[edge_idx] != curr_last_color_from_q) begin
              // Color constraint satisfied; enqueue if not already queued
              if (!queued[node_b[edge_idx]]) begin
                queue_pack[q_tail] <= {color[edge_idx], node_b[edge_idx]};
                queued <= queued | (1 << node_b[edge_idx]);
                q_tail <= q_tail + 1;
              end
            end else begin
              // Consecutive same colors found: node is not good
              good_node <= 1'b0;
            end
          end
          // Move to next edge to search
          edge_idx <= edge_idx + 1;
        end else begin
          // Finished scanning all edges from this node; pop it
          q_head <= q_head + 1;
          // Next cycle will either process next queued item or finish
        end
      end
    end
  end

endmodule
