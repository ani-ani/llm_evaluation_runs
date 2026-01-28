module protest_optimization(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] x_coords [0:7],
    input wire signed [7:0] y_coords [0:7],
    input wire [3:0] n,
    input wire [7:0] d,
    output reg [15:0] result,
    output reg done,
    output reg impossible
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_BOUNDS = 3'd1;
    localparam [2:0] SEARCH_X = 3'd2;
    localparam [2:0] SEARCH_Y = 3'd3;
    localparam [2:0] CHECK_FEASIBLE = 3'd4;
    localparam [2:0] COMPUTE_DISTANCE = 3'd5;
    localparam [2:0] UPDATE_MIN = 3'd6;
    localparam [2:0] DONE = 3'd7;

    // Internal registers
    reg [2:0] state;
    reg signed [7:0] min_x, max_x;
    reg signed [7:0] min_y, max_y;
    reg [3:0] citizen_idx;
    reg signed [7:0] search_x, search_y;
    reg signed [7:0] x_star, y_star;
    reg [7:0] distance_check;
    reg [15:0] total_distance;
    reg [15:0] best_distance;
    reg feasible;
    reg [3:0] check_idx;
    reg [7:0] manhattan_dist;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            min_x <= 8'sd0;
            max_x <= 8'sd0;
            min_y <= 8'sd0;
            max_y <= 8'sd0;
            search_x <= 8'sd0;
            search_y <= 8'sd0;
            x_star <= 8'sd0;
            y_star <= 8'sd0;
            total_distance <= 16'd0;
            best_distance <= 16'd16'hFFFF;
            feasible <= 1'b0;
            citizen_idx <= 4'd0;
            check_idx <= 4'd0;
            distance_check <= 8'd0;
            manhattan_dist <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    best_distance <= 16'hFFFF;
                    feasible <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_BOUNDS;
                        citizen_idx <= 4'd0;
                        min_x <= x_coords[0];
                        max_x <= x_coords[0];
                        min_y <= y_coords[0];
                        max_y <= y_coords[0];
                    end
                end

                COMPUTE_BOUNDS: begin
                    if (citizen_idx < n) begin
                        if (x_coords[citizen_idx] < min_x)
                            min_x <= x_coords[citizen_idx];
                        if (x_coords[citizen_idx] > max_x)
                            max_x <= x_coords[citizen_idx];
                        if (y_coords[citizen_idx] < min_y)
                            min_y <= y_coords[citizen_idx];
                        if (y_coords[citizen_idx] > max_y)
                            max_y <= y_coords[citizen_idx];
                        citizen_idx <= citizen_idx + 1'b1;
                    end else begin
                        search_x <= min_x - d;
                        search_y <= min_y - d;
                        state <= SEARCH_X;
                    end
                end

                SEARCH_X: begin
                    if (search_x <= max_x + d) begin
                        search_y <= min_y - d;
                        state <= SEARCH_Y;
                    end else begin
                        if (!feasible)
                            impossible <= 1'b1;
                        state <= DONE;
                    end
                end

                SEARCH_Y: begin
                    if (search_y <= max_y + d) begin
                        x_star <= search_x;
                        y_star <= search_y;
                        check_idx <= 4'd0;
                        feasible <= 1'b1;
                        state <= CHECK_FEASIBLE;
                    end else begin
                        search_x <= search_x + 1'b1;
                        state <= SEARCH_X;
                    end
                end

                CHECK_FEASIBLE: begin
                    if (check_idx < n) begin
                        if (search_x > x_coords[check_idx])
                            dx <= search_x - x_coords[check_idx];
                        else
                            dx <= x_coords[check_idx] - search_x;
                        if (search_y > y_coords[check_idx])
                            dy <= search_y - y_coords[check_idx];
                        else
                            dy <= y_coords[check_idx] - search_y;
                        distance_check <= dx + dy;
                        check_idx <= check_idx + 1'b1;
                    end else begin
                        if (feasible) begin
                            check_idx <= 4'd0;
                            total_distance <= 16'd0;
                            state <= COMPUTE_DISTANCE;
                        end else begin
                            search_y <= search_y + 1'b1;
                            state <= SEARCH_Y;
                        end
                    end
                end

                COMPUTE_DISTANCE: begin
                    if (check_idx < n) begin
                        if (x_star > x_coords[check_idx])
                            dx <= x_star - x_coords[check_idx];
                        else
                            dx <= x_coords[check_idx] - x_star;
                        if (y_star > y_coords[check_idx])
                            dy <= y_star - y_coords[check_idx];
                        else
                            dy <= y_coords[check_idx] - y_star;
                        manhattan_dist <= dx + dy;
                        total_distance <= total_distance + manhattan_dist;
                        check_idx <= check_idx + 1'b1;
                    end else begin
                        state <= UPDATE_MIN;
                    end
                end

                UPDATE_MIN: begin
                    if (total_distance < best_distance) begin
                        best_distance <= total_distance;
                    end
                    search_y <= search_y + 1'b1;
                    state <= SEARCH_Y;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!impossible) begin
                        result <= best_distance;
                    end else begin
                        result <= 16'd0;
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Intermediate calculations
    reg signed [8:0] dx, dy;

    always @(posedge clk) begin
        if (state == CHECK_FEASIBLE && check_idx < n) begin
            if (dx + dy > d)
                feasible <= 1'b0;
        end
    end

endmodule