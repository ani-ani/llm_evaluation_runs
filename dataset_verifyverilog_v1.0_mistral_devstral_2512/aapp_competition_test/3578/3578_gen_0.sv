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

localparam [3:0] S_IDLE = 4'd0;
localparam [3:0] S_INIT = 4'd1;
localparam [3:0] S_LOAD_REQ = 4'd2;
localparam [3:0] S_LOAD_OPT = 4'd3;
localparam [3:0] S_FLOYD_INIT = 4'd4;
localparam [3:0] S_FLOYD_K = 4'd5;
localparam [3:0] S_FLOYD_I = 4'd6;
localparam [3:0] S_FLOYD_J = 4'd7;
localparam [3:0] S_SUM_REQ = 4'd8;
localparam [3:0] S_GEN_EDGES = 4'd9;
localparam [3:0] S_ENUM_START = 4'd10;
localparam [3:0] S_ENUM_CHECK = 4'd11;
localparam [3:0] S_ENUM_NEXT = 4'd12;
localparam [3:0] S_DONE = 4'd13;

reg [3:0] state;
reg [3:0] next_state;

reg [15:0] dist [0:MAX_N-1][0:MAX_N-1];
reg [15:0] sum_req;
reg [15:0] min_added;
reg [15:0] added_cost;
reg [9:0] mask;
reg [3:0] edge_count;
reg [2:0] edge_u [0:9];
reg [2:0] edge_v [0:9];
reg [2:0] deg [0:MAX_N-1];
reg [2:0] visited [0:MAX_N-1];
reg [2:0] queue [0:MAX_N-1];
reg [2:0] q_head, q_tail;

reg [2:0] i, j, k;
reg [2:0] idx;
reg [2:0] edge_idx;
reg [9:0] max_mask;
reg [15:0] temp_cost;
reg [2:0] a, b;
reg [2:0] u, v;

reg parity_ok;
reg connectivity_ok;

function [15:0] min2;
    input [15:0] a, b;
    min2 = (a < b) ? a : b;
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
    end else begin
        state <= next_state;
    end
end

always @(*) begin
    next_state = state;
    case (state)
        S_IDLE:       if (start) next_state = S_INIT;
        S_INIT:       next_state = S_LOAD_REQ;
        S_LOAD_REQ:   if (idx >= R) next_state = S_LOAD_OPT; else next_state = S_LOAD_REQ;
        S_LOAD_OPT:   if (idx >= F) next_state = S_FLOYD_INIT; else next_state = S_LOAD_OPT;
        S_FLOYD_INIT: next_state = S_FLOYD_K;
        S_FLOYD_K:    if (k >= N) next_state = S_SUM_REQ; else next_state = S_FLOYD_I;
        S_FLOYD_I:    if (i >= N) next_state = S_FLOYD_K; else next_state = S_FLOYD_J;
        S_FLOYD_J:    if (j >= N) next_state = S_FLOYD_I; else next_state = S_FLOYD_J;
        S_SUM_REQ:    next_state = S_GEN_EDGES;
        S_GEN_EDGES:  if (edge_idx >= edge_count) next_state = S_ENUM_START; else next_state = S_GEN_EDGES;
        S_ENUM_START: next_state = S_ENUM_CHECK;
        S_ENUM_CHECK: next_state = S_ENUM_NEXT;
        S_ENUM_NEXT:  if (mask >= max_mask) next_state = S_DONE; else next_state = S_ENUM_CHECK;
        S_DONE:       next_state = S_DONE;
        default:      next_state = S_IDLE;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result <= 16'd0;
        done <= 1'b0;
        sum_req <= 16'd0;
        min_added <= INF;
        mask <= 10'd0;
        edge_count <= 4'd0;
        idx <= 3'd0;
        edge_idx <= 3'd0;
        i <= 3'd0;
        j <= 3'd0;
        k <= 3'd0;
        for (integer x = 0; x < MAX_N; x = x + 1) begin
            for (integer y = 0; y < MAX_N; y = y + 1) begin
                dist[x][y] <= INF;
            end
        end
    end else begin
        case (state)
            S_INIT: begin
                for (integer x = 0; x < MAX_N; x = x + 1) begin
                    dist[x][x] <= 16'd0;
                end
                idx <= 3'd0;
            end
            S_LOAD_REQ: begin
                if (idx < R) begin
                    a <= req_src[idx] - 3'd1;
                    b <= req_dst[idx] - 3'd1;
                    temp_cost <= req_cost[idx];
                    dist[a][b] <= min2(dist[a][b], temp_cost);
                    dist[b][a] <= min2(dist[b][a], temp_cost);
                    sum_req <= sum_req + temp_cost;
                    idx <= idx + 3'd1;
                end
            end
            S_LOAD_OPT: begin
                if (idx < F) begin
                    a <= opt_src[idx] - 3'd1;
                    b <= opt_dst[idx] - 3'd1;
                    temp_cost <= opt_cost[idx];
                    dist[a][b] <= min2(dist[a][b], temp_cost);
                    dist[b][a] <= min2(dist[b][a], temp_cost);
                    idx <= idx + 3'd1;
                end
            end
            S_FLOYD_K: begin
                k <= 3'd0;
                i <= 3'd0;
            end
            S_FLOYD_I: begin
                i <= 3'd0;
                j <= 3'd0;
            end
            S_FLOYD_J: begin
                if (j < N) begin
                    if (dist[i][k] + dist[k][j] < dist[i][j]) begin
                        dist[i][j] <= dist[i][k] + dist[k][j];
                    end
                    j <= j + 3'd1;
                end
            end
            S_SUM_REQ: begin
                edge_count <= 3'd0;
                edge_idx <= 3'd0;
                for (integer x = 0; x < MAX_N; x = x + 1) begin
                    for (integer y = x + 1; y < MAX_N; y = y + 1) begin
                        if (x != y) begin
                            edge_u[edge_count] <= x;
                            edge_v[edge_count] <= y;
                            edge_count <= edge_count + 3'd1;
                        end
                    end
                end
                max_mask <= (1 << edge_count) - 1;
            end
            S_GEN_EDGES: begin
                if (edge_idx < edge_count) begin
                    edge_idx <= edge_idx + 3'd1;
                end
            end
            S_ENUM_START: begin
                mask <= 10'd0;
            end
            S_ENUM_CHECK: begin
                for (integer x = 0; x < MAX_N; x = x + 1) begin
                    deg[x] <= 3'd0;
                end
                added_cost <= 16'd0;
                for (integer x = 0; x < R; x = x + 1) begin
                    a <= req_src[x] - 3'd1;
                    b <= req_dst[x] - 3'd1;
                    deg[a] <= deg[a] + 3'd1;
                    deg[b] <= deg[b] + 3'd1;
                end
                for (integer e = 0; e < edge_count; e = e + 1) begin
                    if (mask[e]) begin
                        u <= edge_u[e];
                        v <= edge_v[e];
                        deg[u] <= deg[u] + 3'd1;
                        deg[v] <= deg[v] + 3'd1;
                        added_cost <= added_cost + dist[u][v];
                    end
                end
                parity_ok <= 1'b1;
                for (integer x = 0; x < N; x = x + 1) begin
                    if (deg[x][0]) begin
                        parity_ok <= 1'b0;
                    end
                end
                for (integer x = 0; x < MAX_N; x = x + 1) begin
                    visited[x] <= 3'd0;
                end
                q_head <= 3'd0;
                q_tail <= 3'd0;
                visited[0] <= 3'd1;
                queue[0] <= 3'd0;
                q_tail <= 3'd1;
                connectivity_ok <= 1'b1;
                for (integer x = 0; x < N; x = x + 1) begin
                    if (!visited[x]) begin
                        connectivity_ok <= 1'b0;
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