module ticket_to_ride_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [3:0] m,
    input wire edge_valid,
    input wire [2:0] edge_u,
    input wire [2:0] edge_v,
    input wire [15:0] edge_cost,
    input wire assignment_valid,
    input wire [2:0] assign_u,
    input wire [2:0] assign_v,
    output reg [15:0] result,
    output reg done
);

// State machine states
localparam [2:0] S_IDLE = 3'd0;
localparam [2:0] S_LOAD_EDGES = 3'd1;
localparam [2:0] S_LOAD_ASSIGNMENTS = 3'd2;
localparam [2:0] S_COMPUTE = 3'd3;
localparam [2:0] S_DONE = 3'd4;

reg [2:0] state;

// Distance matrix for Floyd-Warshall
reg [15:0] dist [0:7][0:7];

// Counters for edge and assignment loading
reg [2:0] edges_count;
reg [2:0] assign_count;

// Storage for assignment pairs
reg [2:0] pairs [0:7];

// Counters for Floyd-Warshall algorithm
reg [2:0] i, j, k;

// Counters for Steiner tree computation
reg [3:0] mask, submask;
reg [15:0] dp [0:15][0:7];
reg [15:0] steiner_cost [0:15];
reg [15:0] min_val;

// Initialize distance matrix
integer row, col;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (row = 0; row < 8; row = row + 1) begin
            for (col = 0; col < 8; col = col + 1) begin
                dist[row][col] <= (row == col) ? 16'd0 : 16'hFFFF;
            end
        end
    end
end

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 1'b0;
        result <= 16'd0;
        edges_count <= 3'd0;
        assign_count <= 3'd0;
        i <= 3'd0;
        j <= 3'd0;
        k <= 3'd0;
        mask <= 4'd0;
        submask <= 4'd0;
    end else begin
        case (state)
            S_IDLE: begin
                if (start) begin
                    state <= S_LOAD_EDGES;
                    edges_count <= 3'd0;
                    assign_count <= 3'd0;
                    done <= 1'b0;
                end
            end
            
            S_LOAD_EDGES: begin
                if (edge_valid && edges_count < m) begin
                    // Update distance matrix with minimum cost
                    if (edge_cost < dist[edge_u][edge_v]) begin
                        dist[edge_u][edge_v] <= edge_cost;
                        dist[edge_v][edge_u] <= edge_cost;
                    end
                    edges_count <= edges_count + 3'd1;
                end else if (edges_count == m) begin
                    state <= S_LOAD_ASSIGNMENTS;
                end
            end
            
            S_LOAD_ASSIGNMENTS: begin
                if (assignment_valid && assign_count < 4) begin
                    pairs[assign_count*2] <= assign_u;
                    pairs[assign_count*2+1] <= assign_v;
                    assign_count <= assign_count + 3'd1;
                end else if (assign_count == 4) begin
                    state <= S_COMPUTE;
                    i <= 3'd0;
                    j <= 3'd0;
                    k <= 3'd0;
                end
            end
            
            S_COMPUTE: begin
                // Floyd-Warshall algorithm
                if (i < n) begin
                    if (j < n) begin
                        if (k < n) begin
                            // Relaxation step
                            if (dist[i][k] + dist[k][j] < dist[i][j]) begin
                                dist[i][j] <= dist[i][k] + dist[k][j];
                            end
                            k <= k + 3'd1;
                        end else begin
                            k <= 3'd0;
                            j <= j + 3'd1;
                        end
                    end else begin
                        j <= 3'd0;
                        i <= i + 3'd1;
                    end
                end else begin
                    // Steiner tree computation
                    if (mask < 16) begin
                        if (mask == 0) begin
                            steiner_cost[mask] <= 16'd0;
                            mask <= mask + 4'd1;
                        end else begin
                            if (submask == 0) begin
                                // Initialize dp for this mask
                                for (i = 0; i < 8; i = i + 1) begin
                                    dp[mask][i] <= 16'hFFFF;
                                end
                                // Set terminals in mask to 0 cost at their vertices
                                for (k = 0; k < 4; k = k + 1) begin
                                    if (mask[k] && pairs[k*2] == pairs[k*2+1]) begin
                                        dp[mask][pairs[k*2]] <= 16'd0;
                                    end
                                end
                                submask <= submask + 4'd1;
                            end else if (submask < mask) begin
                                // Combine submasks
                                if (submask != 0 && (submask & (mask - submask)) != 0) begin
                                    for (i = 0; i < 8; i = i + 1) begin
                                        if (dp[submask][i] + dp[mask - submask][i] < dp[mask][i]) begin
                                            dp[mask][i] <= dp[submask][i] + dp[mask - submask][i];
                                        end
                                    end
                                end
                                submask <= submask + 4'd1;
                            end else begin
                                // Relaxation using Floyd-Warshall distances
                                for (i = 0; i < n; i = i + 1) begin
                                    for (j = 0; j < n; j = j + 1) begin
                                        if (dp[mask][i] + dist[i][j] < dp[mask][j]) begin
                                            dp[mask][j] <= dp[mask][i] + dist[i][j];
                                        end
                                    end
                                end
                                // Compute steiner_cost[mask] = min(dp[mask][v])
                                min_val <= 16'hFFFF;
                                for (i = 0; i < n; i = i + 1) begin
                                    if (dp[mask][i] < min_val) begin
                                        min_val <= dp[mask][i];
                                    end
                                end
                                steiner_cost[mask] <= min_val;
                                mask <= mask + 4'd1;
                                submask <= 4'd0;
                            end
                        end
                    end else begin
                        // Compute result as the cost for all terminals
                        result <= steiner_cost[15];
                        state <= S_DONE;
                        done <= 1'b1;
                    end
                end
            end
            
            S_DONE: begin
                done <= 1'b1;
            end
            
            default: state <= S_IDLE;
        endcase
    end
end

endmodule