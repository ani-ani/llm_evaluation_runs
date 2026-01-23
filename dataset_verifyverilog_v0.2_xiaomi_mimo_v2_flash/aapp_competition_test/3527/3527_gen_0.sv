module network_optimizer (
    input clk,
    input rst_n,
    input start,
    input [4:0] node_count,
    input [15:0] edge_count,
    input [4:0] edges_u [15:0],
    input [4:0] edges_v [15:0],
    output reg [3:0] result,
    output reg done
);

    localparam MAX_N = 16;
    localparam S_IDLE = 0, S_BUILD = 1, S_BFS_START = 2, S_BFS_RUN = 3, S_BFS_PROC = 4, S_TRANSITION = 5, S_RESULT = 6;

    reg [2:0] state;
    reg [15:0] adj [0:15];
    reg [15:0] global_vis;
    reg [15:0] local_vis;
    reg [3:0] dist [0:15];
    reg [3:0] q [0:15];
    reg [3:0] q_head, q_tail, q_cnt;
    reg [3:0] scan_ptr;
    reg [3:0] start_node;
    reg [3:0] active_node;
    reg [3:0] cur_max_dist;
    reg [3:0] farthest_node;
    reg is_pass_2;
    reg is_comp_2;
    reg [3:0] dia1, dia2;
    reg [3:0] rad1, rad2;

    wire q_empty = (q_cnt == 0);
    wire [3:0] q_rd = q[q_head];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) state <= S_BUILD;
                end
                S_BUILD: begin
                    for (int i = 0; i < 16; i++) begin
                        if (i < edge_count) begin
                            adj[edges_u[i]][edges_v[i]] <= 1;
                            adj[edges_v[i]][edges_u[i]] <= 1;
                        end
                    end
                    global_vis <= 0;
                    dia1 <= 0; dia2 <= 0;
                    is_comp_2 <= 0;
                    is_pass_2 <= 0;
                    scan_ptr <= 0;
                    state <= S_BFS_START;
                end
                S_BFS_START: begin
                    if (scan_ptr >= node_count) begin
                        if (is_comp_2) state <= S_RESULT;
                        else state <= S_RESULT; // Only 1 component (or empty)
                    end else if (!global_vis[scan_ptr] && !local_vis[scan_ptr]) begin
                        start_node <= scan_ptr;
                        q_head <= 0; q_tail <= 0; q_cnt <= 0;
                        local_vis <= 0;
                        dist[scan_ptr] <= 0;
                        local_vis[scan_ptr] <= 1;
                        q[q_tail] <= scan_ptr;
                        q_tail <= q_tail + 1;
                        q_cnt <= q_cnt + 1;
                        cur_max_dist <= 0;
                        farthest_node <= scan_ptr;
                        state <= S_BFS_RUN;
                    end else begin
                        scan_ptr <= scan_ptr + 1;
                    end
                end
                S_BFS_RUN: begin
                    if (!q_empty) begin
                        active_node <= q_rd;
                        q_head <= q_head + 1;
                        q_cnt <= q_cnt - 1;
                        state <= S_BFS_PROC;
                    end else begin
                        state <= S_TRANSITION;
                    end
                end
                S_BFS_PROC: begin
                    for (int k = 0; k < 16; k++) begin
                        if (k < node_count && adj[active_node][k] && !local_vis[k]) begin
                            local_vis[k] <= 1;
                            dist[k] <= dist[active_node] + 1;
                            q[q_tail] <= k;
                            q_tail <= q_tail + 1;
                            q_cnt <= q_cnt + 1;
                            if (dist[active_node] + 1 > cur_max_dist) begin
                                cur_max_dist <= dist[active_node] + 1;
                                farthest_node <= k;
                            end
                        end
                    end
                    state <= S_BFS_RUN;
                end
                S_TRANSITION: begin
                    if (!is_comp_2) begin // Component 1
                        if (!is_pass_2) begin // Finished Pass 1
                            start_node <= farthest_node;
                            is_pass_2 <= 1;
                            q_head <= 0; q_tail <= 0; q_cnt <= 0;
                            local_vis <= 0;
                            q[0] <= farthest_node;
                            q_tail <= 1;
                            q_cnt <= 1;
                            local_vis[farthest_node] <= 1;
                            dist[farthest_node] <= 0;
                            cur_max_dist <= 0;
                            state <= S_BFS_RUN;
                        end else begin // Finished Pass 2
                            dia1 <= cur_max_dist;
                            rad1 <= (cur_max_dist + 1) >> 1;
                            global_vis <= global_vis | local_vis;
                            is_comp_2 <= 1;
                            is_pass_2 <= 0;
                            scan_ptr <= 0;
                            state <= S_BFS_START;
                        end
                    end else begin // Component 2
                        if (!is_pass_2) begin // Finished Pass 1
                            start_node <= farthest_node;
                            is_pass_2 <= 1;
                            q_head <= 0; q_tail <= 0; q_cnt <= 0;
                            local_vis <= 0;
                            q[0] <= farthest_node;
                            q_tail <= 1;
                            q_cnt <= 1;
                            local_vis[farthest_node] <= 1;
                            dist[farthest_node] <= 0;
                            cur_max_dist <= 0;
                            state <= S_BFS_RUN;
                        end else begin // Finished Pass 2
                            dia2 <= cur_max_dist;
                            rad2 <= (cur_max_dist + 1) >> 1;
                            state <= S_RESULT;
                        end
                    end
                end
                S_RESULT: begin
                    if (!is_comp_2) begin // Only 1 component found
                        result <= dia1;
                    end else begin
                        // Calculate max(Dia1, Dia2, (Dia1+1)/2 + (Dia2+1)/2 + 1)
                        reg [3:0] t3;
                        t3 = ((dia1 + 1) >> 1) + ((dia2 + 1) >> 1) + 1;
                        if (dia1 >= dia2 && dia1 >= t3) result <= dia1;
                        else if (dia2 >= t3) result <= dia2;
                        else result <= t3;
                    end
                    done <= 1;
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule