module trekking #(
    parameter N = 5,
    parameter M = 6,
    parameter logic [3:0] U [0:M-1] = '{5,0,1,2,2,4},
    parameter logic [3:0] V [0:M-1] = '{1,3,2,3,4,3},
    parameter logic [3:0] D [0:M-1] = '{2,8,11,5,2,9}
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    output reg  [7:0] result,
    output reg        done
);

localparam INF       = 8'hFF;
localparam NO_EDGE   = 4'hF;
localparam MAX_N     = 8;
localparam MAX_STATE = MAX_N * 13;

localparam S_IDLE        = 4'd0;
localparam S_INIT        = 4'd1;
localparam S_FLOYD_INIT  = 4'd2;
localparam S_FLOYD_K     = 4'd3;
localparam S_FLOYD_I     = 4'd4;
localparam S_FLOYD_J     = 4'd5;
localparam S_FLOYD_UPD   = 4'd6;
localparam S_KNIGHT_CALC = 4'd7;
localparam S_DK_INIT     = 4'd8;
localparam S_DK_LOOP     = 4'd9;
localparam S_DK_RELAX    = 4'd10;
localparam S_DK_SLEEP    = 4'd11;
localparam S_DK_RESULT   = 4'd12;
localparam S_WAIT        = 4'd13;
localparam S_DONE        = 4'd14;

reg  [3:0]  state, next_state;
reg  [3:0]  i_reg, j_reg, k_reg;
reg  [3:0]  e_reg;
reg  [7:0]  knight_elapsed_reg;
reg  [7:0]  day_elapsed_reg;
reg  [7:0]  T_knight;
reg  [7:0]  min_dist;
reg  [7:0]  best_state;
reg         found_min;
reg  [7:0]  dist [0:MAX_N-1][0:MAX_N-1];
reg  [3:0]  adj  [0:MAX_N-1][0:MAX_N-1];
reg  [7:0]  dist_state [0:MAX_STATE-1];
reg         visited  [0:MAX_STATE-1];
reg  [3:0]  node_u, node_v, hours_cur;
reg  [7:0]  new_dist;
reg  [3:0]  state_idx;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 0;
        result <= 0;
    end else begin
        state <= next_state;
        if (state != S_DONE) done <= 0;
        if (state == S_DONE) begin
            result <= day_elapsed_reg - knight_elapsed_reg;
            done <= 1;
        end
    end
end

always @(*) begin
    next_state = state;
    case (state)
        S_IDLE:        if (start) next_state = S_INIT;
        S_INIT:        next_state = S_FLOYD_INIT;
        S_FLOYD_INIT:  next_state = S_FLOYD_K;
        S_FLOYD_K:     next_state = S_FLOYD_I;
        S_FLOYD_I:     next_state = S_FLOYD_J;
        S_FLOYD_J:     next_state = S_FLOYD_UPD;
        S_FLOYD_UPD:   if (k_reg >= N-1 && i_reg >= N-1 && j_reg >= N-1) next_state = S_KNIGHT_CALC;
                        else if (j_reg < N-1) next_state = S_FLOYD_J;
                        else if (i_reg < N-1) next_state = S_FLOYD_I;
                        else next_state = S_FLOYD_K;
        S_KNIGHT_CALC: next_state = S_DK_INIT;
        S_DK_INIT:     next_state = S_DK_LOOP;
        S_DK_LOOP:     if (found_min) next_state = S_DK_RELAX;
                        else if (day_elapsed_reg != 0) next_state = S_DK_RESULT;
                        else next_state = S_DK_RESULT;
        S_DK_RELAX:    next_state = S_DK_SLEEP;
        S_DK_SLEEP:    if (hours_cur == 0) next_state = S_DK_LOOP;
                        else next_state = S_DK_LOOP;
        S_DK_RESULT:   next_state = S_WAIT;
        S_WAIT:        next_state = S_DONE;
        S_DONE:        next_state = S_IDLE;
        default:       next_state = S_IDLE;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        integer r, c;
        for (r = 0; r < MAX_N; r = r + 1) begin
            for (c = 0; c < MAX_N; c = c + 1) begin
                dist[r][c] <= INF;
                adj[r][c] <= NO_EDGE;
            end
        end
        for (r = 0; r < MAX_STATE; r = r + 1) begin
            dist_state[r] <= INF;
            visited[r] <= 0;
        end
        i_reg <= 0; j_reg <= 0; k_reg <= 0; e_reg <= 0;
        knight_elapsed_reg <= 0; day_elapsed_reg <= 0;
        T_knight <= 0;
        min_dist <= 0; best_state <= 0; found_min <= 0;
        node_u <= 0; node_v <= 0; hours_cur <= 0;
        new_dist <= 0; state_idx <= 0;
    end else begin
        case (state)
            S_INIT: begin
                if (e_reg < M) begin
                    if (adj[U[e_reg]][V[e_reg]] > D[e_reg])
                        adj[U[e_reg]][V[e_reg]] <= D[e_reg];
                    if (adj[V[e_reg]][U[e_reg]] > D[e_reg])
                        adj[V[e_reg]][U[e_reg]] <= D[e_reg];
                    e_reg <= e_reg + 1;
                end else begin
                    e_reg <= 0;
                    for (integer r = 0; r < N; r = r + 1) begin
                        for (integer c = 0; c < N; c = c + 1) begin
                            if (r == c)
                                dist[r][c] <= 0;
                            else if (adj[r][c] != NO_EDGE)
                                dist[r][c] <= {4'd0, adj[r][c]};
                            else
                                dist[r][c] <= INF;
                        end
                    end
                end
            end
            S_FLOYD_INIT: begin
                k_reg <= 0; i_reg <= 0; j_reg <= 0;
            end
            S_FLOYD_K: begin
                i_reg <= 0;
                if (k_reg < N) k_reg <= k_reg + 1;
            end
            S_FLOYD_I: begin
                j_reg <= 0;
                if (i_reg < N) i_reg <= i_reg + 1;
            end
            S_FLOYD_J: begin
                if (j_reg < N) j_reg <= j_reg + 1;
            end
            S_FLOYD_UPD: begin
                if (k_reg < N && i_reg < N && j_reg < N) begin
                    if (dist[i_reg][k_reg] != INF && dist[k_reg][j_reg] != INF) begin
                        new_dist <= dist[i_reg][k_reg] + dist[k_reg][j_reg];
                        if (new_dist < dist[i_reg][j_reg]) begin
                            dist[i_reg][j_reg] <= new_dist;
                        end
                    end
                end
            end
            S_KNIGHT_CALC: begin
                T_knight <= dist[0][N-1];
                if (dist[0][N-1] != INF) begin
                    if (dist[0][N-1] <= 12)
                        knight_elapsed_reg <= dist[0][N-1];
                    else begin
                        integer days = 0;
                        for (integer t = 0; t < 84; t = t + 1) begin
                            if (t == dist[0][N-1]) begin
                                days = (t + 11) / 12;
                            end
                        end
                        knight_elapsed_reg <= dist[0][N-1] + 12 * (days - 1);
                    end
                end else begin
                    knight_elapsed_reg <= INF;
                end
            end
            S_DK_INIT: begin
                for (integer s = 0; s < MAX_STATE; s = s + 1) begin
                    dist_state[s] <= INF;
                    visited[s] <= 0;
                end
                dist_state[0] <= 0;
                min_dist <= INF;
                found_min <= 0;
            end
            S_DK_LOOP: begin
                min_dist <= INF;
                found_min <= 0;
                for (integer s = 0; s < MAX_STATE; s = s + 1) begin
                    if (!visited[s] && dist_state[s] < min_dist) begin
                        min_dist <= dist_state[s];
                        best_state <= s;
                        found_min <= 1;
                    end
                end
                if (found_min) begin
                    visited[best_state] <= 1;
                    node_u <= best_state / 13;
                    hours_cur <= best_state % 13;
                end
            end
            S_DK_RELAX: begin
                for (integer v = 0; v < N; v = v + 1) begin
                    if (adj[node_u][v] != NO_EDGE) begin
                        if (hours_cur + adj[node_u][v] <= 12) begin
                            state_idx <= v * 13 + (hours_cur + adj[node_u][v]);
                            new_dist <= dist_state[best_state] + adj[node_u][v];
                            if (new_dist < dist_state[state_idx]) begin
                                dist_state[state_idx] <= new_dist;
                            end
                        end
                    end
                end
            end
            S_DK_SLEEP: begin
                if (hours_cur > 0) begin
                    state_idx <= node_u * 13 + 0;
                    new_dist <= dist_state[best_state] + (24 - hours_cur);
                    if (new_dist < dist_state[state_idx]) begin
                        dist_state[state_idx] <= new_dist;
                    end
                end
            end
            S_DK_RESULT: begin
                day_elapsed_reg <= INF;
                for (integer h = 0; h <= 12; h = h + 1) begin
                    integer idx = (N-1) * 13 + h;
                    if (dist_state[idx] < day_elapsed_reg) begin
                        day_elapsed_reg <= dist_state[idx];
                    end
                end
            end
            S_WAIT: begin
            end
            S_DONE: begin
            end
            default: begin
                e_reg <= 0; i_reg <= 0; j_reg <= 0; k_reg <= 0;
            end
        endcase
    end
end

endmodule