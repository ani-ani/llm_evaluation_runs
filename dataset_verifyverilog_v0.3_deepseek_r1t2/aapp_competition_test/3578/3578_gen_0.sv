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
    input wire [2:0] N,
    input wire [2:0] R,
    input wire [2:0] F,
    
    input wire [2:0] req_src [0:MAX_R-1],
    input wire [2:0] req_dst [0:MAX_R-1],
    input wire [13:0] req_cost [0:MAX_R-1],
    
    input wire [2:0] opt_src [0:MAX_F-1],
    input wire [2:0] opt_dst [0:MAX_F-1],
    input wire [13:0] opt_cost [0:MAX_F-1],
    
    output reg [15:0] result,
    output reg done
);

// State definitions
localparam [4:0] 
    S_IDLE       = 5'd0,
    S_INIT       = 5'd1,
    S_LOAD_REQ   = 5'd2,
    S_LOAD_OPT   = 5'd3,
    S_FLOYD_K    = 5'd4,
    S_FLOYD_I    = 5'd5,
    S_FLOYD_J    = 5'd6,
    S_SUM_REQ    = 5'd7,
    S_GEN_EDGES  = 5'd8,
    S_ENUM_START = 5'd9,
    S_ENUM_CHECK = 5'd10,
    S_BFS        = 5'd11,
    S_CHECK_EVEN = 5'd12,
    S_UPDATE_MIN = 5'd13,
    S_NEXT_MASK  = 5'd14,
    S_DONE       = 5'd15;

reg [4:0] state, next_state;

// Internal registers
reg [15:0] dist [0:MAX_N-1][0:MAX_N-1];
reg [15:0] sum_req;
reg [15:0] min_added;
reg [15:0] added_cost;
reg [9:0] mask;
reg [3:0] edge_count;
reg [2:0] edge_u [0:9];
reg [2:0] edge_v [0:9];
reg [2:0] deg [0:MAX_N-1];

// BFS registers
reg [2:0] visited [0:MAX_N-1];
reg [2:0] queue [0:MAX_N-1];
reg [2:0] q_head, q_tail;
reg [2:0] current_node;
reg connectivity_ok;
reg parity_ok;

// Counters/indices
reg [2:0] i_reg, j_reg, k_reg;
reg [2:0] idx;
reg [3:0] edge_idx;
reg [9:0] max_mask;
reg [2:0] a, b;

// Min function
function [15:0] min2;
    input [15:0] a, b;
    min2 = (a < b) ? a : b;
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
        S_LOAD_REQ:   next_state = (idx < R) ? S_LOAD_REQ : S_LOAD_OPT;
        S_LOAD_OPT:   next_state = (idx < F) ? S_LOAD_OPT : S_FLOYD_K;
        S_FLOYD_K:    next_state = (k_reg < N) ? S_FLOYD_I : S_SUM_REQ;
        S_FLOYD_I:    next_state = (i_reg < N) ? S_FLOYD_J : S_FLOYD_K;
        S_FLOYD_J:    next_state = (j_reg < N) ? S_FLOYD_J : S_FLOYD_I;
        S_SUM_REQ:    next_state = S_GEN_EDGES;
        S_GEN_EDGES:  next_state = (edge_idx < edge_count) ? S_GEN_EDGES : S_ENUM_START;
        S_ENUM_START: next_state = S_ENUM_CHECK;
        S_ENUM_CHECK: next_state = S_CHECK_EVEN;
        S_CHECK_EVEN: next_state = (parity_ok) ? S_BFS : S_NEXT_MASK;
        S_BFS:        next_state = (q_head != q_tail) ? S_BFS : S_CHECK_EVEN;
        S_UPDATE_MIN: next_state = S_NEXT_MASK;
        S_NEXT_MASK:  next_state = (mask < max_mask) ? S_ENUM_CHECK : S_DONE;
        S_DONE:       next_state = S_IDLE;
        default:      next_state = S_IDLE;
    endcase
end

// Datapath
integer x, y, e;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done <= 1'b0;
        result <= 16'd0;
        sum_req <= 16'd0;
        min_added <= INF;
        mask <= 10'd0;
        edge_count <= 4'd0;
        idx <= 3'd0;
        edge_idx <= 4'd0;
        i_reg <= 3'd0;
        j_reg <= 3'd0;
        k_reg <= 3'd0;
        
        // Initialize dist matrix
        for (x = 0; x < MAX_N; x = x + 1) begin
            for (y = 0; y < MAX_N; y = y + 1) begin
                dist[x][y] <= INF;
            end
            dist[x][x] <= 16'd0;
        end
    end else begin
        done <= 1'b0;
        
        case (state)
            S_IDLE: begin
                done <= 1'b0;
            end
            
            S_LOAD_REQ: begin
                if (idx < R) begin
                    a = req_src[idx] - 3'd1;
                    b = req_dst[idx] - 3'd1;
                    if (!(a >= N || b >= N)) begin
                        dist[a][b] <= min2(dist[a][b], req_cost[idx]);
                        dist[b][a] <= min2(dist[b][a], req_cost[idx]);
                    end
                    sum_req <= sum_req + req_cost[idx];
                    idx <= idx + 3'd1;
                end
            end
            
            S_LOAD_OPT: begin
                if (idx < F) begin
                    a = opt_src[idx - R] - 3'd1;
                    b = opt_dst[idx - R] - 3'd1;
                    if (!(a >= N || b >= N)) begin
                        dist[a][b] <= min2(dist[a][b], opt_cost[idx - R]);
                        dist[b][a] <= min2(dist[b][a], opt_cost[idx - R]);
                    end
                    idx <= idx + 3'd1;
                end else begin
                    idx <= 3'd0;
                end
            end
            
            S_FLOYD_K: begin
                j_reg <= 3'd0;
                i_reg <= 3'd0;
                k_reg <= (state == S_FLOYD_J) ? k_reg + 3'd1 : k_reg;
            end
            
            S_FLOYD_I: begin
                j_reg <= 3'd0;
                i_reg <= i_reg + 3'd1;
            end
            
            S_FLOYD_J: begin
                if (i_reg != j_reg && j_reg != k_reg && i_reg != k_reg) begin
                    dist[i_reg][j_reg] <= min2(dist[i_reg][j_reg], dist[i_reg][k_reg] + dist[k_reg][j_reg]);
                end
                j_reg <= j_reg + 3'd1;
            end
            
            S_SUM_REQ: begin
                edge_count <= 4'd0;
                a <= 3'd0;
                b <= 3'd1;
            end
            
            S_GEN_EDGES: begin
                if (a < N) begin
                    b <= (b < N) ? (b + 3'd1) : (a + 3'd2);
                    a <= (b < N) ? a : (a + 3'd1);
                    
                    if (a < N && b < N) begin
                        edge_u[edge_idx] <= a;
                        edge_v[edge_idx] <= b;
                        edge_idx <= edge_idx + 4'd1;
                        edge_count <= edge_count + 4'd1;
                    end
                end
                max_mask <= (10'd1 << edge_count) - 10'd1;
            end
            
            S_ENUM_START: begin
                mask <= 10'd0;
                min_added <= (min_added == INF) ? INF : min_added;
            end
            
            S_ENUM_CHECK: begin
                added_cost <= 16'd0;
                for (x = 0; x < MAX_N; x = x + 1) deg[x] <= 3'd0;
                
                // Existing required flights
                for (x = 0; x < R; x = x + 1) begin
                    a = req_src[x] - 3'd1;
                    b = req_dst[x] - 3'd1;
                    if (a < N && b < N) begin
                        deg[a] <= deg[a] + 3'd1;
                        deg[b] <= deg[b] + 3'd1;
                    end
                end
                
                // Selected optional flights
                for (e = 0; e < edge_count; e = e + 1) begin
                    if (mask[e] && e < MAX_F) begin
                        a = edge_u[e];
                        b = edge_v[e];
                        if (a < N && b < N) begin
                            deg[a] <= deg[a] + 3'd1;
                            deg[b] <= deg[b] + 3'd1;
                            added_cost <= added_cost + dist[a][b];
                        end
                    end
                end
            end
            
            S_CHECK_EVEN: begin
                parity_ok <= 1'b1;
                for (x = 0; x < N; x = x + 1) begin
                    if (deg[x][0] == 1'b1) parity_ok <= 1'b0;
                end
                
                // BFS initialization
                for (x = 0; x < MAX_N; x = x + 1) visited[x] <= 1'b0;
                visited[0] <= 1'b1;
                queue[0] <= 3'd0;
                q_head <= 3'd0;
                q_tail <= 3'd1;
                connectivity_ok <= 1'b0;
            end
            
            S_BFS: begin
                if (q_head != q_tail) begin
                    current_node <= queue[q_head];
                    q_head <= q_head + 3'd1;
                    
                    for (x = 0; x < N; x = x + 1) begin
                        if (dist[current_node][x] < INF && !visited[x]) begin
                            visited[x] <= 1'b1;
                            queue[q_tail] <= x;
                            q_tail <= q_tail + 3'd1;
                        end
                    end
                end else begin
                    connectivity_ok <= 1'b1;
                    for (x = 0; x < N; x = x + 1) begin
                        if (!visited[x]) connectivity_ok <= 1'b0;
                    end
                end
            end
            
            S_UPDATE_MIN: begin
                if (added_cost < min_added) begin
                    min_added <= added_cost;
                end
            end
            
            S_NEXT_MASK: begin
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