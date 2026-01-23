module path_counter #(
    parameter MAX_NODES = 8,
    parameter MAX_EDGES = 16,
    parameter MOD = 1000000000
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire graph_write_en,
    input wire [2:0] src,
    input wire [2:0] dst,
    input wire [3:0] cnt,
    output reg [31:0] result,
    output reg done,
    output reg inf
);

    // State encoding
    localparam [2:0] STATE_IDLE    = 3'd0;
    localparam [2:0] STATE_CONFIG  = 3'd1;
    localparam [2:0] STATE_COMPUTE = 3'd2;
    localparam [2:0] STATE_DONE    = 3'd3;
    reg [2:0] state;

    // Adjacency matrix: adj[u][v] = number of edges from u to v
    reg [3:0] adj [0:MAX_NODES-1][0:MAX_NODES-1];

    // Internal registers for computation
    reg [7:0] reachable;
    reg [3:0] in_degree [0:MAX_NODES-1];
    reg [2:0] topo_order [0:MAX_NODES-1];
    reg [2:0] topo_count;
    reg [2:0] node_idx;
    reg [2:0] k_idx;
    reg [2:0] j_idx;
    reg [63:0] dp [0:MAX_NODES-1];
    reg [63:0] dp_sum;
    reg [63:0] dp_mul;
    reg [63:0] dp_val_temp;
    reg compute_done;
    reg cycle_detected;
    reg [7:0] reachable_check;
    reg [2:0] node_count;
    
    // Control flags for sub-operations
    reg bfs_done;
    reg topo_done;
    reg dp_done;
    reg bfs_started;
    reg topo_started;
    reg dp_started;
    reg [2:0] bfs_step;
    reg [2:0] topo_step;
    reg [2:0] dp_step;

    // Loop indices
    integer i, j, k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= STATE_IDLE;
            done <= 1'b0;
            inf <= 1'b0;
            result <= 32'd0;
            
            for (i = 0; i < MAX_NODES; i = i + 1) begin
                for (j = 0; j < MAX_NODES; j = j + 1) begin
                    adj[i][j] <= 4'b0;
                end
                in_degree[i] <= 4'b0;
                dp[i] <= 64'b0;
            end
            
            reachable <= 8'b0;
            topo_count <= 3'b0;
            compute_done <= 1'b0;
            cycle_detected <= 1'b0;
            bfs_done <= 1'b0;
            topo_done <= 1'b0;
            dp_done <= 1'b0;
            bfs_started <= 1'b0;
            topo_started <= 1'b0;
            dp_started <= 1'b0;
            bfs_step <= 3'b0;
            topo_step <= 3'b0;
            dp_step <= 3'b0;
            reachable_check <= 8'b0;
            node_count <= 3'b0;
            
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    inf <= 1'b0;
                    if (graph_write_en) begin
                        // Update adjacency matrix
                        adj[src][dst] <= cnt;
                        state <= STATE_CONFIG;
                    end else if (start) begin
                        // Start computation
                        state <= STATE_COMPUTE;
                        
                        // Initialize computation registers
                        reachable <= 8'b0;
                        topo_count <= 3'b0;
                        compute_done <= 1'b0;
                        cycle_detected <= 1'b0;
                        bfs_done <= 1'b0;
                        topo_done <= 1'b0;
                        dp_done <= 1'b0;
                        bfs_started <= 1'b0;
                        topo_started <= 1'b0;
                        dp_started <= 1'b0;
                        bfs_step <= 3'b0;
                        topo_step <= 3'b0;
                        dp_step <= 3'b0;
                        reachable_check <= 8'b0;
                        node_count <= 3'b0;
                        
                        // Initialize dp array
                        for (i = 0; i < MAX_NODES; i = i + 1) begin
                            dp[i] <= 64'b0;
                        end
                        
                        // Initialize in_degree array
                        for (i = 0; i < MAX_NODES; i = i + 1) begin
                            in_degree[i] <= 4'b0;
                        end
                    end
                end

                STATE_CONFIG: begin
                    if (!graph_write_en) begin
                        state <= STATE_IDLE;
                    end
                end

                STATE_COMPUTE: begin
                    if (!compute_done) begin
                        // --- Step 1: Compute reachable nodes from start (node 0) ---
                        if (!bfs_done) begin
                            if (!bfs_started) begin
                                // Initialize BFS
                                reachable[0] <= 1'b1;
                                reachable_check[0] <= 1'b1;
                                bfs_started <= 1'b1;
                                bfs_step <= 3'd0;
                                node_count <= 3'd1;
                            end else begin
                                // Multi-step BFS to find all reachable nodes
                                // Each cycle, we expand one level
                                case (bfs_step)
                                    3'd0: begin
                                        // Check node 0 neighbors
                                        for (j = 0; j < MAX_NODES; j = j + 1) begin
                                            if (adj[0][j] != 4'b0) begin
                                                reachable[j] <= 1'b1;
                                                reachable_check[j] <= 1'b1;
                                            end
                                        end
                                        bfs_step <= 3'd1;
                                    end
                                    3'd1: begin
                                        // Check node 1 neighbors
                                        for (j = 0; j < MAX_NODES; j = j + 1) begin
                                            if (adj[1][j] != 4'b0 && reachable_check[1]) begin
                                                reachable[j] <= 1'b1;
                                                reachable_check[j] <= 1'b1;
                                            end
                                        end
                                        bfs_step <= 3'd2;
                                    end
                                    3'd2: begin
                                        // Check node 2 neighbors
                                        for (j = 0; j < MAX_NODES; j = j + 1) begin
                                            if (adj[2][j] != 4'b0 && reachable_check[2]) begin
                                                reachable[j] <= 1'b1;
                                                reachable_check[j] <= 1'b1;
                                            end
                                        end
                                        bfs_step <= 3'd3;
                                    end
                                    3'd3: begin
                                        // Check node 3 neighbors
                                        for (j = 0; j < MAX_NODES; j = j + 1) begin
                                            if (adj[3][j] != 4'b0 && reachable_check[3]) begin
                                                reachable[j] <= 1'b1;
                                                reachable_check[j] <= 1'b1;
                                            end
                                        end
                                        bfs_step <= 3'd4;
                                    end
                                    3'd4: begin
                                        // Check node 4 neighbors
                                        for (j = 0; j < MAX_NODES; j = j + 1) begin
                                            if (adj[4][j] != 4'b0 && reachable_check[4]) begin
                                                reachable[j] <= 1'b1;
                                                reachable_check[j] <= 1'b1;
                                            end
                                        end
                                        bfs_step <= 3'd5;
                                    end
                                    3'd5: begin
                                        // Check node 5 neighbors
                                        for (j = 0; j < MAX_NODES; j = j + 1) begin
                                            if (adj[5][j] != 4'b0 && reachable_check[5]) begin
                                                reachable[j] <= 1'b1;
                                                reachable_check[j] <= 1'b1;
                                            end
                                        end
                                        bfs_step <= 3'd6;
                                    end
                                    3'd6: begin
                                        // Check node 6 neighbors
                                        for (j = 0; j < MAX_NODES; j = j + 1) begin
                                            if (adj[6][j] != 4'b0 && reachable_check[6]) begin
                                                reachable[j] <= 1'b1;
                                                reachable_check[j] <= 1'b1;
                                            end
                                        end
                                        bfs_step <= 3'd7;
                                    end
                                    3'd7: begin
                                        // Check node 7 neighbors and finish BFS
                                        for (j = 0; j < MAX_NODES; j = j + 1) begin
                                            if (adj[7][j] != 4'b0 && reachable_check[7]) begin
                                                reachable[j] <= 1'b1;
                                                reachable_check[j] <= 1'b1;
                                            end
                                        end
                                        bfs_done <= 1'b1;
                                    end
                                endcase
                            end
                        end
                        // --- Step 2: Topological sort (Kahn's algorithm) ---
                        else if (!topo_done && bfs_done) begin
                            if (!topo_started) begin
                                // Compute in-degrees
                                for (i = 0; i < MAX_NODES; i = i + 1) begin
                                    in_degree[i] <= 4'b0;
                                end
                                topo_started <= 1'b1;
                                topo_step <= 3'd0;
                            end else begin
                                case (topo_step)
                                    3'd0: begin
                                        // Compute in-degrees for reachable nodes
                                        for (i = 0; i < MAX_NODES; i = i + 1) begin
                                            if (reachable[i]) begin
                                                for (j = 0; j < MAX_NODES; j = j + 1) begin
                                                    if (reachable[j] && adj[j][i] != 4'b0) begin
                                                        in_degree[i] <= in_degree[i] + adj[j][i];
                                                    end
                                                end
                                            end
                                        end
                                        topo_step <= 3'd1;
                                    end
                                    3'd1: begin
                                        // Initialize queue with nodes of in-degree 0
                                        topo_count <= 3'b0;
                                        for (i = 0; i < MAX_NODES; i = i + 1) begin
                                            if (reachable[i] && in_degree[i] == 4'b0) begin
                                                topo_order[topo_count] <= i;
                                                topo_count <= topo_count + 1;
                                            end
                                        end
                                        topo_step <= 3'd2;
                                    end
                                    3'd2: begin
                                        // Process queue (one node per cycle)
                                        if (topo_count > 0) begin
                                            // Get node from queue
                                            node_idx <= topo_order[topo_count - 1];
                                            topo_count <= topo_count - 1;
                                            topo_step <= 3'd3;
                                        end else begin
                                            // Queue empty, check if all reachable nodes processed
                                            topo_step <= 3'd4;
                                        end
                                    end
                                    3'd3: begin
                                        // Process node's neighbors
                                        for (j = 0; j < MAX_NODES; j = j + 1) begin
                                            if (reachable[j] && adj[node_idx][j] != 4'b0) begin
                                                in_degree[j] <= in_degree[j] - adj[node_idx][j];
                                                if (in_degree[j] == adj[node_idx][j]) begin
                                                    topo_order[topo_count] <= j;
                                                    topo_count <= topo_count + 1;
                                                end
                                            end
                                        end
                                        topo_step <= 3'd2;
                                    end
                                    3'd4: begin
                                        // Check for cycles
                                        // Count reachable nodes
                                        node_count <= 3'b0;
                                        for (i = 0; i < MAX_NODES; i = i + 1) begin
                                            if (reachable[i]) begin
                                                node_count <= node_count + 1;
                                            end
                                        end
                                        topo_step <= 3'd5;
                                    end
                                    3'd5: begin
                                        // Compare topo_count with node_count
                                        if (topo_count != node_count) begin
                                            cycle_detected <= 1'b1;
                                        end
                                        topo_done <= 1'b1;
                                    end
                                endcase
                            end
                        end
                        // --- Step 3: DP calculation ---
                        else if (!dp_done && topo_done && bfs_done) begin
                            if (!dp_started) begin
                                // Initialize dp
                                dp[1] <= 64'd1;
                                dp_started <= 1'b1;
                                dp_step <= 3'd0;
                                k_idx <= topo_count;
                            end else begin
                                case (dp_step)
                                    3'd0: begin
                                        // Process nodes in reverse topological order
                                        if (k_idx > 0) begin
                                            k_idx <= k_idx - 1;
                                            node_idx <= topo_order[k_idx - 1];
                                            dp_step <= 3'd1;
                                        end else begin
                                            dp_step <= 3'd3;
                                        end
                                    end
                                    3'd1: begin
                                        // Calculate sum of incoming paths
                                        dp_sum <= 64'b0;
                                        j_idx <= 3'b0;
                                        dp_step <= 3'd2;
                                    end
                                    3'd2: begin
                                        // Loop through all nodes
                                        if (j_idx < MAX_NODES) begin
                                            if (adj[j_idx][node_idx] != 4'b0 && reachable[j_idx]) begin
                                                dp_mul <= adj[j_idx][node_idx] * dp[j_idx];
                                                dp_step <= 3'd4;
                                            end else begin
                                                j_idx <= j_idx + 1;
                                            end
                                        end else begin
                                            // Finish sum for this node
                                            dp[node_idx] <= dp_sum;
                                            dp_step <= 3'd0;
                                        end
                                    end
                                    3'd4: begin
                                        // Add product to sum
                                        dp_sum <= dp_sum + dp_mul;
                                        j_idx <= j_idx + 1;
                                        dp_step <= 3'd2;
                                    end
                                    3'd3: begin
                                        // DP done
                                        dp_done <= 1'b1;
                                    end
                                endcase
                            end
                        end
                        // --- Step 4: Set outputs ---
                        else if (dp_done && topo_done && bfs_done) begin
                            compute_done <= 1'b1;
                            done <= 1'b1;
                            if (cycle_detected) begin
                                inf <= 1'b1;
                                result <= 32'b0;
                            end else begin
                                inf <= 1'b0;
                                if (dp[0] >= MOD) begin
                                    result <= dp[0] % MOD;
                                end else begin
                                    result <= dp[0][31:0];
                                end
                            end
                        end
                    end else begin
                        // Wait for reset or new configuration
                        state <= STATE_IDLE;
                    end
                end

                STATE_DONE: begin
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule