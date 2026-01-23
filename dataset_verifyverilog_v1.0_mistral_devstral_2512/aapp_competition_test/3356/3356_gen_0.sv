module tree_reconstruction(
    input clk,
    input rst_n,
    input start,
    input [2:0] node_count,
    input [7:0] edge_list_0_a, edge_list_0_b,
    input [7:0] edge_list_1_a, edge_list_1_b,
    input [7:0] edge_list_2_a, edge_list_2_b,
    input [7:0] edge_list_3_a, edge_list_3_b,
    input [7:0] edge_list_4_a, edge_list_4_b,
    input [7:0] edge_list_5_a, edge_list_5_b,
    input [7:0] edge_list_6_a, edge_list_6_b,
    input [7:0] edge_list_7_a, edge_list_7_b,
    output reg [3:0] new_diameter,
    output reg [3:0] remove_a, remove_b,
    output reg [3:0] add_a, add_b,
    output reg done
);

    // Parameters
    localparam [3:0] MAX_NODES = 8;
    localparam [3:0] MAX_EDGES = 7;
    localparam [3:0] INF = 15;

    // Internal signals
    reg [3:0] dist [0:7][0:7];
    reg [3:0] diameter_end1, diameter_end2;
    reg [3:0] diameter_path [0:7];
    reg [3:0] path_length;
    reg [3:0] best_diameter;
    reg [3:0] best_remove_a, best_remove_b;
    reg [3:0] best_add_a, best_add_b;

    // FSM signals
    reg [2:0] state;
    reg [3:0] counter, i, j, k;

    // State definitions
    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_INIT = 3'd1;
    localparam [2:0] S_FLOYD = 3'd2;
    localparam [2:0] S_FIND_DIA = 3'd3;
    localparam [2:0] S_FIND_PATH = 3'd4;
    localparam [2:0] S_BREAK_EDGE = 3'd5;
    localparam [2:0] S_DONE = 3'd6;

    // Initialize all registers
    integer idx, jdx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            new_diameter <= 4'd0;
            remove_a <= 4'd0;
            remove_b <= 4'd0;
            add_a <= 4'd0;
            add_b <= 4'd0;
            diameter_end1 <= 4'd0;
            diameter_end2 <= 4'd0;
            path_length <= 4'd0;
            best_diameter <= 4'd0;
            best_remove_a <= 4'd0;
            best_remove_b <= 4'd0;
            best_add_a <= 4'd0;
            best_add_b <= 4'd0;
            counter <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                for (jdx = 0; jdx < 8; jdx = jdx + 1) begin
                    dist[idx][jdx] <= 4'd0;
                end
            end
            for (idx = 0; idx < 8; idx = idx + 1) begin
                diameter_path[idx] <= 4'd0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        state <= S_INIT;
                        done <= 1'b0;
                        counter <= 4'd0;
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                    end
                end
                
                S_INIT: begin
                    if (i < node_count) begin
                        if (j < node_count) begin
                            if (i == j) begin
                                dist[i][j] <= 4'd0;
                            end else begin
                                dist[i][j] <= INF;
                            end
                            j <= j + 1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1;
                        end
                    end else begin
                        if (counter < node_count - 1) begin
                            case (counter)
                                4'd0: begin
                                    if (edge_list_0_a < node_count && edge_list_0_b < node_count) begin
                                        dist[edge_list_0_a][edge_list_0_b] <= 4'd1;
                                        dist[edge_list_0_b][edge_list_0_a] <= 4'd1;
                                    end
                                end
                                4'd1: begin
                                    if (edge_list_1_a < node_count && edge_list_1_b < node_count) begin
                                        dist[edge_list_1_a][edge_list_1_b] <= 4'd1;
                                        dist[edge_list_1_b][edge_list_1_a] <= 4'd1;
                                    end
                                end
                                4'd2: begin
                                    if (edge_list_2_a < node_count && edge_list_2_b < node_count) begin
                                        dist[edge_list_2_a][edge_list_2_b] <= 4'd1;
                                        dist[edge_list_2_b][edge_list_2_a] <= 4'd1;
                                    end
                                end
                                4'd3: begin
                                    if (edge_list_3_a < node_count && edge_list_3_b < node_count) begin
                                        dist[edge_list_3_a][edge_list_3_b] <= 4'd1;
                                        dist[edge_list_3_b][edge_list_3_a] <= 4'd1;
                                    end
                                end
                                4'd4: begin
                                    if (edge_list_4_a < node_count && edge_list_4_b < node_count) begin
                                        dist[edge_list_4_a][edge_list_4_b] <= 4'd1;
                                        dist[edge_list_4_b][edge_list_4_a] <= 4'd1;
                                    end
                                end
                                4'd5: begin
                                    if (edge_list_5_a < node_count && edge_list_5_b < node_count) begin
                                        dist[edge_list_5_a][edge_list_5_b] <= 4'd1;
                                        dist[edge_list_5_b][edge_list_5_a] <= 4'd1;
                                    end
                                end
                                4'd6: begin
                                    if (edge_list_6_a < node_count && edge_list_6_b < node_count) begin
                                        dist[edge_list_6_a][edge_list_6_b] <= 4'd1;
                                        dist[edge_list_6_b][edge_list_6_a] <= 4'd1;
                                    end
                                end
                                4'd7: begin
                                    if (edge_list_7_a < node_count && edge_list_7_b < node_count) begin
                                        dist[edge_list_7_a][edge_list_7_b] <= 4'd1;
                                        dist[edge_list_7_b][edge_list_7_a] <= 4'd1;
                                    end
                                end
                            endcase
                            counter <= counter + 1;
                        end else begin
                            state <= S_FLOYD;
                            i <= 4'd0;
                            j <= 4'd0;
                            k <= 4'd0;
                        end
                    end
                end
                
                S_FLOYD: begin
                    if (k < node_count) begin
                        if (i < node_count) begin
                            if (j < node_count) begin
                                if (dist[i][k] + dist[k][j] < dist[i][j]) begin
                                    dist[i][j] <= dist[i][k] + dist[k][j];
                                end
                                j <= j + 1;
                            end else begin
                                j <= 4'd0;
                                i <= i + 1;
                            end
                        end else begin
                            i <= 4'd0;
                            k <= k + 1;
                        end
                    end else begin
                        state <= S_FIND_DIA;
                        diameter_end1 <= 4'd0;
                        diameter_end2 <= 4'd0;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end
                
                S_FIND_DIA: begin
                    if (i < node_count) begin
                        if (j < node_count) begin
                            if (dist[i][j] > dist[diameter_end1][diameter_end2]) begin
                                diameter_end1 <= i;
                                diameter_end2 <= j;
                            end
                            j <= j + 1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1;
                        end
                    end else begin
                        state <= S_FIND_PATH;
                        path_length <= 4'd0;
                        i <= diameter_end1;
                    end
                end
                
                S_FIND_PATH: begin
                    if (i != diameter_end2) begin
                        for (k = 0; k < node_count; k = k + 1) begin
                            if (dist[i][k] + dist[k][diameter_end2] == dist[i][diameter_end2] && dist[i][k] == 1) begin
                                diameter_path[path_length] <= i;
                                path_length <= path_length + 1;
                                i <= k;
                            end
                        end
                    end else begin
                        diameter_path[path_length] <= diameter_end2;
                        path_length <= path_length + 1;
                        state <= S_BREAK_EDGE;
                        counter <= 4'd0;
                        best_diameter <= INF;
                    end
                end
                
                S_BREAK_EDGE: begin
                    if (counter < path_length - 1) begin
                        new_diameter <= dist[diameter_path[0]][diameter_path[path_length - 1]] - 1;
                        remove_a <= diameter_path[counter];
                        remove_b <= diameter_path[counter + 1];
                        add_a <= diameter_path[counter];
                        add_b <= diameter_path[path_length - 1];
                        if (new_diameter < best_diameter) begin
                            best_diameter <= new_diameter;
                            best_remove_a <= diameter_path[counter];
                            best_remove_b <= diameter_path[counter + 1];
                            best_add_a <= diameter_path[counter];
                            best_add_b <= diameter_path[path_length - 1];
                        end
                        counter <= counter + 1;
                    end else begin
                        state <= S_DONE;
                        new_diameter <= best_diameter;
                        remove_a <= best_remove_a;
                        remove_b <= best_remove_b;
                        add_a <= best_add_a;
                        add_b <= best_add_b;
                        done <= 1'b1;
                    end
                end
                
                S_DONE: begin
                    if (!start) begin
                        done <= 1'b0;
                    end
                end
                
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule