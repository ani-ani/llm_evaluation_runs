module phaser_optimal(
    input clk,
    input rst_n,
    input start,
    input [3:0] room_count,
    input [7:0][31:0] room_x1,
    input [7:0][31:0] room_y1,
    input [7:0][31:0] room_x2,
    input [7:0][31:0] room_y2,
    input [31:0] beam_length,
    output reg [3:0] max_rooms,
    output reg done
);

    parameter N = 8;
    parameter MAX_CORNERS = 32;

    localparam IDLE = 4'b0001;
    localparam EXTRACT_CORNERS = 4'b0010;
    localparam GENERATE_RAYS = 4'b0100;
    localparam INTERSECT_CHECK = 4'b1000;
    localparam DONE = 4'b0000;
    localparam UPDATE_MAX = 4'b1010;

    reg [3:0] current_state, next_state;

    reg [31:0] corner_x [0:MAX_CORNERS-1];
    reg [31:0] corner_y [0:MAX_CORNERS-1];
    reg [5:0] corner_idx;
    reg [2:0] corner_sub_idx;
    reg [3:0] room_extract_idx;

    reg [5:0] p1_idx;
    reg [5:0] p2_idx;

    reg signed [31:0] ray_sx;
    reg signed [31:0] ray_sy;
    reg signed [31:0] ray_ex;
    reg signed [31:0] ray_ey;
    reg signed [31:0] ray_dx;
    reg signed [31:0] ray_dy;
    reg signed [63:0] ray_len_sq;

    reg [3:0] check_room_idx;
    reg [3:0] current_hit_count;

    reg [31:0] curr_x1, curr_y1, curr_x2, curr_y2;

    wire hit;
    wire signed [31:0] rx1, ry1, rx2, ry2;
    wire signed [31:0] seg_x0, seg_y0, seg_x1, seg_y1;

    assign rx1 = (room_x1[check_room_idx] < room_x2[check_room_idx]) ? room_x1[check_room_idx] : room_x2[check_room_idx];
    assign ry1 = (room_y1[check_room_idx] < room_y2[check_room_idx]) ? room_y1[check_room_idx] : room_y2[check_room_idx];
    assign rx2 = (room_x1[check_room_idx] > room_x2[check_room_idx]) ? room_x1[check_room_idx] : room_x2[check_room_idx];
    assign ry2 = (room_y1[check_room_idx] > room_y2[check_room_idx]) ? room_y1[check_room_idx] : room_y2[check_room_idx];

    assign seg_x0 = ray_sx;
    assign seg_y0 = ray_sy;
    assign seg_x1 = ray_ex;
    assign seg_y1 = ray_ey;

    reg signed [63:0] t1, t2, t3, t4, num, den;
    reg signed [63:0] p, q;
    reg signed [63:0] t0, tE, tL;
    reg intersection_found;

    always @(*) begin
        tE = 0;
        tL = 64'sd65536;
        intersection_found = 0;

        p = -(seg_x1 - seg_x0);
        q = -(seg_x0 - rx1);
        if (p == 0) begin
            if (q < 0) intersection_found = 0;
            else intersection_found = 1;
        end else begin
            t1 = (q << 16) / p;
        end

        intersection_found = 0;

        if (seg_x0 < rx1 && seg_x1 < rx1) intersection_found = 0;
        else if (seg_x0 > rx2 && seg_x1 > rx2) intersection_found = 0;
        else if (seg_y0 < ry1 && seg_y1 < ry1) intersection_found = 0;
        else if (seg_y0 > ry2 && seg_y1 > ry2) intersection_found = 0;
        else begin
            if ((seg_x0 >= rx1 && seg_x0 <= rx2 && seg_y0 >= ry1 && seg_y0 <= ry2) ||
                (seg_x1 >= rx1 && seg_x1 <= rx2 && seg_y1 >= ry1 && seg_y1 <= ry2)) begin
                intersection_found = 1;
            end else begin
                ray_dx = seg_x1 - seg_x0;
                ray_dy = seg_y1 - seg_y0;

                if (ray_dx != 0) begin
                    t1 = ( (rx1 - seg_x0) << 16 ) / ray_dx;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            max_rooms <= 0;
            done <= 0;
            corner_idx <= 0;
            p1_idx <= 0;
            p2_idx <= 0;
            ray_count <= 0;
            room_extract_idx <= 0;
            check_room_idx <= 0;
            current_hit_count <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    max_rooms <= 0;
                    if (start) begin
                        current_state <= EXTRACT_CORNERS;
                        corner_idx <= 0;
                        room_extract_idx <= 0;
                        corner_sub_idx <= 0;
                    end
                end

                EXTRACT_CORNERS: begin
                    if (room_extract_idx < room_count) begin
                        curr_x1 <= room_x1[room_extract_idx];
                        curr_y1 <= room_y1[room_extract_idx];
                        curr_x2 <= room_x2[room_extract_idx];
                        curr_y2 <= room_y2[room_extract_idx];

                        case (corner_sub_idx)
                            0: begin
                                corner_x[corner_idx] <= room_x1[room_extract_idx];
                                corner_y[corner_idx] <= room_y1[room_extract_idx];
                            end
                            1: begin
                                corner_x[corner_idx] <= room_x1[room_extract_idx];
                                corner_y[corner_idx] <= room_y2[room_extract_idx];
                            end
                            2: begin
                                corner_x[corner_idx] <= room_x2[room_extract_idx];
                                corner_y[corner_idx] <= room_y1[room_extract_idx];
                            end
                            3: begin
                                corner_x[corner_idx] <= room_x2[room_extract_idx];
                                corner_y[corner_idx] <= room_y2[room_extract_idx];
                            end
                        endcase

                        corner_sub_idx <= corner_sub_idx + 1;
                        corner_idx <= corner_idx + 1;

                        if (corner_sub_idx == 3) begin
                            room_extract_idx <= room_extract_idx + 1;
                            corner_sub_idx <= 0;
                        end
                    end else begin
                        current_state <= GENERATE_RAYS;
                        p1_idx <= 0;
                        p2_idx <= 1;
                    end
                end

                GENERATE_RAYS: begin
                    if ( (p1_idx >> 2) == (p2_idx >> 2) ) begin
                        p2_idx <= p2_idx + 1;
                    end else begin
                        ray_sx <= corner_x[p1_idx];
                        ray_sy <= corner_y[p1_idx];

                        ray_dx <= $signed(corner_x[p2_idx]) - $signed(corner_x[p1_idx]);
                        ray_dy <= $signed(corner_y[p2_idx]) - $signed(corner_y[p1_idx]);

                        ray_len_sq <= (ray_dx * ray_dx) + (ray_dy * ray_dy);

                        p2_idx <= p2_idx + 1;
                        if (p2_idx >= (corner_idx - 1)) begin
                            p2_idx <= p1_idx + 2;
                            p1_idx <= p1_idx + 1;
                            if (p1_idx >= (corner_idx - 2)) begin
                                current_state <= UPDATE_MAX;
                            end else begin
                                current_state <= INTERSECT_CHECK;
                                check_room_idx <= 0;
                                current_hit_count <= 0;
                            end
                        end else begin
                            current_state <= INTERSECT_CHECK;
                            check_room_idx <= 0;
                            current_hit_count <= 0;
                        end
                    end
                end

                INTERSECT_CHECK: begin
                    if (check_room_idx < room_count) begin
                        if (intersection_found) begin
                            current_hit_count <= current_hit_count + 1;
                        end
                        check_room_idx <= check_room_idx + 1;
                    end else begin
                        current_state <= UPDATE_MAX;
                    end
                end

                UPDATE_MAX: begin
                    if (current_hit_count > max_rooms) begin
                        max_rooms <= current_hit_count;
                    end

                    p2_idx <= p2_idx + 1;

                    if (p2_idx >= (corner_idx - 1)) begin
                        p2_idx <= p1_idx + 2;
                        p1_idx <= p1_idx + 1;

                        if (p1_idx >= (corner_idx - 2)) begin
                            current_state <= DONE;
                        end else begin
                            current_state <= GENERATE_RAYS;
                        end
                    end else begin
                        current_state <= GENERATE_RAYS;
                    end
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    function automatic signed [63:0] cross_product;
        input signed [31:0] px, py, qx, qy, rx, ry;
        begin
            cross_product = ( (qx - px) * (ry - py) ) - ( (qy - py) * (rx - px) );
        end
    endfunction
endmodule