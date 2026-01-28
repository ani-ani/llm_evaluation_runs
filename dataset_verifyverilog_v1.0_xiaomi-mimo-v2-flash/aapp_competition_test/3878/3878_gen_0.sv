module FriendshipCliqueSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [5:0] m,
    input wire [4:0] u,
    input wire [4:0] v,
    output reg [5:0] step_count,
    output reg [114:0] steps,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD = 4'd1;
    localparam [3:0] INIT_ADJ = 4'd2;
    localparam [3:0] CHECK_COMPLETE = 4'd3;
    localparam [3:0] SELECT_NODE = 4'd4;
    localparam [3:0] UPDATE_GRAPH = 4'd5;
    localparam [3:0] UPDATE_MASK = 4'd6;
    localparam [3:0] INCREMENT_STEP = 4'd7;
    localparam [3:0] FINISHED = 4'd8;
    localparam [3:0] TIMEOUT = 4'd9;

    reg [3:0] state, next_state;
    reg [4:0] step_idx;
    reg [4:0] load_idx;
    reg [4:0] node_idx;
    reg [4:0] node_max;
    reg [4:0] best_node;
    reg [5:0] cycle_counter;
    localparam [5:0] MAX_CYCLES = 6'd200;

    // Adjacency matrix: 22x22 bits stored as 22 registers of 22 bits each
    reg [21:0] adj_reg [21:0];
    reg [21:0] current_adj [21:0];
    reg [21:0] connected_mask; // Bitmask of nodes that are fully connected to others

    // Intermediate signals
    reg [21:0] temp_mask;
    reg [21:0] temp_friend_mask;
    reg [21:0] new_edges_mask;
    reg [4:0] temp_node;
    reg [21:0] test_mask;
    reg [21:0] test_mask2;
    reg found_all;
    reg [4:0] i, j, k;
    reg [21:0] combined_mask;
    reg [5:0] steps_counter;
    reg [5:0] edge_count;
    reg [5:0] max_edges;
    reg [4:0] temp_steps [21:0];

    integer step_write_idx;

    // Helper: Count set bits in a 22-bit mask
    function automatic [4:0] count_bits(input [21:0] mask);
        reg [4:0] count;
        integer b;
        begin
            count = 5'd0;
            for (b = 0; b < 22; b = b + 1) begin
                if (mask[b]) begin
                    count = count + 5'd1;
                end
            end
            count_bits = count;
        end
    endfunction

    // Helper: Find node with maximum new connections
    function automatic [4:0] find_best_node(input [21:0] current_mask, input [21:0] adj [21:0], input [4:0] max_node);
        reg [4:0] best;
        reg [5:0] best_score;
        reg [5:0] current_score;
        reg [21:0] friends;
        reg [21:0] combined;
        integer idx;
        begin
            best = 5'd0;
            best_score = 6'd0;
            for (idx = 0; idx < 22; idx = idx + 1) begin
                if (idx < max_node) begin
                    friends = adj[idx];
                    // Score: count of new nodes added to clique
                    // We add idx if not in mask, and all friends
                    // New nodes = (mask | {idx} | friends) \ mask
                    combined = current_mask | (1 << idx) | friends;
                    current_score = count_bits(combined) - count_bits(current_mask);
                    if (current_score > best_score) begin
                        best_score = current_score;
                        best = idx;
                    end
                end
            end
            find_best_node = best;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            step_count <= 6'd0;
            steps <= 115'd0;
            cycle_counter <= 6'd0;
            load_idx <= 5'd0;
            step_idx <= 5'd0;
            node_idx <= 5'd0;
            connected_mask <= 22'd0;
            for (i = 0; i < 22; i = i + 1) begin
                adj_reg[i] <= 22'd0;
                current_adj[i] <= 22'd0;
            end
            for (step_write_idx = 0; step_write_idx < 22; step_write_idx = step_write_idx + 1) begin
                temp_steps[step_write_idx] <= 5'd0;
            end
        end else begin
            cycle_counter <= cycle_counter + 6'd1;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    step_count <= 6'd0;
                    steps <= 115'd0;
                    load_idx <= 5'd0;
                    step_idx <= 5'd0;
                    connected_mask <= 22'd0;
                    cycle_counter <= 6'd0;
                    if (start) begin
                        state <= LOAD;
                        // Initialize adjacency self-connections
                        for (i = 0; i < 22; i = i + 1) begin
                            adj_reg[i][i] <= 1'b1;
                            current_adj[i][i] <= 1'b1;
                        end
                    end
                end

                LOAD: begin
                    // Assume inputs u, v are provided externally
                    // For this implementation, we accept one edge per cycle until m=0 or max edges
                    // In a real scenario, you'd need a separate edge input interface
                    // Here we simulate loading by checking if edge inputs are valid
                    // For simplicity in this single module, we treat u and v as static inputs
                    // to be processed. However, since we need to load m edges,
                    // we'll just use the current u/v inputs for the first edge
                    // and assume they are stable or we iterate.
                    // To make it robust, let's assume the testbench feeds edges serially.
                    // If u and v are valid (different), add to adj_reg
                    if (load_idx < m && u != v) begin
                        adj_reg[u][v] <= 1'b1;
                        adj_reg[v][u] <= 1'b1;
                        current_adj[u][v] <= 1'b1;
                        current_adj[v][u] <= 1'b1;
                        load_idx <= load_idx + 5'd1;
                    end
                    if (load_idx >= m) begin
                        state <= INIT_ADJ;
                    end
                end

                INIT_ADJ: begin
                    // Initialize connected_mask: all nodes with degree n-1 are fully connected
                    // For simplicity in Greedy, start with empty mask (or just self-connected)
                    connected_mask <= 22'd0;
                    // Self-connected
                    for (i = 0; i < n; i = i + 1) begin
                        current_adj[i][i] <= 1'b1;
                    end
                    state <= CHECK_COMPLETE;
                end

                CHECK_COMPLETE: begin
                    // Check if graph is fully connected (clique)
                    // For every pair (i, j) where i < j < n, adj[i][j] must be 1
                    found_all <= 1'b1;
                    // Check connectivity of current mask if we only care about subset
                    // But requirement: make all n guests friends
                    // Check if all pairs connected
                    // We can check column sums or simple iteration
                    // Optimization: Check if connected_mask covers all n nodes and they are fully connected
                    // Actually, simpler: check if for all i in 0..n-1, adj[i] has all bits 0..n-1 set
                    // We'll do a check per cycle
                    if (node_idx < n) begin
                        temp_mask = current_adj[node_idx];
                        // Mask out bits >= n
                        temp_mask = temp_mask & ((1 << n) - 1);
                        if (temp_mask != ((1 << n) - 1)) begin
                            found_all <= 1'b0;
                        end
                        node_idx <= node_idx + 5'd1;
                    end else begin
                        node_idx <= 5'd0;
                        if (found_all && step_idx > 0) begin
                            state <= FINISHED;
                        end else if (cycle_counter > MAX_CYCLES) begin
                            state <= TIMEOUT;
                        end else begin
                            state <= SELECT_NODE;
                        end
                    end
                end

                SELECT_NODE: begin
                    // Greedy selection: find node that adds most new edges/cliques
                    // We look for node i that maximizes (new connections)
                    // New connections = degree of i in current graph (excluding already fully connected neighbors)
                    // Actually, the operation: pick i, then friends of i become clique.
                    // This adds edges between all pairs of friends of i.
                    // We want to maximize reduction in missing edges.
                    // Heuristic: pick node with highest degree in the "not yet fully connected" part.
                    
                    // Simple greedy: pick node with max degree in current graph
                    reg [4:0] best;
                    reg [4:0] d;
                    reg [4:0] max_deg;
                    
                    best = 5'd0;
                    max_deg = 5'd0;
                    
                    for (i = 0; i < n; i = i + 1) begin
                        d = count_bits(current_adj[i]);
                        if (d > max_deg) begin
                            max_deg = d;
                            best = i;
                        end
                    end
                    
                    best_node <= best;
                    temp_node <= best;
                    state <= UPDATE_GRAPH;
                end

                UPDATE_GRAPH: begin
                    // Execute operation: pick temp_node
                    // 1. Get friends of temp_node
                    temp_friend_mask = current_adj[temp_node];
                    // 2. Make all friends a clique: for every pair (i,j) in temp_friend_mask, set adj[i][j] = 1
                    // This is O(N^2) operation. We iterate.
                    // We need to update current_adj.
                    // Since we can't update entire matrix in one cycle (484 bits), we iterate over nodes.
                    
                    // We update row i for all i in temp_friend_mask
                    // Set columns j for all j in temp_friend_mask
                    // We will do this row by row.
                    if (node_idx < n) begin
                        // Check if node_idx is a friend of temp_node
                        if (temp_friend_mask[node_idx]) begin
                            // Update row node_idx: OR with temp_friend_mask
                            current_adj[node_idx] <= current_adj[node_idx] | temp_friend_mask;
                        end
                        node_idx <= node_idx + 5'd1;
                    end else begin
                        node_idx <= 5'd0;
                        state <= UPDATE_MASK;
                    end
                end

                UPDATE_MASK: begin
                    // Update connected mask (nodes that are now fully connected)
                    // A node i is fully connected if its adjacency row has all n bits set
                    if (node_idx < n) begin
                        temp_mask = current_adj[node_idx];
                        temp_mask = temp_mask & ((1 << n) - 1);
                        if (temp_mask == ((1 << n) - 1)) begin
                            connected_mask[node_idx] <= 1'b1;
                        end
                        node_idx <= node_idx + 5'd1;
                    end else begin
                        node_idx <= 5'd0;
                        state <= INCREMENT_STEP;
                    end
                end

                INCREMENT_STEP: begin
                    // Record step
                    if (step_idx < 22) begin
                        // Pack into steps output (115 bits)
                        // steps[114:0] stores 22 steps of 5 bits each
                        // Index 0 is MSB or LSB? Let's assume MSB first for step 0
                        // Step 0: bits 114-110
                        // Step idx: bits (114 - idx*5) downto (110 - idx*5)
                        // We use a temp array to build it then pack at end or update packing
                        // Packing in hardware is tricky with variable index.
                        // Let's use a shift register approach or direct mapping.
                        // Easier: update specific slice.
                        // Verilog slice assignment on variable slice is not always supported.
                        // We will reconstruct 'steps' from temp_steps array at the end.
                        // But we need to output it continuously.
                        // Let's update temp_steps here.
                        temp_steps[step_idx] <= best_node;
                        step_idx <= step_idx + 5'd1;
                        step_count <= step_count + 6'd1;
                    end
                    // Check loop condition again
                    state <= CHECK_COMPLETE;
                end

                FINISHED: begin
                    // Pack temp_steps into 'steps' output
                    // Reconstruct 115-bit vector from temp_steps
                    // Since we can't easily do slice assignment with loop in combinational logic,
                    // we do it here in sequential logic.
                    // We'll iterate to pack.
                    if (node_idx < 22) begin
                        // Shift current steps left by 5 and OR in new step
                        // But 'steps' is a reg, we can do it bit by bit or index by index.
                        // Let's do direct mapping if possible, but indices are variable.
                        // Let's iterate. We need a packing state or use combinational output.
                        // Let's use combinational logic for 'steps' output based on temp_steps.
                        // But requirements say output reg [114:0] steps.
                        // We will define steps as combinational logic usually, but spec says reg.
                        // Let's keep it sequential for robustness.
                        // We'll pack 22 steps.
                        steps <= 115'd0;
                        for (i = 0; i < 22; i = i + 1) begin
                            steps <= {steps[109:0], temp_steps[i]};
                        end
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                TIMEOUT: begin
                    // Force finish on timeout
                    step_count <= 6'd0;
                    steps <= 115'd0;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule