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

localparam [3:0] INF = 4'd15;
localparam [3:0] MAX_NODES = 4'd8;

localparam [2:0] S_IDLE = 3'd0;
localparam [2:0] S_INIT = 3'd1;
localparam [2:0] S_FLOYD = 3'd2;
localparam [2:0] S_FIND_DIA = 3'd3;
localparam [2:0] S_FIND_PATH = 3'd4;
localparam [2:0] S_BREAK_EDGE = 3'd5;
localparam [2:0] S_DONE = 3'd6;

reg [2:0] state;
reg [2:0] i, j, k, counter, path_idx;
reg [3:0] dist_0_0, dist_0_1, dist_0_2, dist_0_3, dist_0_4, dist_0_5, dist_0_6, dist_0_7;
reg [3:0] dist_1_0, dist_1_1, dist_1_2, dist_1_3, dist_1_4, dist_1_5, dist_1_6, dist_1_7;
reg [3:0] dist_2_0, dist_2_1, dist_2_2, dist_2_3, dist_2_4, dist_2_5, dist_2_6, dist_2_7;
reg [3:0] dist_3_0, dist_3_1, dist_3_2, dist_3_3, dist_3_4, dist_3_5, dist_3_6, dist_3_7;
reg [3:0] dist_4_0, dist_4_1, dist_4_2, dist_4_3, dist_4_4, dist_4_5, dist_4_6, dist_4_7;
reg [3:0] dist_5_0, dist_5_1, dist_5_2, dist_5_3, dist_5_4, dist_5_5, dist_5_6, dist_5_7;
reg [3:0] dist_6_0, dist_6_1, dist_6_2, dist_6_3, dist_6_4, dist_6_5, dist_6_6, dist_6_7;
reg [3:0] dist_7_0, dist_7_1, dist_7_2, dist_7_3, dist_7_4, dist_7_5, dist_7_6, dist_7_7;
reg [3:0] diameter_end1, diameter_end2;
reg [3:0] diameter_path_0, diameter_path_1, diameter_path_2, diameter_path_3, diameter_path_4, diameter_path_5, diameter_path_6, diameter_path_7;
reg [3:0] path_length;
reg [3:0] best_diameter;
reg [3:0] best_remove_a, best_remove_b;
reg [3:0] best_add_a, best_add_b;
reg [3:0] temp_dist;

function automatic [3:0] get_dist;
    input [2:0] x, y;
    case (x)
        3'd0: case (y)
            3'd0: get_dist = dist_0_0;
            3'd1: get_dist = dist_0_1;
            3'd2: get_dist = dist_0_2;
            3'd3: get_dist = dist_0_3;
            3'd4: get_dist = dist_0_4;
            3'd5: get_dist = dist_0_5;
            3'd6: get_dist = dist_0_6;
            3'd7: get_dist = dist_0_7;
            default: get_dist = INF;
        endcase
        3'd1: case (y)
            3'd0: get_dist = dist_1_0;
            3'd1: get_dist = dist_1_1;
            3'd2: get_dist = dist_1_2;
            3'd3: get_dist = dist_1_3;
            3'd4: get_dist = dist_1_4;
            3'd5: get_dist = dist_1_5;
            3'd6: get_dist = dist_1_6;
            3'd7: get_dist = dist_1_7;
            default: get_dist = INF;
        endcase
        3'd2: case (y)
            3'd0: get_dist = dist_2_0;
            3'd1: get_dist = dist_2_1;
            3'd2: get_dist = dist_2_2;
            3'd3: get_dist = dist_2_3;
            3'd4: get_dist = dist_2_4;
            3'd5: get_dist = dist_2_5;
            3'd6: get_dist = dist_2_6;
            3'd7: get_dist = dist_2_7;
            default: get_dist = INF;
        endcase
        3'd3: case (y)
            3'd0: get_dist = dist_3_0;
            3'd1: get_dist = dist_3_1;
            3'd2: get_dist = dist_3_2;
            3'd3: get_dist = dist_3_3;
            3'd4: get_dist = dist_3_4;
            3'd5: get_dist = dist_3_5;
            3'd6: get_dist = dist_3_6;
            3'd7: get_dist = dist_3_7;
            default: get_dist = INF;
        endcase
        3'd4: case (y)
            3'd0: get_dist = dist_4_0;
            3'd1: get_dist = dist_4_1;
            3'd2: get_dist = dist_4_2;
            3'd3: get_dist = dist_4_3;
            3'd4: get_dist = dist_4_4;
            3'd5: get_dist = dist_4_5;
            3'd6: get_dist = dist_4_6;
            3'd7: get_dist = dist_4_7;
            default: get_dist = INF;
        endcase
        3'd5: case (y)
            3'd0: get_dist = dist_5_0;
            3'd1: get_dist = dist_5_1;
            3'd2: get_dist = dist_5_2;
            3'd3: get_dist = dist_5_3;
            3'd4: get_dist = dist_5_4;
            3'd5: get_dist = dist_5_5;
            3'd6: get_dist = dist_5_6;
            3'd7: get_dist = dist_5_7;
            default: get_dist = INF;
        endcase
        3'd6: case (y)
            3'd0: get_dist = dist_6_0;
            3'd1: get_dist = dist_6_1;
            3'd2: get_dist = dist_6_2;
            3'd3: get_dist = dist_6_3;
            3'd4: get_dist = dist_6_4;
            3'd5: get_dist = dist_6_5;
            3'd6: get_dist = dist_6_6;
            3'd7: get_dist = dist_6_7;
            default: get_dist = INF;
        endcase
        3'd7: case (y)
            3'd0: get_dist = dist_7_0;
            3'd1: get_dist = dist_7_1;
            3'd2: get_dist = dist_7_2;
            3'd3: get_dist = dist_7_3;
            3'd4: get_dist = dist_7_4;
            3'd5: get_dist = dist_7_5;
            3'd6: get_dist = dist_7_6;
            3'd7: get_dist = dist_7_7;
            default: get_dist = INF;
        endcase
        default: get_dist = INF;
    endcase
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 0;
        new_diameter <= 0;
        remove_a <= 0;
        remove_b <= 0;
        add_a <= 0;
        add_b <= 0;
        i <= 0;
        j <= 0;
        k <= 0;
        counter <= 0;
        path_idx <= 0;
        temp_dist <= 0;
        diameter_end1 <= 0;
        diameter_end2 <= 0;
        path_length <= 0;
        best_diameter <= INF;
        best_remove_a <= 0;
        best_remove_b <= 0;
        best_add_a <= 0;
        best_add_b <= 0;
        dist_0_0 <= 0; dist_0_1 <= 0; dist_0_2 <= 0; dist_0_3 <= 0; dist_0_4 <= 0; dist_0_5 <= 0; dist_0_6 <= 0; dist_0_7 <= 0;
        dist_1_0 <= 0; dist_1_1 <= 0; dist_1_2 <= 0; dist_1_3 <= 0; dist_1_4 <= 0; dist_1_5 <= 0; dist_1_6 <= 0; dist_1_7 <= 0;
        dist_2_0 <= 0; dist_2_1 <= 0; dist_2_2 <= 0; dist_2_3 <= 0; dist_2_4 <= 0; dist_2_5 <= 0; dist_2_6 <= 0; dist_2_7 <= 0;
        dist_3_0 <= 0; dist_3_1 <= 0; dist_3_2 <= 0; dist_3_3 <= 0; dist_3_4 <= 0; dist_3_5 <= 0; dist_3_6 <= 0; dist_3_7 <= 0;
        dist_4_0 <= 0; dist_4_1 <= 0; dist_4_2 <= 0; dist_4_3 <= 0; dist_4_4 <= 0; dist_4_5 <= 0; dist_4_6 <= 0; dist_4_7 <= 0;
        dist_5_0 <= 0; dist_5_1 <= 0; dist_5_2 <= 0; dist_5_3 <= 0; dist_5_4 <= 0; dist_5_5 <= 0; dist_5_6 <= 0; dist_5_7 <= 0;
        dist_6_0 <= 0; dist_6_1 <= 0; dist_6_2 <= 0; dist_6_3 <= 0; dist_6_4 <= 0; dist_6_5 <= 0; dist_6_6 <= 0; dist_6_7 <= 0;
        dist_7_0 <= 0; dist_7_1 <= 0; dist_7_2 <= 0; dist_7_3 <= 0; dist_7_4 <= 0; dist_7_5 <= 0; dist_7_6 <= 0; dist_7_7 <= 0;
        diameter_path_0 <= 0; diameter_path_1 <= 0; diameter_path_2 <= 0; diameter_path_3 <= 0;
        diameter_path_4 <= 0; diameter_path_5 <= 0; diameter_path_6 <= 0; diameter_path_7 <= 0;
    end else begin
        case (state)
            S_IDLE: begin
                if (start) begin
                    state <= S_INIT;
                    i <= 0;
                    j <= 0;
                    counter <= 0;
                end
                done <= 1'b0;
            end
            
            S_INIT: begin
                if (i < node_count) begin
                    if (j < node_count) begin
                        if (i == j) begin
                            case (i)
                                3'd0: begin dist_0_0 <= 0; dist_1_1 <= 0; dist_2_2 <= 0; dist_3_3 <= 0; dist_4_4 <= 0; dist_5_5 <= 0; dist_6_6 <= 0; dist_7_7 <= 0; end
                            endcase
                        end else begin
                            case ({i, j})
                                6'h01: begin dist_0_1 <= INF; dist_1_0 <= INF; end
                                6'h02: begin dist_0_2 <= INF; dist_2_0 <= INF; end
                                6'h03: begin dist_0_3 <= INF; dist_3_0 <= INF; end
                                6'h04: begin dist_0_4 <= INF; dist_4_0 <= INF; end
                                6'h05: begin dist_0_5 <= INF; dist_5_0 <= INF; end
                                6'h06: begin dist_0_6 <= INF; dist_6_0 <= INF; end
                                6'h07: begin dist_0_7 <= INF; dist_7_0 <= INF; end
                                6'h12: begin dist_1_2 <= INF; dist_2_1 <= INF; end
                                6'h13: begin dist_1_3 <= INF; dist_3_1 <= INF; end
                                6'h14: begin dist_1_4 <= INF; dist_4_1 <= INF; end
                                6'h15: begin dist_1_5 <= INF; dist_5_1 <= INF; end
                                6'h16: begin dist_1_6 <= INF; dist_6_1 <= INF; end
                                6'h17: begin dist_1_7 <= INF; dist_7_1 <= INF; end
                                6'h23: begin dist_2_3 <= INF; dist_3_2 <= INF; end
                                6'h24: begin dist_2_4 <= INF; dist_4_2 <= INF; end
                                6'h25: begin dist_2_5 <= INF; dist_5_2 <= INF; end
                                6'h26: begin dist_2_6 <= INF; dist_6_2 <= INF; end
                                6'h27: begin dist_2_7 <= INF; dist_7_2 <= INF; end
                                6'h34: begin dist_3_4 <= INF; dist_4_3 <= INF; end
                                6'h35: begin dist_3_5 <= INF; dist_5_3 <= INF; end
                                6'h36: begin dist_3_6 <= INF; dist_6_3 <= INF; end
                                6'h37: begin dist_3_7 <= INF; dist_7_3 <= INF; end
                                6'h45: begin dist_4_5 <= INF; dist_5_4 <= INF; end
                                6'h46: begin dist_4_6 <= INF; dist_6_4 <= INF; end
                                6'h47: begin dist_4_7 <= INF; dist_7_4 <= INF; end
                                6'h56: begin dist_5_6 <= INF; dist_6_5 <= INF; end
                                6'h57: begin dist_5_7 <= INF; dist_7_5 <= INF; end
                                6'h67: begin dist_6_7 <= INF; dist_7_6 <= INF; end
                            endcase
                        end
                        j <= j + 3'd1;
                    end else begin
                        j <= 0;
                        i <= i + 3'd1;
                    end
                end else begin
                    counter <= node_count - 4'd1;
                    i <= 0;
                end
                if (counter < node_count - 4'd1) begin
                    if (counter == 3'd0) begin
                        if (edge_list_0_a < node_count && edge_list_0_b < node_count) begin
                            case ({edge_list_0_a, edge_list_0_b})
                                16'h0001: begin dist_0_1 <= 1; dist_1_0 <= 1; end
                                16'h0002: begin dist_0_2 <= 1; dist_2_0 <= 1; end
                                16'h0003: begin dist_0_3 <= 1; dist_3_0 <= 1; end
                                16'h0004: begin dist_0_4 <= 1; dist_4_0 <= 1; end
                                16'h0005: begin dist_0_5 <= 1; dist_5_0 <= 1; end
                                16'h0006: begin dist_0_6 <= 1; dist_6_0 <= 1; end
                                16'h0007: begin dist_0_7 <= 1; dist_7_0 <= 1; end
                                16'h0102: begin dist_1_2 <= 1; dist_2_1 <= 1; end
                                16'h0103: begin dist_1_3 <= 1; dist_3_1 <= 1; end
                                16'h0104: begin dist_1_4 <= 1; dist_4_1 <= 1; end
                                16'h0105: begin dist_1_5 <= 1; dist_5_1 <= 1; end
                                16'h0106: begin dist_1_6 <= 1; dist_6_1 <= 1; end
                                16'h0107: begin dist_1_7 <= 1; dist_7_1 <= 1; end
                                16'h0203: begin dist_2_3 <= 1; dist_3_2 <= 1; end
                                16'h0204: begin dist_2_4 <= 1; dist_4_2 <= 1; end
                                16'h0205: begin dist_2_5 <= 1; dist_5_2 <= 1; end
                                16'h0206: begin dist_2_6 <= 1; dist_6_2 <= 1; end
                                16'h0207: begin dist_2_7 <= 1; dist_7_2 <= 1; end
                                16'h0304: begin dist_3_4 <= 1; dist_4_3 <= 1; end
                                16'h0305: begin dist_3_5 <= 1; dist_5_3 <= 1; end
                                16'h0306: begin dist_3_6 <= 1; dist_6_3 <= 1; end
                                16'h0307: begin dist_3_7 <= 1; dist_7_3 <= 1; end
                                16'h0405: begin dist_4_5 <= 1; dist_5_4 <= 1; end
                                16'h0406: begin dist_4_6 <= 1; dist_6_4 <= 1; end
                                16'h0407: begin dist_4_7 <= 1; dist_7_4 <= 1; end
                                16'h0506: begin dist_5_6 <= 1; dist_6_5 <= 1; end
                                16'h0507: begin dist_5_7 <= 1; dist_7_5 <= 1; end
                                16'h0607: begin dist_6_7 <= 1; dist_7_6 <= 1; end
                            endcase
                        end
                    end
                    counter <= counter + 3'd1;
                end else begin
                    if (i >= node_count) begin
                        state <= S_FLOYD;
                        i <= 0;
                        j <= 0;
                        k <= 0;
                    end
                end
            end
            
            S_FLOYD: begin
                if (k < node_count) begin
                    if (i < node_count) begin
                        if (j < node_count) begin
                            temp_dist <= get_dist(i, k) + get_dist(k, j);
                            if (get_dist(i, k) + get_dist(k, j) < get_dist(i, j)) begin
                                case ({i, j})
                                    6'h00: if (j == 3'd0) dist_0_0 <= temp_dist; end
                                    6'h01: if (j == 3'd1) dist_0_1 <= temp_dist; end
                                    6'h02: if (j == 3'd2) dist_0_2 <= temp_dist; end
                                    6'h03: if (j == 3'd3) dist_0_3 <= temp_dist; end
                                    6'h04: if (j == 3'd4) dist_0_4 <= temp_dist; end
                                    6'h05: if (j == 3'd5) dist_0_5 <= temp_dist; end
                                    6'h06: if (j == 3'd6) dist_0_6 <= temp_dist; end
                                    6'h07: if (j == 3'd7) dist_0_7 <= temp_dist; end
                                    6'h10: if (j == 3'd0) dist_1_0 <= temp_dist; end
                                    6'h11: if (j == 3'd1) dist_1_1 <= temp_dist; end
                                    6'h12: if (j == 3'd2) dist_1_2 <= temp_dist; end
                                    6'h13: if (j == 3'd3) dist_1_3 <= temp_dist; end
                                    6'h14: if (j == 3'd4) dist_1_4 <= temp_dist; end
                                    6'h15: if (j == 3'd5) dist_1_5 <= temp_dist; end
                                    6'h16: if (j == 3'd6) dist_1_6 <= temp_dist; end
                                    6'h17: if (j == 3'd7) dist_1_7 <= temp_dist; end
                                    6'h20: if (j == 3'd0) dist_2_0 <= temp_dist; end
                                    6'h21: if (j == 3'd1) dist_2_1 <= temp_dist; end
                                    6'h22: if (j == 3'd2) dist_2_2 <= temp_dist; end
                                    6'h23: if (j == 3'd3) dist_2_3 <= temp_dist; end
                                    6'h24: if (j == 3'd4) dist_2_4 <= temp_dist; end
                                    6'h25: if (j == 3'd5) dist_2_5 <= temp_dist; end
                                    6'h26: if (j == 3'd6) dist_2_6 <= temp_dist; end
                                    6'h27: if (j == 3'd7) dist_2_7 <= temp_dist; end
                                    6'h30: if (j == 3'd0) dist_3_0 <= temp_dist; end
                                    6'h31: if (j == 3'd1) dist_3_1 <= temp_dist; end
                                    6'h32: if (j == 3'd2) dist_3_2 <= temp_dist; end
                                    6'h33: if (j == 3'd3) dist_3_3 <= temp_dist; end
                                    6'h34: if (j == 3'd4) dist_3_4 <= temp_dist; end
                                    6'h35: if (j == 3'd5) dist_3_5 <= temp_dist; end
                                    6'h36: if (j == 3'd6) dist_3_6 <= temp_dist; end
                                    6'h37: if (j == 3'd7) dist_3_7 <= temp_dist; end
                                    6'h40: if (j == 3'd0) dist_4_0 <= temp_dist; end
                                    6'h41: if (j == 3'd1) dist_4_1 <= temp_dist; end
                                    6'h42: if (j == 3'd2) dist_4_2 <= temp_dist; end
                                    6'h43: if (j == 3'd3) dist_4_3 <= temp_dist; end
                                    6'h44: if (j == 3'd4) dist_4_4 <= temp_dist; end
                                    6'h45: if (j == 3'd5) dist_4_5 <= temp_dist; end
                                    6'h46: if (j == 3'd6) dist_4_6 <= temp_dist; end
                                    6'h47: if (j == 3'd7) dist_4_7 <= temp_dist; end
                                    6'h50: if (j == 3'd0) dist_5_0 <= temp_dist; end
                                    6'h51: if (j == 3'd1) dist_5_1 <= temp_dist; end
                                    6'h52: if (j == 3'd2) dist_5_2 <= temp_dist; end
                                    6'h53: if (j == 3'd3) dist_5_3 <= temp_dist; end
                                    6'h54: if (j == 3'd4) dist_5_4 <= temp_dist; end
                                    6'h55: if (j == 3'd5) dist_5_5 <= temp_dist; end
                                    6'h56: if (j == 3'd6) dist_5_6 <= temp_dist; end
                                    6'h57: if (j == 3'd7) dist_5_7 <= temp_dist; end
                                    6'h60: if (j == 3'd0) dist_6_0 <= temp_dist; end
                                    6'h61: if (j == 3'd1) dist_6_1 <= temp_dist; end
                                    6'h62: if (j == 3'd2) dist_6_2 <= temp_dist; end
                                    6'h63: if (j == 3'd3) dist_6_3 <= temp_dist; end
                                    6'h64: if (j == 3'd4) dist_6_4 <= temp_dist; end
                                    6'h65: if (j == 3'd5) dist_6_5 <= temp_dist; end
                                    6'h66: if (j == 3'd6) dist_6_6 <= temp_dist; end
                                    6'h67: if (j == 3'd7) dist_6_7 <= temp_dist; end
                                    6'h70: if (j == 3'd0) dist_7_0 <= temp_dist; end
                                    6'h71: if (j == 3'd1) dist_7_1 <= temp_dist; end
                                    6'h72: if (j == 3'd2) dist_7_2 <= temp_dist; end
                                    6'h73: if (j == 3'd3) dist_7_3 <= temp_dist; end
                                    6'h74: if (j == 3'd4) dist_7_4 <= temp_dist; end
                                    6'h75: if (j == 3'd5) dist_7_5 <= temp_dist; end
                                    6'h76: if (j == 3'd6) dist_7_6 <= temp_dist; end
                                    6'h77: if (j == 3'd7) dist_7_7 <= temp_dist; end
                                endcase
                            end
                            j <= j + 3'd1;
                        end else begin
                            j <= 0;
                            i <= i + 3'd1;
                        end
                    end else begin
                        i <= 0;
                        k <= k + 3'd1;
                    end
                end else begin
                    state <= S_FIND_DIA;
                    diameter_end1 <= 0;
                    diameter_end2 <= 0;
                    i <= 0;
                    j <= 0;
                end
            end
            
            S_FIND_DIA: begin
                if (i < node_count) begin
                    if (j < node_count) begin
                        if (get_dist(i, j) > get_dist(diameter_end1, diameter_end2)) begin
                            diameter_end1 <= i;
                            diameter_end2 <= j;
                        end
                        j <= j + 3'd1;
                    end else begin
                        j <= 0;
                        i <= i + 3'd1;
                    end
                end else begin
                    state <= S_FIND_PATH;
                    path_length <= 0;
                    path_idx <= 0;
                    i <= diameter_end1;
                end
            end
            
            S_FIND_PATH: begin
                if (i != diameter_end2) begin
                    for (k = 0; k < node_count; k = k + 3'd1) begin
                        if (k != i && get_dist(i, k) == 4'd1 && get_dist(k, diameter_end2) + 4'd1 == get_dist(i, diameter_end2)) begin
                            if (path_idx < node_count) begin
                                case (path_idx)
                                    3'd0: diameter_path_0 <= i;
                                    3'd1: diameter_path_1 <= i;
                                    3'd2: diameter_path_2 <= i;
                                    3'd3: diameter_path_3 <= i;
                                    3'd4: diameter_path_4 <= i;
                                    3'd5: diameter_path_5 <= i;
                                    3'd6: diameter_path_6 <= i;
                                    3'd7: diameter_path_7 <= i;
                                endcase
                                path_idx <= path_idx + 3'd1;
                                i <= k;
                            end
                        end
                    end
                end else begin
                    if (path_idx < node_count) begin
                        case (path_idx)
                            3'd0: diameter_path_0 <= diameter_end2;
                            3'd1: diameter_path_1 <= diameter_end2;
                            3'd2: diameter_path_2 <= diameter_end2;
                            3'd3: diameter_path_3 <= diameter_end2;
                            3'd4: diameter_path_4 <= diameter_end2;
                            3'd5: diameter_path_5 <= diameter_end2;
                            3'd6: diameter_path_6 <= diameter_end2;
                            3'd7: diameter_path_7 <= diameter_end2;
                        endcase
                        path_idx <= path_idx + 3'd1;
                    end
                    path_length <= path_idx + 4'd1;
                    state <= S_BREAK_EDGE;
                    counter <= 0;
                    best_diameter <= INF;
                end
            end
            
            S_BREAK_EDGE: begin
                if (counter < path_length - 4'd1) begin
                    new_diameter <= get_dist(diameter_path_0, diameter_path[path_length - 4'd1]) - 4'd1;
                    case (counter)
                        3'd0: begin remove_a <= diameter_path_0; remove_b <= diameter_path_1; add_a <= diameter_path_0; add_b <= diameter_path[path_length - 4'd1]; end
                        3'd1: begin remove_a <= diameter_path_1; remove_b <= diameter_path_2; add_a <= diameter_path_1; add_b <= diameter_path[path_length - 4'd1]; end
                        3'd2: begin remove_a <= diameter_path_2; remove_b <= diameter_path_3; add_a <= diameter_path_2; add_b <= diameter_path[path_length - 4'd1]; end
                        3'd3: begin remove_a <= diameter_path_3; remove_b <= diameter_path_4; add_a <= diameter_path_3; add_b <= diameter_path[path_length - 4'd1]; end
                        3'd4: begin remove_a <= diameter_path_4; remove_b <= diameter_path_5; add_a <= diameter_path_4; add_b <= diameter_path[path_length - 4'd1]; end
                        3'd5: begin remove_a <= diameter_path_5; remove_b <= diameter_path_6; add_a <= diameter_path_5; add_b <= diameter_path[path_length - 4'd1]; end
                        3'd6: begin remove_a <= diameter_path_6; remove_b <= diameter_path_7; add_a <= diameter_path_6; add_b <= diameter_path[path_length - 4'd1]; end
                    endcase
                    if (new_diameter < best_diameter) begin
                        best_diameter <= new_diameter;
                        case (counter)
                            3'd0: begin best_remove_a <= diameter_path_0; best_remove_b <= diameter_path_1; best_add_a <= diameter_path_0; best_add_b <= diameter_path[path_length - 4'd1]; end
                            3'd1: begin best_remove_a <= diameter_path_1; best_remove_b <= diameter_path_2; best_add_a <= diameter_path_1; best_add_b <= diameter_path[path_length - 4'd1]; end
                            3'd2: begin best_remove_a <= diameter_path_2; best_remove_b <= diameter_path_3; best_add_a <= diameter_path_2; best_add_b <= diameter_path[path_length - 4'd1]; end
                            3'd3: begin best_remove_a <= diameter_path_3; best_remove_b <= diameter_path_4; best_add_a <= diameter_path_3; best_add_b <= diameter_path[path_length - 4'd1]; end
                            3'd4: begin best_remove_a <= diameter_path_4; best_remove_b <= diameter_path_5; best_add_a <= diameter_path_4; best_add_b <= diameter_path[path_length - 4'd1]; end
                            3'd5: begin best_remove_a <= diameter_path_5; best_remove_b <= diameter_path_6; best_add_a <= diameter_path_5; best_add_b <= diameter_path[path_length - 4'd1]; end
                            3'd6: begin best_remove_a <= diameter_path_6; best_remove_b <= diameter_path_7; best_add_a <= diameter_path_6; best_add_b <= diameter_path[path_length - 4'd1]; end
                        endcase
                    end
                    counter <= counter + 3'd1;
                end else begin
                    state <= S_DONE;
                    new_diameter <= best_diameter;
                    remove_a <= best_remove_a;
                    remove_b <= best_remove_b;
                    add_a <= best_add_a;
                    add_b <= best_add_b;
                    done <= 1;
                end
            end
            
            S_DONE: begin
                if (!start) begin
                    done <= 0;
                end
            end
            
            default: state <= S_IDLE;
        endcase
    end
end

endmodule