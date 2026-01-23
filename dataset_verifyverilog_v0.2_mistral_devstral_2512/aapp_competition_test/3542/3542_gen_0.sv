module grid_router (
    input clk,
    input rst_n,
    input start,
    input [3:0] grid_n,
    input [3:0] grid_m,
    input [3:0] a1_x, a1_y,
    input [3:0] a2_x, a2_y,
    input [3:0] b1_x, b1_y,
    input [3:0] b2_x, b2_y,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CALC_DIST,
        CHECK_INTERSECTION,
        COMPUTE_RESULT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [7:0] dist_A, dist_B;
    reg [3:0] a_min_x, a_max_x, a_min_y, a_max_y;
    reg [3:0] b_min_x, b_max_x, b_min_y, b_max_y;
    reg boxes_intersect;
    reg [3:0] counter;

    // Check if coordinates are within grid bounds
    wire a1_valid = (a1_x <= grid_n) && (a1_y <= grid_m);
    wire a2_valid = (a2_x <= grid_n) && (a2_y <= grid_m);
    wire b1_valid = (b1_x <= grid_n) && (b1_y <= grid_m);
    wire b2_valid = (b2_x <= grid_n) && (b2_y <= grid_m);
    wire all_valid = a1_valid && a2_valid && b1_valid && b2_valid;

    // Calculate Manhattan distances (combinational)
    wire [7:0] calc_dist_A = (a1_x > a2_x) ? (a1_x - a2_x) : (a2_x - a1_x) +
                             (a1_y > a2_y) ? (a1_y - a2_y) : (a2_y - a1_y);
    wire [7:0] calc_dist_B = (b1_x > b2_x) ? (b1_x - b2_x) : (b2_x - b1_x) +
                             (b1_y > b2_y) ? (b1_y - b2_y) : (b2_y - b1_y);

    // Calculate bounding boxes (combinational)
    wire [3:0] a_min_x_w = (a1_x < a2_x) ? a1_x : a2_x;
    wire [3:0] a_max_x_w = (a1_x > a2_x) ? a1_x : a2_x;
    wire [3:0] a_min_y_w = (a1_y < a2_y) ? a1_y : a2_y;
    wire [3:0] a_max_y_w = (a1_y > a2_y) ? a1_y : a2_y;

    wire [3:0] b_min_x_w = (b1_x < b2_x) ? b1_x : b2_x;
    wire [3:0] b_max_x_w = (b1_x > b2_x) ? b1_x : b2_x;
    wire [3:0] b_min_y_w = (b1_y < b2_y) ? b1_y : b2_y;
    wire [3:0] b_max_y_w = (b1_y > b2_y) ? b1_y : b2_y;

    // Check if bounding boxes intersect (combinational)
    wire boxes_intersect_w = !(a_max_x_w < b_min_x_w || a_min_x_w > b_max_x_w ||
                               a_max_y_w < b_min_y_w || a_min_y_w > b_max_y_w);

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            dist_A <= 0;
            dist_B <= 0;
            a_min_x <= 0;
            a_max_x <= 0;
            a_min_y <= 0;
            a_max_y <= 0;
            b_min_x <= 0;
            b_max_x <= 0;
            b_min_y <= 0;
            b_max_y <= 0;
            boxes_intersect <= 0;
            counter <= 0;
            result <= 255;
            done <= 0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        dist_A <= calc_dist_A;
                        dist_B <= calc_dist_B;
                        a_min_x <= a_min_x_w;
                        a_max_x <= a_max_x_w;
                        a_min_y <= a_min_y_w;
                        a_max_y <= a_max_y_w;
                        b_min_x <= b_min_x_w;
                        b_max_x <= b_max_x_w;
                        b_min_y <= b_min_y_w;
                        b_max_y <= b_max_y_w;
                        boxes_intersect <= boxes_intersect_w;
                        counter <= 0;
                    end
                end

                CALC_DIST: begin
                    counter <= counter + 1;
                end

                CHECK_INTERSECTION: begin
                    counter <= counter + 1;
                end

                COMPUTE_RESULT: begin
                    counter <= counter + 1;
                end

                DONE: begin
                    if (!start) begin
                        done <= 0;
                    end
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_DIST;
                end
            end

            CALC_DIST: begin
                if (counter == 1) begin
                    next_state = CHECK_INTERSECTION;
                end
            end

            CHECK_INTERSECTION: begin
                if (counter == 2) begin
                    next_state = COMPUTE_RESULT;
                end
            end

            COMPUTE_RESULT: begin
                if (counter == 3) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Result computation
    always @(*) begin
        if (current_state == COMPUTE_RESULT && counter == 3) begin
            if (!all_valid) begin
                result = 255;
            end else if (!boxes_intersect) begin
                result = dist_A + dist_B;
            end else begin
                result = 255;
            end
        end
    end

    // Done signal
    always @(*) begin
        if (current_state == DONE) begin
            done = 1;
        end else begin
            done = 0;
        end
    end

endmodule