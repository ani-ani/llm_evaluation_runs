module minimal_settlers(
  input clk,
  input rst_n,
  input start,
  input [3:0] node_count,
  input [3:0] iron_count,
  input [3:0] coal_count,
  input [7:0] iron_list,
  input [7:0] coal_list,
  input [7:0][3:0] neighbor_counts,
  input [7:0][3:0][2:0] neighbors,
  output reg [3:0] result,
  output reg done,
  output reg impossible
);

  // Local parameters
  localparam MAX_NODES = 8;
  localparam MAX_NEIGHBORS = 4;
  localparam INF = 4'b1111; // use 4-bit wide to match result width

  // FSM states
  typedef enum logic [2:0] {
    IDLE      = 3'b000,
    IRON_BFS  = 3'b001,
    COAL_BFS  = 3'b010,
    CALCULATE = 3'b011,
    DONE      = 3'b100
  } state_t;

  state_t state, next_state;

  // BFS internals
  reg [3:0] bfsNodeCount; // clamped node count for this BFS
  reg [3:0] bfsIter;      // iteration index (0..bfsNodeCount)
  reg [2:0] q_head, q_tail;
  reg [MAX_NODES-1:0] q_full;
  reg [2:0] q [$size-1:0]; // not used, kept for tool compatibility
  reg [3:0] q_mem [0:MAX_NODES-1]; // queue as circular memory
  reg [3:0] dist [0:MAX_NODES-1];  // distances (0..15), INF if unreachable
  reg [MAX_NODES-1:0] visited;
  reg [3:0] minIronDist;
  reg [3:0] minCoalDist;
  reg [3:0] currentBfsNode;
  reg [3:0] bfsNeighborCount;
  reg [3:0] bfsNeighborIdx;
  reg [3:0] bfsNeighbor;
  reg [3:0] bfsDistancePlus1;

  // Helper: clamp to 8
  wire [3:0] clamped_node_count;
  assign clamped_node_count = (node_count > 4'd8) ? 4'd8 : node_count;

  // Sequential state update with async active-low reset
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      impossible <= 1'b0;
      result <= 4'd0;
    end else begin
      state <= next_state;
      // Outputs are updated in CALCULATE and preserved in DONE; else hold low
      if (next_state == CALCULATE) begin
        // These will be set in the combinational block below; readback ensures final values on next cycle
        done <= done;
        impossible <= impossible;
        result <= result;
      end else if (next_state == DONE) begin
        // Hold outputs stable
        done <= done;
        impossible <= impossible;
        result <= result;
      end else begin
        // Clear outputs when not computing
        done <= 1'b0;
        impossible <= 1'b0;
        result <= result; // keep last result until new start
      end
    end
  end

  // Next state logic and BFS datapath
  always_comb begin
    // Defaults
    next_state = state;

    // BFS internals: non-blocking default assignments
    bfsNodeCount      = bfsNodeCount;
    bfsIter           = bfsIter;
    q_head            = q_head;
    q_tail            = q_tail;
    q_full            = q_full;
    dist              = dist;
    visited           = visited;
    minIronDist       = minIronDist;
    minCoalDist       = minCoalDist;
    currentBfsNode    = currentBfsNode;
    bfsNeighborCount  = bfsNeighborCount;
    bfsNeighborIdx    = bfsNeighborIdx;
    bfsNeighbor       = bfsNeighbor;
    bfsDistancePlus1  = bfsDistancePlus1;

    // Output updates will be set in CALCULATE
    result = result;
    done = done;
    impossible = impossible;

    case (state)
      IDLE: begin
        // Clear pipeline/inputs-probing-related signals
        bfsNodeCount  = 4'd0;
        bfsIter       = 4'd0;
        q_head        = 3'd0;
        q_tail        = 3'd0;
        q_full        = 8'd0;
        minIronDist   = INF;
        minCoalDist   = INF;
        // Dist and visited not needed here, will be set in BFS start
        if (start) begin
          // Start IRON BFS from node 0 (cell 1)
          bfsNodeCount = clamped_node_count;
          // Initialize BFS structures
          for (int i = 0; i < MAX_NODES; i++) begin
            dist[i] = INF;
          end
          visited = 8'd0;
          // Seed queue with start node 0
          q_mem[0] = 4'd0;
          q_head = 3'd1; // next pop from index 1
          q_tail = 3'd1; // next push at index 1
          q_full = 8'd1; // 1 element used
          dist[0] = 4'd0;
          visited[0] = 1'b1;
          bfsIter = 4'd1; // will pop node 0 first
          next_state = IRON_BFS;
        end else begin
          next_state = IDLE;
        end
      end

      IRON_BFS: begin
        if (bfsIter < bfsNodeCount) begin
          // Pop node from queue
          currentBfsNode = q_mem[bfsIter];
          // Determine neighbor count for this node
          bfsNeighborCount = neighbor_counts[currentBfsNode];
          // Clamp neighbor count to MAX_NEIGHBORS
          if (bfsNeighborCount > MAX_NEIGHBORS) bfsNeighborCount = MAX_NEIGHBORS;
          bfsNeighborIdx = 4'd0;
          bfsIter = bfsIter + 1;
          next_state = IRON_BFS;
        end else begin
          // Find min distance to any iron node (if any)
          minIronDist = INF;
          for (int i = 0; i < MAX_NODES; i++) begin
            if (i < bfsNodeCount) begin
              if (iron_list[i] && dist[i] != INF) begin
                if (dist[i] < minIronDist) minIronDist = dist[i];
              end
            end
          end
          // Start COAL BFS from node 0 again
          for (int i = 0; i < MAX_NODES; i++) begin
            dist[i] = INF;
          end
          visited = 8'd0;
          q_mem[0] = 4'd0;
          q_head = 3'd1;
          q_tail = 3'd1;
          q_full = 8'd1;
          dist[0] = 4'd0;
          visited[0] = 1'b1;
          bfsIter = 4'd1; // will pop node 0 first
          next_state = COAL_BFS;
        end
      end

      COAL_BFS: begin
        if (bfsIter < bfsNodeCount) begin
          // Pop node from queue
          currentBfsNode = q_mem[bfsIter];
          // Determine neighbor count for this node
          bfsNeighborCount = neighbor_counts[currentBfsNode];
          // Clamp neighbor count to MAX_NEIGHBORS
          if (bfsNeighborCount > MAX_NEIGHBORS) bfsNeighborCount = MAX_NEIGHBORS;
          bfsNeighborIdx = 4'd0;
          bfsIter = bfsIter + 1;
          next_state = COAL_BFS;
        end else begin
          // Find min distance to any coal node (if any)
          minCoalDist = INF;
          for (int i = 0; i < MAX_NODES; i++) begin
            if (i < bfsNodeCount) begin
              if (coal_list[i] && dist[i] != INF) begin
                if (dist[i] < minCoalDist) minCoalDist = dist[i];
              end
            end
          end
          next_state = CALCULATE;
        end
      end

      CALCULATE: begin
        // Compute minimal settlers = min_iron + min_coal - 1 (start node doesn't need binding)
        if ((minIronDist != INF) && (minCoalDist != INF)) begin
          // Both reachable
          bfsDistancePlus1 = minIronDist + minCoalDist - 1;
          // Cap to 4 bits (0..15)
          if (bfsDistancePlus1 > 4'd15) bfsDistancePlus1 = 4'd15;
          result = bfsDistancePlus1;
          done = 1'b1;
          impossible = 1'b0;
        end else begin
          // One or both unreachable
          result = 4'd0;
          done = 1'b0;
          impossible = 1'b1;
        end
        next_state = DONE;
      end

      DONE: begin
        // Hold outputs; wait for start to begin new computation or stay done until reset
        done = done;
        impossible = impossible;
        result = result;
        if (start) begin
          // Allow re-start on next cycle (go to IDLE which will immediately begin)
          next_state = IDLE;
        end else begin
          next_state = DONE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Combinational neighbor processing within BFS cycles
  // Processed each clock in IRON_BFS and COAL_BFS after a node has been popped
  always_comb begin
    if (state == IRON_BFS || state == COAL_BFS) begin
      // Default (no change) retain previous values
      dist       = dist;
      visited    = visited;
      q_head     = q_head;
      q_tail     = q_tail;
      q_full     = q_full;
      // Derived per-iteration signals
      bfsNeighbor       = bfsNeighbor;
      bfsNeighborCount  = bfsNeighborCount;
      bfsNeighborIdx    = bfsNeighborIdx;

      // If we just popped a node (bfsIter advanced), process its neighbors
      if (bfsNeighborIdx < bfsNeighborCount) begin
        bfsNeighbor = neighbors[currentBfsNode][bfsNeighborIdx];
        // Convert from 1-based IDs to 0-based indices
        if (bfsNeighbor > 0) bfsNeighbor = bfsNeighbor - 1;
        else bfsNeighbor = 3'd0; // guard; treat 0 as node 0

        // Check bounds and visit if unvisited and within node count
        if (bfsNeighbor < bfsNodeCount) begin
          if (!visited[bfsNeighbor]) begin
            // Mark visited and set distance
            visited[bfsNeighbor] = 1'b1;
            dist[bfsNeighbor] = dist[currentBfsNode] + 1;
            // Enqueue neighbor if space
            if (!q_full[q_tail]) begin
              q_mem[q_tail] = bfsNeighbor;
              // Update tail and full flags
              q_tail = q_tail + 1;
              q_full[q_tail] = 1'b1; // mark new tail position as used (simplified occupancy)
            end
          end
        end
        // Advance neighbor index for next cycle
        bfsNeighborIdx = bfsNeighborIdx + 1;
      end else begin
        // No more neighbors to process in this cycle
        bfsNeighborIdx = bfsNeighborIdx;
      end
    end else begin
      // Not in BFS states; keep latched values stable
      dist       = dist;
      visited    = visited;
      q_head     = q_head;
      q_tail     = q_tail;
      q_full     = q_full;
      bfsNeighbor       = bfsNeighbor;
      bfsNeighborCount  = bfsNeighborCount;
      bfsNeighborIdx    = bfsNeighborIdx;
    end
  end

endmodule
