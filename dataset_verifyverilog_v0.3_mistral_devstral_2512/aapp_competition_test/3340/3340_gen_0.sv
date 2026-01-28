module flight_optimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] adj_flat,
    output reg [2:0] min_diameter,
    output reg [2:0] remove_u,
    output reg [2:0] remove_v,
    output reg [2:0] add_u,
    output reg [2:0] add_v,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] FIND_EDGE = 4'd2;
    localparam [3:0] REMOVE_EDGE = 4'd3;
    localparam [3:0] FIND_COMPONENTS = 4'd4;
    localparam [3:0] BFS1_START = 4'd5;
    localparam [3:0] BFS1_LOOP = 4'd6;
    localparam [3:0] PROCESS_NEIGHBORS1 = 4'd7;
    localparam [3:0] BFS2_START = 4'd8;
    localparam [3:0] BFS2_LOOP = 4'd9;
    localparam [3:0] PROCESS_NEIGHBORS2 = 4'd10;
    localparam [3:0] CALC_RADIUS1 = 4'd11;
    localparam [3:0] CALC_RADIUS2 = 4'd12;
    localparam [3:0] CALC_CANDIDATE = 4'd13;
    localparam [3:0] UPDATE_BEST = 4'd14;
    localparam [3:0] RESTORE_EDGE = 4'd15;
    localparam [3:0] DONE = 4'd16;

    // Internal registers
    reg [3:0] state;
    reg [63:0] adj_reg;
    reg [63:0] temp_adj;
    reg [2:0] edge_i, edge_j;
    reg [2:0] best_diam;
    reg [2:0] best_remove_u, best_remove_v;
    reg [2:0] best_add_u, best_add_v;
    reg [2:0] comp1_diam, comp2_diam;
    reg [2:0] comp1_rad, comp2_rad;
    reg [2:0] new_diam;
    reg [2:0] center1, center2;

    // BFS registers
    reg [2:0] bfs_start;
    reg [2:0] bfs_queue [0:7];
    reg [2:0] bfs_head, bfs_tail;
    reg [7:0] visited;
    reg [2:0] dist [0:7];
    reg [2:0] bfs_node;
    reg [2:0] farthest_node;
    reg [2:0] max_dist;
    reg [1:0] bfs_comp;
    reg [2:0] neighbor_idx;

    // Helper function to get edge
    function get_edge(input [2:0] i, input [2:0] j, input [63:0] matrix);
        begin
            get_edge = matrix[i*8 + j];
        end
    endfunction

    // Helper function to set edge
    function [63:0] set_edge(input [2:0] i, input [2:0] j, input val, input [63:0] matrix);
        begin
            set_edge = matrix;
            set_edge[i*8 + j] = val;
            set_edge[j*8 + i] = val;
        end
    endfunction

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_diameter <= 3'd0;
            best_diam <= 3'd7;
            edge_i <= 3'd0;
            edge_j <= 3'd1;
            best_remove_u <= 3'd0;
            best_remove_v <= 3'd0;
            best_add_u <= 3'd0;
            best_add_v <= 3'd0;
            visited <= 8'd0;
            bfs_head <= 3'd0;
            bfs_tail <= 3'd0;
            neighbor_idx <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        adj_reg <= adj_flat;
                        temp_adj <= adj_flat;
                        best_diam <= 3'd7;
                        edge_i <= 3'd0;
                        edge_j <= 3'd1;
                        state <= INIT;
                    end
                end

                INIT: begin
                    state <= FIND_EDGE;
                end

                FIND_EDGE: begin
                    if (edge_i < 3'd8 && edge_j < 3'd8) begin
                        if (get_edge(edge_i, edge_j, adj_reg)) begin
                            state <= REMOVE_EDGE;
                        end else begin
                            if (edge_j < 3'd7) begin
                                edge_j <= edge_j + 3'd1;
                            end else begin
                                edge_j <= edge_i + 3'd2;
                                edge_i <= edge_i + 3'd1;
                            end
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                REMOVE_EDGE: begin
                    temp_adj <= set_edge(edge_i, edge_j, 1'b0, temp_adj);
                    state <= FIND_COMPONENTS;
                    bfs_comp <= 2'd0;
                end

                FIND_COMPONENTS: begin
                    bfs_start <= edge_i;
                    bfs_comp <= 2'd1;
                    state <= BFS1_START;
                end

                BFS1_START: begin
                    visited <= 8'd0;
                    visited[edge_i] <= 1'b1;
                    dist[edge_i] <= 3'd0;
                    bfs_queue[0] <= edge_i;
                    bfs_head <= 3'd0;
                    bfs_tail <= 3'd1;
                    farthest_node <= edge_i;
                    max_dist <= 3'd0;
                    state <= BFS1_LOOP;
                end

                BFS1_LOOP: begin
                    if (bfs_head != bfs_tail) begin
                        bfs_node <= bfs_queue[bfs_head];
                        bfs_head <= bfs_head + 3'd1;
                        neighbor_idx <= 3'd0;
                        state <= PROCESS_NEIGHBORS1;
                    end else begin
                        if (bfs_comp == 2'd1) begin
                            comp1_diam <= max_dist;
                            bfs_start <= farthest_node;
                            state <= BFS2_START;
                        end else begin
                            comp2_diam <= max_dist;
                            state <= CALC_RADIUS1;
                        end
                    end
                end

                PROCESS_NEIGHBORS1: begin
                    if (neighbor_idx < 3'd8) begin
                        if (get_edge(bfs_node, neighbor_idx, temp_adj) && !visited[neighbor_idx]) begin
                            visited[neighbor_idx] <= 1'b1;
                            dist[neighbor_idx] <= dist[bfs_node] + 3'd1;
                            bfs_queue[bfs_tail] <= neighbor_idx;
                            bfs_tail <= bfs_tail + 3'd1;
                            if (dist[neighbor_idx] > max_dist) begin
                                max_dist <= dist[neighbor_idx];
                                farthest_node <= neighbor_idx;
                            end
                        end
                        neighbor_idx <= neighbor_idx + 3'd1;
                    end else begin
                        state <= BFS1_LOOP;
                    end
                end

                BFS2_START: begin
                    visited <= 8'd0;
                    visited[bfs_start] <= 1'b1;
                    dist[bfs_start] <= 3'd0;
                    bfs_queue[0] <= bfs_start;
                    bfs_head <= 3'd0;
                    bfs_tail <= 3'd1;
                    farthest_node <= bfs_start;
                    max_dist <= 3'd0;
                    state <= BFS2_LOOP;
                end

                BFS2_LOOP: begin
                    if (bfs_head != bfs_tail) begin
                        bfs_node <= bfs_queue[bfs_head];
                        bfs_head <= bfs_head + 3'd1;
                        neighbor_idx <= 3'd0;
                        state <= PROCESS_NEIGHBORS2;
                    end else begin
                        comp1_rad <= max_dist;
                        center1 <= farthest_node;
                        bfs_comp <= 2'd2;
                        bfs_start <= edge_j;
                        state <= BFS1_START;
                    end
                end

                PROCESS_NEIGHBORS2: begin
                    if (neighbor_idx < 3'd8) begin
                        if (get_edge(bfs_node, neighbor_idx, temp_adj) && !visited[neighbor_idx]) begin
                            visited[neighbor_idx] <= 1'b1;
                            dist[neighbor_idx] <= dist[bfs_node] + 3'd1;
                            bfs_queue[bfs_tail] <= neighbor_idx;
                            bfs_tail <= bfs_tail + 3'd1;
                            if (dist[neighbor_idx] > max_dist) begin
                                max_dist <= dist[neighbor_idx];
                                farthest_node <= neighbor_idx;
                            end
                        end
                        neighbor_idx <= neighbor_idx + 3'd1;
                    end else begin
                        state <= BFS2_LOOP;
                    end
                end

                CALC_RADIUS1: begin
                    comp2_rad <= max_dist;
                    center2 <= farthest_node;
                    state <= CALC_CANDIDATE;
                end

                CALC_CANDIDATE: begin
                    new_diam <= (comp1_diam > comp2_diam) ? 
                                ((comp1_diam > (comp1_rad + comp2_rad + 3'd1)) ? comp1_diam : comp1_rad + comp2_rad + 3'd1) :
                                ((comp2_diam > (comp1_rad + comp2_rad + 3'd1)) ? comp2_diam : comp1_rad + comp2_rad + 3'd1);
                    state <= UPDATE_BEST;
                end

                UPDATE_BEST: begin
                    if (new_diam < best_diam) begin
                        best_diam <= new_diam;
                        best_remove_u <= edge_i;
                        best_remove_v <= edge_j;
                        best_add_u <= center1;
                        best_add_v <= center2;
                    end
                    state <= RESTORE_EDGE;
                end

                RESTORE_EDGE: begin
                    temp_adj <= set_edge(edge_i, edge_j, 1'b1, temp_adj);
                    if (edge_j < 3'd7) begin
                        edge_j <= edge_j + 3'd1;
                    end else begin
                        edge_j <= edge_i + 3'd2;
                        edge_i <= edge_i + 3'd1;
                    end
                    state <= FIND_EDGE;
                end

                DONE: begin
                    min_diameter <= best_diam;
                    remove_u <= best_remove_u;
                    remove_v <= best_remove_v;
                    add_u <= best_add_u;
                    add_v <= best_add_v;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule