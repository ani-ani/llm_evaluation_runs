module food_review #(
    parameter MAX_N = 5,
    parameter MAX_R = 4,
    parameter MAX_F = 4,
    parameter CLK_PERIOD = 10,
    parameter INF = 16'hFFFF
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] N,          // number of cities (1..MAX_N)
    input wire [2:0] R,          // number of required flights (0..MAX_R)
    input wire [2:0] F,          // number of additional flights (0..MAX_F)
    
    // Required flights
    input wire [2:0] req_src [0:MAX_R-1],
    input wire [2:0] req_dst [0:MAX_R-1],
    input wire [13:0] req_cost [0:MAX_R-1],
    
    // Additional flights
    input wire [2:0] opt_src [0:MAX_F-1],
    input wire [2:0] opt_dst [0:MAX_F-1],
    input wire [13:0] opt_cost [0:MAX_F-1],
    
    output reg [15:0] result,
    output reg done
);

// State definitions
localparam [4:0] S_IDLE       = 5'd0;
localparam [4:0] S_INIT       = 5'd1;
localparam [4:0] S_LOAD_REQ   = 5'd2;
localparam [4:0] S_LOAD_OPT   = 5'd3;
localparam [4:0] S_FLOYD_I    = 5'd4;
localparam [4:0] S_FLOYD_J    = 5'd5;
localparam [4:0] S_FLOYD_K    = 5'd6;
localparam [4:0] S_SUM_REQ    = 5'd7;
localparam [4:0] S_GEN_EDGES  = 5'd8;
localparam [4:0] S_ENUM_START = 5'd9;
localparam [4:0] S_ENUM_CHECK = 5'd10;
localparam [4:0] S_ENUM_NEXT  = 5'd11;
localparam [4:0] S_DONE       = 5'd12;

reg [4:0] state;
reg [4:0] next_state;

// Internal registers - using packed arrays for 2D matrices
reg [15:0] dist [0:MAX_N-1][0:MAX_N-1];
reg [15:0] sum_req;
reg [15:0] min_added;
reg [15:0] added_cost;
reg [9:0] mask;                     // mask for subset of edges
reg [3:0] edge_count;               // number of possible edges M = N*(N-1)/2
reg [2:0] edge_u [0:9];             // list of possible edges (u)
reg [2:0] edge_v [0:9];             // list of possible edges (v)
reg [2:0] deg [0:MAX_N-1];          // degree array for current mask
reg [2:0] visited [0:MAX_N-1];      // for BFS
reg [2:0] queue [0:MAX_N-1];        // simple queue for BFS
reg [2:0] q_head, q_tail;
reg parity_ok;
reg connectivity_ok;

// Loop counters
reg [2:0] idx;                      // index for flights
reg [2:0] edge_idx;                 // index for possible edges
reg [9:0] max_mask;                 // (1 << edge_count) - 1
reg [2:0] i, j, k;                  // Floyd-Warshall counters
reg [2:0] a, b;                     // temp nodes
reg [2:0] u, v;                     // temp nodes for edges
reg [2:0] temp_node;                // temp node for BFS

// Helper to compute min
function [15:0] min2;
    input [15:0] a, b;
    begin
        min2 = (a < b) ? a : b;
    end
endfunction

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        S_IDLE:       if (start) next_state = S_INIT;
        S_INIT:       next_state = S_LOAD_REQ;
        S_LOAD_REQ:   if (idx >= R) next_state = S_LOAD_OPT; else next_state = S_LOAD_REQ;
        S_LOAD_OPT:   if (idx >= F) next_state = S_FLOYD_I; else next_state = S_LOAD_OPT;
        S_FLOYD_I:    next_state = S_FLOYD_J;
        S_FLOYD_J:    next_state = S_FLOYD_K;
        S_FLOYD_K:    if (k < N) next_state = S_FLOYD_K;
                      else if (j < N) next_state = S_FLOYD_J;
                      else if (i < N) next_state = S_FLOYD_I;
                      else next_state = S_SUM_REQ;
        S_SUM_REQ:    next_state = S_GEN_EDGES;
        S_GEN_EDGES:  if (edge_idx >= edge_count) next_state = S_ENUM_START; else next_state = S_GEN_EDGES;
        S_ENUM_START: next_state = S_ENUM_CHECK;
        S_ENUM_CHECK: next_state = S_ENUM_NEXT;
        S_ENUM_NEXT:  if (mask >= max_mask) next_state = S_DONE; else next_state = S_ENUM_CHECK;
        S_DONE:       next_state = S_DONE;
        default:      next_state = S_IDLE;
    endcase
end

// Datapath
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        result <= 16'd0;
        done <= 1'b0;
        sum_req <= 16'd0;
        min_added <= INF;
        mask <= 10'd0;
        edge_count <= 4'd0;
        idx <= 3'd0;
        edge_idx <= 3'd0;
        i <= 3'd0; j <= 3'd0; k <= 3'd0;
        parity_ok <= 1'b0;
        connectivity_ok <= 1'b0;
        q_head <= 3'd0; q_tail <= 3'd0;
        added_cost <= 16'd0;
        temp_node <= 3'd0;
    end else begin
        case (state)
            S_INIT: begin
                // Initialize distance matrix
                for (integer x = 0; x < MAX_N; x = x + 1) begin
                    for (integer y = 0; y < MAX_N; y = y + 1) begin
                        dist[x][y] <= INF;
                    end
                end
                // Set diagonal to 0
                for (integer x = 0; x < MAX_N; x = x + 1) begin
                    dist[x][x] <= 16'd0;
                end
                idx <= 3'd0;
                sum_req <= 16'd0;
                min_added <= INF;
            end
            S_LOAD_REQ: begin
                if (idx < R) begin
                    // Update distance matrix with min cost
                    a <= req_src[idx] - 3'd1;  // convert to 0-based
                    b <= req_dst[idx] - 3'd1;
                    if (req_cost[idx] < dist[req_src[idx] - 3'd1][req_dst[idx] - 3'd1]) begin
                        dist[req_src[idx] - 3'd1][req_dst[idx] - 3'd1] <= req_cost[idx];
                        dist[req_dst[idx] - 3'd1][req_src[idx] - 3'd1] <= req_cost[idx];
                    end
                    // Accumulate sum_req
                    sum_req <= sum_req + req_cost[idx];
                    idx <= idx + 3'd1;
                end
            end
            S_LOAD_OPT: begin
                if (idx < F) begin
                    // Update distance matrix with min cost
                    if (opt_cost[idx] < dist[opt_src[idx] - 3'd1][opt_dst[idx] - 3'd1]) begin
                        dist[opt_src[idx] - 3'd1][opt_dst[idx] - 3'd1] <= opt_cost[idx];
                        dist[opt_dst[idx] - 3'd1][opt_src[idx] - 3'd1] <= opt_cost[idx];
                    end
                    idx <= idx + 3'd1;
                end
            end
            S_FLOYD_I: begin
                i <= 3'd0;
            end
            S_FLOYD_J: begin
                if (i < N) begin
                    j <= 3'd0;
                end
            end
            S_FLOYD_K: begin
                if (j < N) begin
                    // Run Floyd-Warshall step for current (i, j, k)
                    // We need to iterate k inside this state
                    // For this implementation, we process k in a single cycle
                    for (k = 3'd0; k < N; k = k + 3'd1) begin
                        if (dist[i][j] > dist[i][k] + dist[k][j]) begin
                            dist[i][j] <= dist[i][k] + dist[k][j];
                        end
                    end
                    j <= j + 3'd1;
                end else if (i < N) begin
                    i <= i + 3'd1;
                end
            end
            S_SUM_REQ: begin
                // sum_req already computed, prepare for edge generation
                edge_idx <= 3'd0;
                edge_count <= 4'd0;
            end
            S_GEN_EDGES: begin
                // Generate all possible edges (i, j) where i < j and dist[i][j] != INF
                // We iterate through all pairs (i, j) to find valid edges
                // This is done incrementally using i and j as state
                if (edge_idx < edge_count) begin
                    // This state is used to fill edge_u and edge_v arrays
                    // We need to iterate through all i, j pairs
                    // For simplicity, we'll generate edges in this single cycle
                    // by precomputing them, but for synthesis we need iteration.
                    // Let's use a nested loop structure with state variables.
                    // We'll generate edges in one cycle using for-loops.
                    edge_count <= 0;
                    for (i = 3'd0; i < N; i = i + 3'd1) begin
                        for (j = 3'd1; j < N; j = j + 3'd1) begin
                            if (i < j) begin
                                if (dist[i][j] < INF) begin
                                    edge_u[edge_count] <= i;
                                    edge_v[edge_count] <= j;
                                    edge_count <= edge_count + 4'd1;
                                end
                            end
                        end
                    end
                    edge_idx <= edge_count; // Mark as done
                end
            end
            S_ENUM_START: begin
                mask <= 10'd0;
                max_mask <= (edge_count == 0) ? 10'd0 : (10'd1 << edge_count) - 10'd1;
            end
            S_ENUM_CHECK: begin
                // Compute degrees and added cost for current mask
                // Reset degrees
                for (integer x = 0; x < MAX_N; x = x + 1) deg[x] <= 3'd0;
                added_cost <= 16'd0;
                
                // Add required edges to degrees (already accounted in dist matrix)
                // But for parity check, we need explicit degree count from required flights
                // Let's compute required degrees from req_src/req_dst
                for (integer x = 0; x < MAX_R; x = x + 1) begin
                    if (x < R) begin
                        deg[req_src[x] - 3'd1] <= deg[req_src[x] - 3'd1] + 3'd1;
                        deg[req_dst[x] - 3'd1] <= deg[req_dst[x] - 3'd1] + 3'd1;
                    end
                end
                
                // Add edges from mask
                for (integer e = 0; e < 10; e = e + 1) begin
                    if (e < edge_count) begin
                        if (mask[e]) begin
                            deg[edge_u[e]] <= deg[edge_u[e]] + 3'd1;
                            deg[edge_v[e]] <= deg[edge_v[e]] + 3'd1;
                            added_cost <= added_cost + dist[edge_u[e]][edge_v[e]];
                        end
                    end
                end
                
                // Check parity (all degrees even)
                parity_ok <= 1'b1;
                for (integer x = 0; x < MAX_N; x = x + 1) begin
                    if (x < N) begin
                        if (deg[x][0] == 1'b1) parity_ok <= 1'b0; // Check LSB for odd
                    end
                end
                
                // Check connectivity via BFS
                // Initialize visited
                for (integer x = 0; x < MAX_N; x = x + 1) visited[x] <= 3'd0;
                q_head <= 3'd0; q_tail <= 3'd0;
                
                // BFS setup - we'll do BFS in separate states or in this cycle if small
                // Since N <= 5, we can do BFS in one cycle
                visited[0] <= 3'd1;
                queue[0] <= 3'd0;
                q_tail <= 3'd1;
                
                // BFS loop - iterate until queue empty
                for (integer q_idx = 0; q_idx < 5; q_idx = q_idx + 1) begin
                    if (q_idx < q_tail) begin
                        temp_node <= queue[q_idx];
                        // Check neighbors
                        for (integer neighbor = 0; neighbor < 5; neighbor = neighbor + 1) begin
                            if (neighbor < N) begin
                                if (dist[temp_node][neighbor] < INF && visited[neighbor] == 3'd0) begin
                                    visited[neighbor] <= 3'd1;
                                    queue[q_tail] <= neighbor;
                                    q_tail <= q_tail + 3'd1;
                                end
                            end
                        end
                    end
                end
                
                // Check connectivity
                connectivity_ok <= 1'b1;
                for (integer x = 0; x < MAX_N; x = x + 1) begin
                    if (x < N) begin
                        if (visited[x] == 3'd0) connectivity_ok <= 1'b0;
                    end
                end
            end
            S_ENUM_NEXT: begin
                if (parity_ok && connectivity_ok && (added_cost < min_added)) begin
                    min_added <= added_cost;
                end
                mask <= mask + 10'd1;
            end
            S_DONE: begin
                result <= sum_req + min_added;
                done <= 1'b1;
            end
        endcase
    end
end

endmodule