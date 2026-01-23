module tree_optimizer (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_nodes,
    input [7:0] edges [14:0][1:0],
    output reg [2:0] best_diameter,
    output reg [2:0] remove_edge_u, remove_edge_v,
    output reg [2:0] add_edge_u, add_edge_v,
    output reg done
);

    // States
    localparam IDLE = 4'd0;
    localparam BUILD = 4'd1;
    localparam FW_INIT = 4'd2;
    localparam FW_COMP = 4'd3;
    localparam TRY_START = 4'd4;
    localparam REMOVE = 4'd5;
    localparam FIND_COMP = 4'd6;
    localparam FIND_CEN = 4'd7;
    localparam CLR_VIS = 4'd8;
    localparam CALC_ECC = 4'd9;
    localparam EVAL = 4'd10;
    localparam UPDATE = 4'd11;
    localparam NEXT = 4'd12;
    localparam FINISH = 4'd13;

    reg [3:0] state;
    reg [3:0] next_state; // For returning from sub-states

    // Graph
    reg [7:0] adj [7:0][7:0];
    reg [2:0] dist [7:0][7:0];

    // Edges
    reg [2:0] eu [14:0];
    reg [2:0] ev [14:0];
    reg [3:0] ecnt;

    // Iterators
    reg [2:0] i, j, k;
    reg [3:0] eidx;

    // BFS Queue
    reg [2:0] q [7:0];
    reg [2:0] qh, qt;
    reg [2:0] curr_node;

    // Metrics
    reg [2:0] cur_u, cur_v;
    reg [2:0] cen_a, cen_b;
    reg [2:0] rad_a, rad_b;
    reg [2:0] dia_a, dia_b;
    reg [2:0] cur_diam;
    reg [7:0] visited;

    // Temp
    reg [2:0] min_ecc, max_ecc, temp_ecc;
    reg [2:0] temp_cen;
    reg is_b_phase;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            best_diameter <= 3'd7;
        end else begin
            case (state)
                IDLE: begin
                    if (start) state <= BUILD;
                    i <= 0; ecnt <= 0;
                end

                BUILD: begin
                    if (i < 8) begin
                        if (j < 8) begin
                            adj[i][j] <= (i==j); // Init (0 or 1 for self, others 0)
                            j <= j + 1;
                        end else begin
                            i <= i + 1; j <= 0;
                        end
                    end else begin
                        if (ecnt < num_nodes - 1) begin
                            adj[edges[ecnt][0]][edges[ecnt][1]] <= 1;
                            adj[edges[ecnt][1]][edges[ecnt][0]] <= 1;
                            eu[ecnt] <= edges[ecnt][0];
                            ev[ecnt] <= edges[ecnt][1];
                            ecnt <= ecnt + 1;
                        end else begin
                            ecnt <= num_nodes - 1;
                            state <= FW_INIT;
                            i <= 0; j <= 0;
                        end
                    end
                end

                FW_INIT: begin
                    if (i < 8) begin
                        if (j < 8) begin
                            if (i == j) dist[i][j] <= 0;
                            else if (adj[i][j]) dist[i][j] <= 1;
                            else dist[i][j] <= 7;
                            j <= j + 1;
                        end else begin
                            j <= 0; i <= i + 1;
                        end
                    end else begin
                        i <= 0; j <= 0; k <= 0;
                        state <= FW_COMP;
                    end
                end

                FW_COMP: begin
                    if (i < 8) begin
                        if (j < 8) begin
                            if (k < 8) begin
                                if (dist[j][i] + dist[i][k] < dist[j][k])
                                    dist[j][k] <= dist[j][i] + dist[i][k];
                                k <= k + 1;
                            end else begin
                                k <= 0; j <= j + 1;
                            end
                        end else begin
                            j <= 0; i <= i + 1;
                        end
                    end else begin
                        state <= TRY_START;
                        eidx <= 0;
                        best_diameter <= 7;
                    end
                end

                TRY_START: begin
                    if (eidx < ecnt) begin
                        cur_u <= eu[eidx]; cur_v <= ev[eidx];
                        state <= REMOVE;
                        visited <= 0;
                        qh <= 0; qt <= 0;
                    end else state <= FINISH;
                end

                REMOVE: begin
                    // Start Component A (cur_u)
                    visited[cur_u] <= 1; q[qt] <= cur_u; qt <= qt + 1;
                    state <= FIND_COMP;
                    is_b_phase <= 0; // Mark we are finding A
                    i <= 0; // Sub-state for pop
                end

                FIND_COMP: begin
                    if (qh < qt) begin
                        if (i == 0) begin
                            curr_node <= q[qh]; qh <= qh + 1; i <= 1; k <= 0;
                        end else begin
                            if (k < 8) begin
                                if (adj[curr_node][k] && !((curr_node==cur_u && k==cur_v) || (curr_node==cur_v && k==cur_u))) begin
                                    if (!visited[k]) begin
                                        visited[k] <= 1; q[qt] <= k; qt <= qt + 1;
                                    end
                                end
                                k <= k + 1;
                            end else i <= 0; // Done neighbors, ready for next pop
                        end
                    end else begin
                        // Done component. Find Center.
                        state <= FIND_CEN;
                        i <= 0; min_ecc <= 7; max_ecc <= 0;
                        temp_cen <= 0;
                    end
                end

                FIND_CEN: begin
                    if (i < 8) begin
                        if (visited[i]) begin
                            temp_ecc <= 0; j <= 0;
                            next_state <= FIND_CEN; // Return here
                            state <= CALC_ECC;
                        end else i <= i + 1;
                    end else begin
                        // Store results
                        if (!is_b_phase) begin
                            rad_a <= min_ecc; dia_a <= max_ecc; cen_a <= temp_cen;
                            // Go to B
                            state <= CLR_VIS;
                        end else begin
                            rad_b <= min_ecc; dia_b <= max_ecc; cen_b <= temp_cen;
                            state <= EVAL;
                        end
                    end
                end

                CLR_VIS: begin
                    if (i < 8) begin
                        visited[i] <= 0; i <= i + 1;
                    end else begin
                        // Start B
                        visited[cur_v] <= 1; q[qt] <= cur_v; qt <= qt + 1;
                        state <= FIND_COMP;
                        is_b_phase <= 1; // Mark B phase
                        i <= 0;
                    end
                end

                CALC_ECC: begin
                    if (j < 8) begin
                        if (visited[j]) begin
                            if (dist[i][j] > temp_ecc) temp_ecc <= dist[i][j];
                        end
                        j <= j + 1;
                    end else begin
                        // Ecc calc done for node i
                        if (temp_ecc > max_ecc) max_ecc <= temp_ecc;
                        if (temp_ecc < min_ecc) begin
                            min_ecc <= temp_ecc;
                            temp_cen <= i;
                        end
                        i <= i + 1;
                        state <= next_state;
                    end
                end

                EVAL: begin
                    cur_diam <= dia_a;
                    if (dia_b > cur_diam) cur_diam <= dia_b;
                    if (rad_a + rad_b + 1 > cur_diam) cur_diam <= rad_a + rad_b + 1;
                    state <= UPDATE;
                end

                UPDATE: begin
                    if (cur_diam < best_diameter) begin
                        best_diameter <= cur_diam;
                        remove_edge_u <= cur_u;
                        remove_edge_v <= cur_v;
                        add_edge_u <= cen_a;
                        add_edge_v <= cen_b;
                    end
                    state <= NEXT;
                end

                NEXT: begin
                    eidx <= eidx + 1;
                    state <= TRY_START;
                end

                FINISH: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule