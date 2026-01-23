module collinear_checker (
    input clk,
    input rst_n,
    input start,
    input [7:0] point_x [0:15],
    input [7:0] point_y [0:15],
    input [4:0] num_points,
    output reg success,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CHECK_COLLINEAR,
        STRATEGY_A,
        STRATEGY_B,
        STRATEGY_C,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [3:0] index;
    reg [3:0] remaining_index;
    reg [3:0] remaining_count;
    reg [15:0] flag;
    reg [17:0] cross_product;
    reg [7:0] x0, y0, x1, y1, x2, y2;
    reg [7:0] line_x0, line_y0, line_x1, line_y1;
    reg [7:0] remaining_x0, remaining_y0, remaining_x1, remaining_y1;
    reg [7:0] temp_x, temp_y;
    reg all_collinear;
    reg strategy_a_pass, strategy_b_pass, strategy_c_pass;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            index <= 0;
            remaining_index <= 0;
            remaining_count <= 0;
            flag <= 0;
            cross_product <= 0;
            x0 <= 0; y0 <= 0; x1 <= 0; y1 <= 0; x2 <= 0; y2 <= 0;
            line_x0 <= 0; line_y0 <= 0; line_x1 <= 0; line_y1 <= 0;
            remaining_x0 <= 0; remaining_y0 <= 0; remaining_x1 <= 0; remaining_y1 <= 0;
            temp_x <= 0; temp_y <= 0;
            all_collinear <= 0;
            strategy_a_pass <= 0; strategy_b_pass <= 0; strategy_c_pass <= 0;
            success <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
            if (current_state == CHECK_COLLINEAR && index < num_points - 1) begin
                index <= index + 1;
            end else if (current_state == STRATEGY_A || current_state == STRATEGY_B || current_state == STRATEGY_C) begin
                if (remaining_index < num_points - 1) begin
                    remaining_index <= remaining_index + 1;
                end
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_COLLINEAR;
                    index = 0;
                    remaining_index = 0;
                    remaining_count = 0;
                    flag = 0;
                    all_collinear = 1;
                    strategy_a_pass = 0;
                    strategy_b_pass = 0;
                    strategy_c_pass = 0;
                    success = 0;
                    done = 0;
                end
            end
            CHECK_COLLINEAR: begin
                if (index == num_points - 1) begin
                    if (all_collinear || num_points < 3) begin
                        next_state = DONE;
                        success = 1;
                        done = 1;
                    end else begin
                        next_state = STRATEGY_A;
                        index = 0;
                        remaining_index = 0;
                        remaining_count = 0;
                        flag = 0;
                        line_x0 = point_x[0]; line_y0 = point_y[0];
                        line_x1 = point_x[1]; line_y1 = point_y[1];
                    end
                end
            end
            STRATEGY_A: begin
                if (remaining_index == num_points - 1) begin
                    if (remaining_count <= 1) begin
                        next_state = DONE;
                        success = 1;
                        done = 1;
                    end else begin
                        next_state = STRATEGY_B;
                        index = 0;
                        remaining_index = 0;
                        remaining_count = 0;
                        flag = 0;
                        line_x0 = point_x[0]; line_y0 = point_y[0];
                        line_x1 = point_x[2]; line_y1 = point_y[2];
                    end
                end
            end
            STRATEGY_B: begin
                if (remaining_index == num_points - 1) begin
                    if (remaining_count <= 1) begin
                        next_state = DONE;
                        success = 1;
                        done = 1;
                    end else begin
                        next_state = STRATEGY_C;
                        index = 0;
                        remaining_index = 0;
                        remaining_count = 0;
                        flag = 0;
                        line_x0 = point_x[1]; line_y0 = point_y[1];
                        line_x1 = point_x[2]; line_y1 = point_y[2];
                    end
                end
            end
            STRATEGY_C: begin
                if (remaining_index == num_points - 1) begin
                    next_state = DONE;
                    success = (remaining_count <= 1);
                    done = 1;
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Datapath logic
    always @(*) begin
        case (current_state)
            CHECK_COLLINEAR: begin
                if (index < num_points - 1) begin
                    x0 = point_x[0]; y0 = point_y[0];
                    x1 = point_x[1]; y1 = point_y[1];
                    x2 = point_x[index + 1]; y2 = point_y[index + 1];
                    cross_product = ($signed(x1 - x0) * $signed(y2 - y0)) - ($signed(x2 - x0) * $signed(y1 - y0));
                    if (cross_product != 0) begin
                        all_collinear = 0;
                    end
                end
            end
            STRATEGY_A, STRATEGY_B, STRATEGY_C: begin
                if (remaining_index < num_points - 1) begin
                    temp_x = point_x[remaining_index + 1];
                    temp_y = point_y[remaining_index + 1];
                    cross_product = ($signed(line_x1 - line_x0) * $signed(temp_y - line_y0)) - ($signed(temp_x - line_x0) * $signed(line_y1 - line_y0));
                    if (cross_product == 0) begin
                        flag[remaining_index + 1] = 1;
                    end else begin
                        if (remaining_count == 0) begin
                            remaining_x0 = temp_x;
                            remaining_y0 = temp_y;
                        end else if (remaining_count == 1) begin
                            remaining_x1 = temp_x;
                            remaining_y1 = temp_y;
                        end
                        remaining_count = remaining_count + 1;
                    end
                end
            end
        endcase
    end

endmodule