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
    localparam [1:0] STATE_IDLE    = 2'd0;
    localparam [1:0] STATE_CONFIG  = 2'd1;
    localparam [1:0] STATE_COMPUTE = 2'd2;
    localparam [1:0] STATE_DONE    = 2'd3;
    
    reg [1:0] state;
    
    // Adjacency matrix
    reg [3:0] adj [0:MAX_NODES-1][0:MAX_NODES-1];
    
    // Computation registers
    reg [7:0] reachable;
    reg [3:0] in_degree [0:MAX_NODES-1];
    reg [2:0] topo_order [0:MAX_NODES-1];
    reg [2:0] topo_count;
    reg [63:0] dp [0:MAX_NODES-1];
    reg [3:0] node_idx;
    
    // Control flags
    reg compute_done;
    reg cycle_detected;
    
    // Loop variables (synthesis will unroll)
    integer i, j, k, m;
    
    // Kahn's algorithm queue
    reg [2:0] queue [0:MAX_NODES-1];
    reg [2:0] queue_read_ptr;
    reg [2:0] queue_write_ptr;
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            done <= 1'b0;
            inf <= 1'b0;
            result <= 32'd0;
            
            for (i = 0; i < MAX_NODES; i = i + 1) begin
                for (j = 0; j < MAX_NODES; j = j + 1) begin
                    adj[i][j] <= 4'd0;
                end
                in_degree[i] <= 4'd0;
                dp[i] <= 64'd0;
            end
            
            reachable <= 8'd0;
            topo_count <= 3'd0;
            compute_done <= 1'b0;
            cycle_detected <= 1'b0;
            queue_read_ptr <= 3'd0;
            queue_write_ptr <= 3'd0;
            node_idx <= 3'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    inf <= 1'b0;
                    
                    if (graph_write_en) begin
                        if (cnt != 4'd0) begin
                            adj[src][dst] <= cnt;
                        end
                        state <= STATE_CONFIG;
                    end else if (start) begin
                        state <= STATE_COMPUTE;
                        reachable <= 8'd0;
                        topo_count <= 3'd0;
                        compute_done <= 1'b0;
                        cycle_detected <= 1'b0;
                        
                        // Initialize in_degree
                        for (i = 0; i < MAX_NODES; i = i + 1) begin
                            in_degree[i] <= 4'd0;
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
                        // Step 1: BFS to find reachable nodes
                        if (reachable == 8'd0) begin
                            reachable <= 8'b00000001;
                            // First pass - just mark node 0 as reachable
                        end else begin
                            // Propagate reachability
                            for (i = 0; i < MAX_NODES; i = i + 1) begin
                                if (reachable[i]) begin
                                    for (j = 0; j < MAX_NODES; j = j + 1) begin
                                        if (adj[i][j] != 4'd0 && !reachable[j]) begin
                                            reachable[j] <= 1'b1;
                                        end
                                    end
                                end
                            end
                        end
                        
                        // Step 2: Compute in-degrees for reachable nodes
                        for (i = 0; i < MAX_NODES; i = i + 1) begin
                            if (reachable[i]) begin
                                for (j = 0; j < MAX_NODES; j = j + 1) begin
                                    if (reachable[j] && adj[j][i] != 4'd0) begin
                                        in_degree[i] <= in_degree[i] + adj[j][i];
                                    end
                                end
                            end
                        end
                        
                        // Step 3: Kahn's algorithm for topological sort
                        queue_write_ptr <= 3'd0;
                        for (i = 0; i < MAX_NODES; i = i + 1) begin
                            if (reachable[i] && (in_degree[i] == 4'd0)) begin
                                queue[queue_write_ptr] <= i;
                                queue_write_ptr <= queue_write_ptr + 1;
                            end
                        end
                        
                        topo_count <= 3'd0;
                        while (queue_read_ptr < queue_write_ptr) begin
                            node_idx <= queue[queue_read_ptr];
                            queue_read_ptr <= queue_read_ptr + 1;
                            topo_order[topo_count] <= node_idx;
                            topo_count <= topo_count + 1;
                            
                            // Reduce in-degree of neighbors
                            for (j = 0; j < MAX_NODES; j = j + 1) begin
                                if (reachable[j] && adj[node_idx][j] != 4'd0) begin
                                    in_degree[j] <= in_degree[j] - adj[node_idx][j];
                                    
                                    if (in_degree[j] == 4'd0) begin
                                        queue[queue_write_ptr] <= j;
                                        queue_write_ptr <= queue_write_ptr + 1;
                                    end
                                end
                            end
                        end
                        
                        // Cycle detection
                        if (topo_count < $countones(reachable)) begin
                            cycle_detected <= 1'b1;
                        end
                        
                        // Step 4: Dynamic programming
                        if (cycle_detected) begin
                            inf <= 1'b1;
                        end else begin
                            // Reset DP array
                            for (i = 0; i < MAX_NODES; i = i + 1) begin
                                dp[i] <= 64'd0;
                            end
                            dp[1] <= 64'd1;
                            
                            // Process in reverse order
                            for (m = topo_count - 1; m >= 0; m = m - 1) begin
                                node_idx = topo_order[m];
                                for (k = 0; k < MAX_NODES; k = k + 1) begin
                                    if (adj[node_idx][k] != 4'd0 && reachable[k]) begin
                                        dp[node_idx] <= dp[node_idx] + adj[node_idx][k] * dp[k];
                                    end
                                end
                            end
                        end
                        
                        compute_done <= 1'b1;
                    end else begin
                        if (cycle_detected) begin
                            inf <= 1'b1;
                            result <= 32'd0;
                        end else begin
                            inf <= 1'b0;
                            result <= dp[0] >= MOD ? (dp[0] % MOD) : dp[0][31:0];
                        end
                        done <= 1'b1;
                        state <= STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    done <= 1'b0;
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end
endmodule