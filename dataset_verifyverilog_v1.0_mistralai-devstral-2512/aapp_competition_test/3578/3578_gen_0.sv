module SteinerTSP(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_nodes,
    input wire [3:0] num_req_nodes,
    input wire [7:0] req_nodes_mask,
    input wire [15:0] dist_matrix [0:63],
    input wire [3:0] req_node_list [0:7],
    output reg [15:0] min_cost,
    output reg done
);

    // State definitions
    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_FLOYD = 3'd1;
    localparam [2:0] S_DP = 3'd2;
    localparam [2:0] S_FINAL = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [15:0] dp [0:255]; // dp[mask][node] for 8 nodes
    reg [15:0] dist [0:7][0:7];
    reg [7:0] mask;
    reg [2:0] u;
    reg [2:0] v;
    reg [2:0] k;
    reg [7:0] cycle_count;
    reg [15:0] current_min;
    reg [2:0] current_node;

    // Constants
    localparam [7:0] MAX_CYCLES = 8'd200;
    localparam [15:0] INF = 16'hFFFF;

    // Initialize state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            min_cost <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize DP table
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                dp[i] <= INF;
            end
            
            // Initialize distance matrix
            integer j;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    dist[i][j] <= INF;
                end
            end
            
            // Set diagonal to 0
            for (i = 0; i < 8; i = i + 1) begin
                dist[i][i] <= 16'd0;
            end
            
            // Load input distance matrix
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    dist[i][j] <= dist_matrix[i * 8 + j];
                end
            end
            
            u <= 3'd0;
            v <= 3'd0;
            k <= 3'd0;
            mask <= 8'd0;
            current_min <= INF;
            current_node <= 3'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= S_FLOYD;
                        cycle_count <= 8'd0;
                    end
                end

                S_FLOYD: begin
                    // Floyd-Warshall algorithm
                    if (cycle_count < 8'd512) begin // 8^3 iterations
                        // Calculate indices
                        k <= cycle_count[8:6];
                        u <= cycle_count[5:3];
                        v <= cycle_count[2:0];
                        
                        // Update distance
                        if (dist[u][k] + dist[k][v] < dist[u][v]) begin
                            dist[u][v] <= dist[u][k] + dist[k][v];
                        end
                        
                        cycle_count <= cycle_count + 8'd1;
                    end else begin
                        state <= S_DP;
                        cycle_count <= 8'd0;
                        
                        // Initialize DP: start at node 0 (Stockholm)
                        dp[0] <= 16'd0;
                        
                        // Set mask to include node 0
                        mask <= 8'd1;
                    end
                end

                S_DP: begin
                    if (cycle_count < 8'd2040) begin // 255 masks * 8 nodes
                        // Calculate current mask and node
                        mask <= cycle_count[11:4];
                        u <= cycle_count[3:0];
                        
                        // Only process if current state is valid
                        if (dp[mask * 8 + u] != INF) begin
                            // Try to visit all unvisited required nodes
                            integer i;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (req_nodes_mask[i] && !(mask[i])) begin
                                    // Calculate new mask
                                    reg [7:0] new_mask;
                                    new_mask <= mask | (1 << i);
                                    
                                    // Calculate new cost
                                    reg [15:0] new_cost;
                                    new_cost <= dp[mask * 8 + u] + dist[u][i];
                                    
                                    // Update DP if better
                                    if (new_cost < dp[new_mask * 8 + i]) begin
                                        dp[new_mask * 8 + i] <= new_cost;
                                    end
                                end
                            end
                        end
                        
                        cycle_count <= cycle_count + 8'd1;
                    end else begin
                        state <= S_FINAL;
                        cycle_count <= 8'd0;
                        current_min <= INF;
                        current_node <= 3'd0;
                    end
                end

                S_FINAL: begin
                    if (cycle_count < 8'd8) begin
                        // Check all nodes for return to Stockholm (node 0)
                        current_node <= cycle_count;
                        
                        // Full mask (all required nodes visited)
                        reg [7:0] full_mask;
                        full_mask <= req_nodes_mask;
                        
                        // Calculate total cost including return
                        reg [15:0] total_cost;
                        total_cost <= dp[full_mask * 8 + current_node] + dist[current_node][0];
                        
                        // Update minimum
                        if (total_cost < current_min) begin
                            current_min <= total_cost;
                        end
                        
                        cycle_count <= cycle_count + 8'd1;
                    end else begin
                        min_cost <= current_min;
                        done <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule