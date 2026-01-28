module moving_walkways(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [31:0] a_x,
    input wire signed [31:0] a_y,
    input wire signed [31:0] b_x,
    input wire signed [31:0] b_y,
    input wire signed [31:0] c0_x1,
    input wire signed [31:0] c0_y1,
    input wire signed [31:0] c0_x2,
    input wire signed [31:0] c0_y2,
    input wire c0_valid,
    input wire signed [31:0] c1_x1,
    input wire signed [31:0] c1_y1,
    input wire signed [31:0] c1_x2,
    input wire signed [31:0] c1_y2,
    input wire c1_valid,
    input wire signed [31:0] c2_x1,
    input wire signed [31:0] c2_y1,
    input wire signed [31:0] c2_x2,
    input wire signed [31:0] c2_y2,
    input wire c2_valid,
    output reg signed [31:0] result,
    output reg done
);

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] DISCRETIZE = 4'd1;
    localparam [3:0] ENUMERATE = 4'd2;
    localparam [3:0] COMPUTE = 4'd3;
    localparam [3:0] DONE_STATE = 4'd4;

    localparam [7:0] MAX_CYCLES = 8'd2000000;

    reg [3:0] state, next_state;
    reg [7:0] cycle_count;

    localparam [4:0] MAX_CONVEYORS = 5'd3;
    localparam [2:0] K = 3'd5;
    localparam [7:0] NODES = 8'd17;

    reg signed [31:0] conveyor_points [0:16][0:1];
    reg [2:0] conveyor_sequence [0:2];
    reg [2:0] current_sequence_length;
    reg [2:0] current_conveyor_index;
    reg [2:0] current_point_index;
    reg [2:0] entry_point [0:2];
    reg [2:0] exit_point [0:2];
    reg signed [31:0] current_time;
    reg signed [31:0] min_time;
    reg [7:0] path_counter;
    reg [7:0] point_counter;
    reg [7:0] sequence_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            current_sequence_length <= 3'd0;
            current_conveyor_index <= 3'd0;
            current_point_index <= 3'd0;
            path_counter <= 8'd0;
            point_counter <= 8'd0;
            sequence_counter <= 8'd0;
            result <= 32'd0;
            done <= 1'b0;
            min_time <= 32'd0;
            current_time <= 32'd0;

            integer i, j;
            for (i = 0; i < 17; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    conveyor_points[i][j] <= 32'd0;
                end
            end

            for (i = 0; i < 3; i = i + 1) begin
                conveyor_sequence[i] <= 3'd0;
                entry_point[i] <= 3'd0;
                exit_point[i] <= 3'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= DISCRETIZE;
                        cycle_count <= 8'd0;
                        min_time <= 32'd0;
                    end
                end

                DISCRETIZE: begin
                    if (cycle_count == 8'd0) begin
                        conveyor_points[0][0] <= a_x;
                        conveyor_points[0][1] <= a_y;
                        conveyor_points[1][0] <= b_x;
                        conveyor_points[1][1] <= b_y;
                    end

                    if (c0_valid && cycle_count < 8'd6) begin
                        conveyor_points[2 + cycle_count][0] <= c0_x1 + ((c0_x2 - c0_x1) * cycle_count) / 5;
                        conveyor_points[2 + cycle_count][1] <= c0_y1 + ((c0_y2 - c0_y1) * cycle_count) / 5;
                    end

                    if (c1_valid && cycle_count < 8'd11) begin
                        conveyor_points[7 + (cycle_count - 5)][0] <= c1_x1 + ((c1_x2 - c1_x1) * (cycle_count - 5)) / 5;
                        conveyor_points[7 + (cycle_count - 5)][1] <= c1_y1 + ((c1_y2 - c1_y1) * (cycle_count - 5)) / 5;
                    end

                    if (c2_valid && cycle_count < 8'd16) begin
                        conveyor_points[12 + (cycle_count - 10)][0] <= c2_x1 + ((c2_x2 - c2_x1) * (cycle_count - 10)) / 5;
                        conveyor_points[12 + (cycle_count - 10)][1] <= c2_y1 + ((c2_y2 - c2_y1) * (cycle_count - 10)) / 5;
                    end

                    if (cycle_count >= 8'd15) begin
                        next_state <= ENUMERATE;
                        cycle_count <= 8'd0;
                    end
                end

                ENUMERATE: begin
                    if (cycle_count == 8'd0) begin
                        current_sequence_length <= 3'd0;
                        sequence_counter <= 8'd0;
                        path_counter <= 8'd0;
                    end

                    if (current_sequence_length < 3'd4) begin
                        if (sequence_counter < 8'd100) begin
                            if (path_counter < 8'd100) begin
                                next_state <= COMPUTE;
                                cycle_count <= 8'd0;
                            end else begin
                                path_counter <= 8'd0;
                                sequence_counter <= sequence_counter + 8'd1;
                            end
                        end else begin
                            sequence_counter <= 8'd0;
                            current_sequence_length <= current_sequence_length + 3'd1;
                        end
                    end else begin
                        next_state <= DONE_STATE;
                        cycle_count <= 8'd0;
                    end
                end

                COMPUTE: begin
                    if (cycle_count == 8'd0) begin
                        current_time <= 32'd0;
                        current_conveyor_index <= 3'd0;
                        current_point_index <= 3'd0;
                    end

                    if (current_conveyor_index < current_sequence_length) begin
                        if (current_point_index < 3'd5) begin
                            current_time <= current_time + compute_distance(
                                conveyor_points[entry_point[current_conveyor_index]][0],
                                conveyor_points[entry_point[current_conveyor_index]][1],
                                conveyor_points[exit_point[current_conveyor_index]][0],
                                conveyor_points[exit_point[current_conveyor_index]][1]
                            );
                            current_point_index <= current_point_index + 3'd1;
                        end else begin
                            current_point_index <= 3'd0;
                            current_conveyor_index <= current_conveyor_index + 3'd1;
                        end
                    end else begin
                        if (current_time < min_time || min_time == 32'd0) begin
                            min_time <= current_time;
                        end
                        next_state <= ENUMERATE;
                        cycle_count <= 8'd0;
                    end
                end

                DONE_STATE: begin
                    result <= min_time;
                    done <= 1'b1;
                    next_state <= IDLE;
                    cycle_count <= 8'd0;
                end

                default: begin
                    next_state <= IDLE;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end

    function signed [31:0] compute_distance(
        input signed [31:0] x1,
        input signed [31:0] y1,
        input signed [31:0] x2,
        input signed [31:0] y2
    );
        signed [31:0] dx, dy, dist_sq, dist;
        signed [63:0] temp;
        integer i;

        dx = x2 - x1;
        dy = y2 - y1;
        dist_sq = (dx * dx) + (dy * dy);

        if (dist_sq == 32'd0) begin
            compute_distance = 32'd0;
        end else begin
            dist = 32'd1;
            for (i = 0; i < 10; i = i + 1) begin
                temp = (32'd0 << 32) + (dist_sq << 16) - (dist * dist * dist_sq);
                dist = dist + (temp[63:32] >> 1);
            end
            compute_distance = dist;
        end
    endfunction

endmodule