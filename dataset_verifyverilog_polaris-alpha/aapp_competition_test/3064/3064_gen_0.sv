module longest_path_to_1(
    input  clk,
    input  rst_n,
    input  start,
    input  [2:0]  node_count,
    input  [15:0][7:0] edges, // {A[2:0], B[2:0], 1'bunused, 1'bvalid}
    output reg [4:0] path_length,
    output reg       done
);

    // ------------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------------
    localparam MAX_NODES   = 8;
    localparam MAX_EDGES   = 16;
    localparam MAX_STATES  = MAX_EDGES + 1; // (used_mask options)
    localparam MAX_DEPTH   = 5'd31;
    localparam TARGET_NODE = 3'd0;         // city 1 has ID 0

    // We model exploration states as:
    //   node:   current node (0..7)
    //   used:   16-bit bitmask of used edges
    // That ensures no road reuse.
    // We perform a bounded DFS / BFS-style expansion over 100 cycles.

    // ------------------------------------------------------------------
    // Edge decode and adjacency: edges are treated as bidirectional.
    // Also build a compact adjacency list to speed exploration.
    // ------------------------------------------------------------------

    // Store decoded edges
    reg [2:0] edge_a [0:MAX_EDGES-1];
    reg [2:0] edge_b [0:MAX_EDGES-1];
    reg       edge_v [0:MAX_EDGES-1];

    // Adjacency: for each node, list of incident edges
    // max 16 edges, 8 nodes: worst case all edges touch all nodes; but with
    // practical constraints each node will have limited edges.
    // We'll allow up to 16 incident edges per node for simplicity.
    localparam MAX_NODE_EDGES = 16;

    reg [3:0] node_edge_count [0:MAX_NODES-1];
    reg [3:0] node_edge_idx   [0:MAX_NODES-1][0:MAX_NODE_EDGES-1];

    // ------------------------------------------------------------------
    // Exploration state representation
    // ------------------------------------------------------------------

    // A state is (node, used_mask, depth)
    typedef struct packed {
        logic [2:0] node;
        logic [15:0] used;
        logic [4:0] depth;
    } state_t;

    // We keep a small frontier (queue-style) plus next frontier.
    // With 16 edges, maximum distinct used-mask depth combinations is large,
    // but we constrain by time (100 cycles) and small frontier size.

    localparam FRONTIER_SIZE = 32; // heuristic; adequate within 100 cycles

    state_t frontier      [0:FRONTIER_SIZE-1];
    state_t next_frontier [0:FRONTIER_SIZE-1];

    reg [5:0] frontier_count;      // 0..32
    reg [5:0] next_frontier_count; // 0..32

    reg [4:0] best_len;

    // FSM
    typedef enum logic [2:0] {
        S_IDLE   = 3'd0,
        S_LOAD   = 3'd1,
        S_INIT   = 3'd2,
        S_EXPAND = 3'd3,
        S_WAIT   = 3'd4,
        S_DONE   = 3'd5
    } state_e;

    state_e cur_state, nxt_state;

    // cycle counter to enforce 100-cycle latency from start
    reg [6:0] cycle_cnt; // up to 127

    integer i, j;

    // ------------------------------------------------------------------
    // Combinational next-state for FSM
    // ------------------------------------------------------------------
    always @* begin
        nxt_state = cur_state;
        case (cur_state)
            S_IDLE: begin
                if (start)
                    nxt_state = S_LOAD;
            end
            S_LOAD: begin
                // one cycle to latch edges
                nxt_state = S_INIT;
            end
            S_INIT: begin
                // build initial frontier (all starting nodes)
                nxt_state = S_EXPAND;
            end
            S_EXPAND: begin
                // keep expanding until cycle_cnt hits 100
                if (cycle_cnt >= 7'd99)
                    nxt_state = S_DONE;
                else
                    nxt_state = S_EXPAND;
            end
            S_DONE: begin
                // stay done until next start
                if (!start)
                    nxt_state = S_IDLE;
            end
            default: nxt_state = S_IDLE;
        endcase
    end

    // ------------------------------------------------------------------
    // Sequential logic
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cur_state    <= S_IDLE;
            path_length  <= 5'd0;
            done         <= 1'b0;
            best_len     <= 5'd0;
            cycle_cnt    <= 7'd0;

            // clear adjacency and edges
            for (i = 0; i < MAX_EDGES; i = i + 1) begin
                edge_a[i] <= 3'd0;
                edge_b[i] <= 3'd0;
                edge_v[i] <= 1'b0;
            end
            for (i = 0; i < MAX_NODES; i = i + 1) begin
                node_edge_count[i] <= 4'd0;
                for (j = 0; j < MAX_NODE_EDGES; j = j + 1) begin
                    node_edge_idx[i][j] <= 4'd0;
                end
            end

            frontier_count      <= 6'd0;
            next_frontier_count <= 6'd0;
        end else begin
            cur_state <= nxt_state;

            case (cur_state)
                // ------------------------------------------------------
                // IDLE: wait for start
                // ------------------------------------------------------
                S_IDLE: begin
                    done        <= 1'b0;
                    path_length <= 5'd0;
                    best_len    <= 5'd0;
                    cycle_cnt   <= 7'd0;
                    frontier_count      <= 6'd0;
                    next_frontier_count <= 6'd0;
                    // no edge load here; wait for S_LOAD
                end

                // ------------------------------------------------------
                // LOAD: capture edges, build adjacency lists
                // ------------------------------------------------------
                S_LOAD: begin
                    // reset structures
                    best_len   <= 5'd0;
                    cycle_cnt  <= 7'd0;
                    for (i = 0; i < MAX_NODES; i = i + 1) begin
                        node_edge_count[i] <= 4'd0;
                    end

                    // parse edges
                    for (i = 0; i < MAX_EDGES; i = i + 1) begin
                        edge_a[i] <= edges[i][7:5];
                        edge_b[i] <= edges[i][4:2];
                        edge_v[i] <= edges[i][0];
                    end

                    // build adjacency (combinationally in this cycle)
                    for (i = 0; i < MAX_EDGES; i = i + 1) begin
                        if (edges[i][0]) begin
                            // endpoint A
                            if (node_edge_count[edges[i][7:5]] < MAX_NODE_EDGES) begin
                                node_edge_idx[edges[i][7:5]][ node_edge_count[edges[i][7:5]] ] <= i[3:0];
                                node_edge_count[edges[i][7:5]] <= node_edge_count[edges[i][7:5]] + 1'b1;
                            end
                            // endpoint B
                            if (node_edge_count[edges[i][4:2]] < MAX_NODE_EDGES) begin
                                node_edge_idx[edges[i][4:2]][ node_edge_count[edges[i][4:2]] ] <= i[3:0];
                                node_edge_count[edges[i][4:2]] <= node_edge_count[edges[i][4:2]] + 1'b1;
                            end
                        end
                    end

                    frontier_count      <= 6'd0;
                    next_frontier_count <= 6'd0;
                end

                // ------------------------------------------------------
                // INIT: initialize frontier from all nodes (all paths start everywhere)
                // ------------------------------------------------------
                S_INIT: begin
                    frontier_count      <= 6'd0;
                    next_frontier_count <= 6'd0;
                    best_len            <= 5'd0;
                    cycle_cnt           <= 7'd0;

                    // create initial frontier states: each node as start
                    // Only nodes < node_count are valid.
                    for (i = 0; i < FRONTIER_SIZE; i = i + 1) begin
                        frontier[i].node  <= 3'd0;
                        frontier[i].used  <= 16'd0;
                        frontier[i].depth <= 5'd0;
                    end

                    for (i = 0; i < MAX_NODES; i = i + 1) begin
                        if (i < node_count && frontier_count < FRONTIER_SIZE) begin
                            frontier[frontier_count].node  <= i[2:0];
                            frontier[frontier_count].used  <= 16'd0;
                            frontier[frontier_count].depth <= 5'd0;
                            frontier_count <= frontier_count + 1'b1;
                        end
                    end
                end

                // ------------------------------------------------------
                // EXPAND: BFS/DFS-style exploration with used-edge masks
                // ------------------------------------------------------
                S_EXPAND: begin
                    // We do one full-level expansion per cycle (from frontier to next_frontier)
                    integer f, ne_idx;
                    reg [2:0] cur_node;
                    reg [15:0] cur_used;
                    reg [4:0] cur_depth;
                    reg [3:0] e_idx;
                    reg [2:0] na, nb;
                    reg       vv;
                    reg [2:0] nxt_node;
                    reg [15:0] nxt_used;
                    reg [4:0] nxt_depth;

                    // reset next frontier count
                    next_frontier_count <= 6'd0;

                    // expand each frontier state
                    for (f = 0; f < FRONTIER_SIZE; f = f + 1) begin
                        if (f < frontier_count) begin
                            cur_node  = frontier[f].node;
                            cur_used  = frontier[f].used;
                            cur_depth = frontier[f].depth;

                            // if we are at target node, update best_len
                            if (cur_node == TARGET_NODE) begin
                                if (cur_depth > best_len)
                                    best_len <= cur_depth;
                            end

                            // traverse all incident edges of cur_node
                            for (ne_idx = 0; ne_idx < MAX_NODE_EDGES; ne_idx = ne_idx + 1) begin
                                if (ne_idx < node_edge_count[cur_node]) begin
                                    e_idx = node_edge_idx[cur_node][ne_idx];
                                    vv    = edge_v[e_idx];
                                    if (vv && !cur_used[e_idx]) begin
                                        na = edge_a[e_idx];
                                        nb = edge_b[e_idx];

                                        // determine neighbor
                                        if (cur_node == na)
                                            nxt_node = nb;
                                        else if (cur_node == nb)
                                            nxt_node = na;
                                        else
                                            nxt_node = cur_node; // safety

                                        // only consider if within node_count
                                        if (nxt_node < node_count) begin
                                            nxt_used         = cur_used;
                                            nxt_used[e_idx]  = 1'b1;
                                            nxt_depth        = (cur_depth < MAX_DEPTH) ? (cur_depth + 1'b1) : cur_depth;

                                            // push into next_frontier if space
                                            if (next_frontier_count < FRONTIER_SIZE) begin
                                                next_frontier[next_frontier_count].node  <= nxt_node;
                                                next_frontier[next_frontier_count].used  <= nxt_used;
                                                next_frontier[next_frontier_count].depth <= nxt_depth;
                                                next_frontier_count <= next_frontier_count + 1'b1;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end

                    // move next_frontier -> frontier for next cycle
                    for (i = 0; i < FRONTIER_SIZE; i = i + 1) begin
                        if (i < next_frontier_count) begin
                            frontier[i].node  <= next_frontier[i].node;
                            frontier[i].used  <= next_frontier[i].used;
                            frontier[i].depth <= next_frontier[i].depth;
                        end else begin
                            frontier[i].node  <= 3'd0;
                            frontier[i].used  <= 16'd0;
                            frontier[i].depth <= 5'd0;
                        end
                    end
                    frontier_count <= next_frontier_count;

                    // increment global cycle counter; done at 100 cycles
                    if (cycle_cnt < 7'd127)
                        cycle_cnt <= cycle_cnt + 1'b1;
                end

                // ------------------------------------------------------
                // DONE: latch result and assert done after 100 cycles
                // ------------------------------------------------------
                S_DONE: begin
                    done        <= 1'b1;
                    path_length <= best_len;
                    // hold values; wait for new start -> IDLE
                end

                default: begin
                    // safety
                    done        <= 1'b0;
                    path_length <= best_len;
                end
            endcase
        end
    end

endmodule