module network_cost_minimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] M,
    input wire [3:0] edge_u,
    input wire [3:0] edge_v,
    input wire tree_sel,
    input wire edge_valid,
    output reg [31:0] result,
    output reg done,
    output reg ready
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] WAIT_EDGES    = 4'd1;
    localparam [3:0] BUILD_A       = 4'd2;
    localparam [3:0] BUILD_B       = 4'd3;
    localparam [3:0] DIST_A_ROOT   = 4'd4;
    localparam [3:0] DIST_A_CALCS  = 4'd5;
    localparam [3:0] DIST_B_ROOT   = 4'd6;
    localparam [3:0] DIST_B_CALCS  = 4'd7;
    localparam [3:0] INTERNAL_COST = 4'd8;
    localparam [3:0] CROSS_COST    = 4'd9;
    localparam [3:0] FINISH        = 4'd10;

    reg [3:0] state, next_state;
    
    // Edge storage
    reg [3:0] edge_u_reg, edge_v_reg;
    reg tree_sel_reg;
    reg edge_valid_reg;
    
    // Tree structures (12 nodes max, 0-indexed)
    reg [3:0] adj_A [0:11];  // Adjacency list for A: adj_A[i] stores neighbor
    reg [3:0] adj_B [0:11];  // Adjacency list for B
    reg [3:0] deg_A [0:11];  // Degree count
    reg [3:0] deg_B [0:11];
    reg [3:0] edges_A_count, edges_B_count;
    
    // BFS/DFS structures
    reg [3:0] node_queue [0:11];
    reg [3:0] q_head, q_tail;
    reg [3:0] dist [0:11];
    reg [3:0] sub_size [0:11];
    reg visited [0:11];
    
    // Computation registers
    reg [31:0] internal_cost_A;
    reg [31:0] internal_cost_B;
    reg [31:0] cross_term_acc;
    reg [31:0] final_result;
    
    // Iteration counters
    reg [3:0] i, j, k, neighbor;
    reg [31:0] sum_sq, temp_val;
    reg [31:0] temp_dist_sq;
    
    // State transition and control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b1;
            done <= 1'b0;
            result <= 32'd0;
            edges_A_count <= 4'd0;
            edges_B_count <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            q_head <= 4'd0;
            q_tail <= 4'd0;
            internal_cost_A <= 32'd0;
            internal_cost_B <= 32'd0;
            cross_term_acc <= 32'd0;
            final_result <= 32'd0;
            edge_valid_reg <= 1'b0;
            // Initialize arrays
            for (i = 0; i < 12; i = i + 1) begin
                adj_A[i] <= 4'd0;
                adj_B[i] <= 4'd0;
                deg_A[i] <= 4'd0;
                deg_B[i] <= 4'd0;
                dist[i] <= 4'd0;
                sub_size[i] <= 4'd0;
                visited[i] <= 1'b0;
            end
            i <= 4'd0;
        end else begin
            edge_valid_reg <= edge_valid;
            state <= next_state;
            
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    edges_A_count <= 4'd0;
                    edges_B_count <= 4'd0;
                    for (i = 0; i < 12; i = i + 1) begin
                        adj_A[i] <= 4'd0;
                        adj_B[i] <= 4'd0;
                        deg_A[i] <= 4'd0;
                        deg_B[i] <= 4'd0;
                    end
                end
                
                WAIT_EDGES: begin
                    ready <= 1'b0;
                    if (edge_valid && !edge_valid_reg) begin
                        edge_u_reg <= edge_u - 4'd1;
                        edge_v_reg <= edge_v - 4'd1;
                        tree_sel_reg <= tree_sel;
                    end
                end
                
                BUILD_A: begin
                    if (edge_valid_reg && tree_sel_reg == 1'b0) begin
                        // Store edge for A
                        if (deg_A[edge_u_reg] < 4'd12) begin
                            adj_A[edge_u_reg * 12 + deg_A[edge_u_reg]] <= edge_v_reg;
                            deg_A[edge_u_reg] <= deg_A[edge_u_reg] + 4'd1;
                        end
                        if (deg_A[edge_v_reg] < 4'd12) begin
                            adj_A[edge_v_reg * 12 + deg_A[edge_v_reg]] <= edge_u_reg;
                            deg_A[edge_v_reg] <= deg_A[edge_v_reg] + 4'd1;
                        end
                        edges_A_count <= edges_A_count + 4'd1;
                    end
                end
                
                BUILD_B: begin
                    if (edge_valid_reg && tree_sel_reg == 1'b1) begin
                        // Store edge for B
                        if (deg_B[edge_u_reg] < 4'd12) begin
                            adj_B[edge_u_reg * 12 + deg_B[edge_u_reg]] <= edge_v_reg;
                            deg_B[edge_u_reg] <= deg_B[edge_u_reg] + 4'd1;
                        end
                        if (deg_B[edge_v_reg] < 4'd12) begin
                            adj_B[edge_v_reg * 12 + deg_B[edge_v_reg]] <= edge_u_reg;
                            deg_B[edge_v_reg] <= deg_B[edge_v_reg] + 4'd1;
                        end
                        edges_B_count <= edges_B_count + 4'd1;
                    end
                end
                
                DIST_A_ROOT: begin
                    // BFS from node 0 for Tree A
                    if (i < N) begin
                        visited[i] <= 1'b0;
                        dist[i] <= 4'd0;
                    end else begin
                        visited[0] <= 1'b1;
                        dist[0] <= 4'd0;
                        node_queue[0] <= 4'd0;
                        q_head <= 4'd0;
                        q_tail <= 4'd1;
                        i <= 4'd0;
                    end
                end
                
                DIST_A_CALCS: begin
                    if (q_head < q_tail && q_tail <= 4'd12) begin
                        // Pop node
                        i <= node_queue[q_head];
                        q_head <= q_head + 4'd1;
                    end else if (q_head < q_tail) begin
                        // Process neighbor
                        if (j < deg_A[i]) begin
                            neighbor <= adj_A[i * 12 + j];
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                        end
                    end else begin
                        // BFS done
                        q_head <= 4'd0;
                        q_tail <= 4'd0;
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                    end
                    
                    // BFS neighbor processing
                    if (j < deg_A[i]) begin
                        if (!visited[neighbor]) begin
                            visited[neighbor] <= 1'b1;
                            dist[neighbor] <= dist[i] + 4'd1;
                            node_queue[q_tail] <= neighbor;
                            q_tail <= q_tail + 4'd1;
                        end
                    end
                end
                
                DIST_B_ROOT: begin
                    // BFS from node 0 for Tree B
                    if (i < M) begin
                        visited[i] <= 1'b0;
                        dist[i] <= 4'd0;
                    end else begin
                        visited[0] <= 1'b1;
                        dist[0] <= 4'd0;
                        node_queue[0] <= 4'd0;
                        q_head <= 4'd0;
                        q_tail <= 4'd1;
                        i <= 4'd0;
                    end
                end
                
                DIST_B_CALCS: begin
                    if (q_head < q_tail && q_tail <= 4'd12) begin
                        // Pop node
                        i <= node_queue[q_head];
                        q_head <= q_head + 4'd1;
                    end else if (q_head < q_tail) begin
                        // Process neighbor
                        if (j < deg_B[i]) begin
                            neighbor <= adj_B[i * 12 + j];
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                        end
                    end else begin
                        // BFS done
                        q_head <= 4'd0;
                        q_tail <= 4'd0;
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                    end
                    
                    // BFS neighbor processing
                    if (j < deg_B[i]) begin
                        if (!visited[neighbor]) begin
                            visited[neighbor] <= 1'b1;
                            dist[neighbor] <= dist[i] + 4'd1;
                            node_queue[q_tail] <= neighbor;
                            q_tail <= q_tail + 4'd1;
                        end
                    end
                end
                
                INTERNAL_COST: begin
                    // Compute internal cost for current tree
                    // Using formula: 2 * sum_{edges} size_subtree * (N - size_subtree)
                    // But we need to find subtree sizes first
                    // Simplified: Sum of dist^2 = 2 * sum_{edges} sz * (N - sz)
                    // We'll compute sz via DFS
                    if (i < N && j == 0) begin
                        // Initialize visited for DFS
                        visited[i] <= 1'b0;
                        sub_size[i] <= 4'd0;
                    end else if (i < N && j == 1) begin
                        // Run DFS to compute sizes
                        // For this implementation, we use a simple iterative approach
                        // Sum of squared distances calculation
                        if (k < deg_A[i]) begin
                            neighbor <= adj_A[i * 12 + k];
                            k <= k + 4'd1;
                            // Edge from i to neighbor
                            // Estimate: dist contribution
                            temp_val <= dist[neighbor] + dist[i];
                            sum_sq <= sum_sq + temp_val * temp_val;
                        end else begin
                            k <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        sum_sq <= sum_sq >> 1; // Adjust formula
                        internal_cost_A <= sum_sq;
                        i <= 4'd0;
                        j <= 0;
                        k <= 4'd0;
                        sum_sq <= 32'd0;
                        // For B
                        if (j == 0) begin
                            j <= 1;
                            i <= 4'd0;
                        end else begin
                            internal_cost_B <= sum_sq;
                        end
                    end
                    // Correction: Direct distance sum of squares
                    // Sum_{u,v} dist^2 = 2 * sum_{edges} size * (total - size)
                    // We need to compute subtree sizes from leaves up
                    // This part is complex; we use a simpler iteration over all pairs
                    if (i < N && k < N) begin
                        temp_dist_sq <= (dist[i] + dist[k]) * (dist[i] + dist[k]);
                        sum_sq <= sum_sq + temp_dist_sq;
                        if (k == N - 1) begin
                            k <= 4'd0;
                            i <= i + 4'd1;
                        end else begin
                            k <= k + 4'd1;
                        end
                    end else if (i < N) begin
                        k <= 4'd0;
                        i <= i + 4'd1;
                    end else begin
                        // Sum of squared distances counts pairs twice, divide by 2
                        internal_cost_A <= sum_sq >> 1;
                        // Reset for B
                        i <= 4'd0;
                        j <= 1;
                        sum_sq <= 32'd0;
                    end
                end
                
                CROSS_COST: begin
                    // Compute cross term
                    // For each a in A (0 to N-1), sum over b in B: (dist_A[a] + 1 + dist_B[b])^2
                    // Minimized by picking appropriate b
                    // We iterate all b to find min sum
                    if (i < N) begin
                        // For node i in A
                        if (j < M) begin
                            temp_val <= dist[i] + 1 + dist[j];
                            sum_sq <= sum_sq + temp_val * temp_val;
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            cross_term_acc <= cross_term_acc + sum_sq;
                            i <= i + 4'd1;
                            sum_sq <= 32'd0;
                        end
                    end else begin
                        final_result <= internal_cost_A + internal_cost_B + cross_term_acc;
                    end
                end
                
                FINISH: begin
                    result <= final_result;
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = (start) ? WAIT_EDGES : IDLE;
            
            WAIT_EDGES: begin
                if (N == 4'd0 && M == 4'd0) next_state = DIST_A_ROOT;
                else if (N > 4'd0 && M > 4'd0) next_state = BUILD_A;
                else next_state = WAIT_EDGES;
            end
            
            BUILD_A: begin
                if (edges_A_count == N - 4'd1 || (N == 4'd1 && edges_A_count == 0)) begin
                    if (M == 4'd0) next_state = DIST_A_ROOT;
                    else next_state = BUILD_B;
                end else next_state = WAIT_EDGES;
            end
            
            BUILD_B: begin
                if (edges_B_count == M - 4'd1 || (M == 4'd1 && edges_B_count == 0)) begin
                    next_state = DIST_A_ROOT;
                end else next_state = WAIT_EDGES;
            end
            
            DIST_A_ROOT: next_state = DIST_A_CALCS;
            
            DIST_A_CALCS: begin
                if (q_head >= q_tail && j >= 4'd12) next_state = DIST_B_ROOT;
                else next_state = DIST_A_CALCS;
            end
            
            DIST_B_ROOT: next_state = DIST_B_CALCS;
            
            DIST_B_CALCS: begin
                if (q_head >= q_tail && j >= 4'd12) next_state = INTERNAL_COST;
                else next_state = DIST_B_CALCS;
            end
            
            INTERNAL_COST: begin
                if (i >= N && j == 1) next_state = CROSS_COST;
                else if (i >= N && j == 0) next_state = DIST_B_ROOT; // Wait, logic fix
                else next_state = INTERNAL_COST;
            end
            
            CROSS_COST: begin
                if (i >= N) next_state = FINISH;
                else next_state = CROSS_COST;
            end
            
            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

endmodule