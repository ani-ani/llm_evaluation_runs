module rocket_safety_checker (
    input clk,
    input rst_n,
    input start,
    input [15:0] engine1_x [0:7],
    input [15:0] engine1_y [0:7],
    input [2:0] engine1_count,
    input [15:0] engine2_x [0:7],
    input [15:0] engine2_y [0:7],
    input [2:0] engine2_count,
    output reg safe,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        FIND_MIN_Y,
        SORT_POINTS,
        BUILD_HULL,
        COMPARE_HULLS,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [15:0] min_y1, min_y2;
    reg [15:0] min_x1, min_x2;
    reg [2:0] min_idx1, min_idx2;
    reg [15:0] sorted_x1 [0:7], sorted_y1 [0:7];
    reg [15:0] sorted_x2 [0:7], sorted_y2 [0:7];
    reg [2:0] hull1_size, hull2_size;
    reg [15:0] hull1_x [0:7], hull1_y [0:7];
    reg [15:0] hull2_x [0:7], hull2_y [0:7];
    reg [2:0] sort_idx1, sort_idx2;
    reg [2:0] build_idx1, build_idx2;
    reg [2:0] compare_idx1, compare_idx2;
    reg [2:0] counter;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            safe <= 0;
            done <= 0;
            min_idx1 <= 0;
            min_idx2 <= 0;
            sort_idx1 <= 0;
            sort_idx2 <= 0;
            build_idx1 <= 0;
            build_idx2 <= 0;
            compare_idx1 <= 0;
            compare_idx2 <= 0;
            counter <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = FIND_MIN_Y;
            end
            FIND_MIN_Y: begin
                if (counter == 199) next_state = SORT_POINTS;
            end
            SORT_POINTS: begin
                if (counter == 199) next_state = BUILD_HULL;
            end
            BUILD_HULL: begin
                if (counter == 199) next_state = COMPARE_HULLS;
            end
            COMPARE_HULLS: begin
                if (counter == 199) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Counter for state timing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
        end else if (start && current_state != IDLE) begin
            if (counter == 199) begin
                counter <= 0;
            end else begin
                counter <= counter + 1;
            end
        end
    end

    // Find minimum y point
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_y1 <= 0;
            min_x1 <= 0;
            min_idx1 <= 0;
            min_y2 <= 0;
            min_x2 <= 0;
            min_idx2 <= 0;
        end else if (current_state == FIND_MIN_Y && counter == 0) begin
            // Engine 1
            min_y1 = engine1_y[0];
            min_x1 = engine1_x[0];
            min_idx1 = 0;
            for (int i = 1; i < engine1_count; i++) begin
                if (engine1_y[i] < min_y1 || (engine1_y[i] == min_y1 && engine1_x[i] < min_x1)) begin
                    min_y1 = engine1_y[i];
                    min_x1 = engine1_x[i];
                    min_idx1 = i;
                end
            end

            // Engine 2
            min_y2 = engine2_y[0];
            min_x2 = engine2_x[0];
            min_idx2 = 0;
            for (int i = 1; i < engine2_count; i++) begin
                if (engine2_y[i] < min_y2 || (engine2_y[i] == min_y2 && engine2_x[i] < min_x2)) begin
                    min_y2 = engine2_y[i];
                    min_x2 = engine2_x[i];
                    min_idx2 = i;
                end
            end
        end
    end

    // Sort points by polar angle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sort_idx1 <= 0;
            sort_idx2 <= 0;
        end else if (current_state == SORT_POINTS && counter == 0) begin
            // Engine 1
            for (int i = 0; i < engine1_count; i++) begin
                if (i != min_idx1) begin
                    sorted_x1[sort_idx1] = engine1_x[i];
                    sorted_y1[sort_idx1] = engine1_y[i];
                    sort_idx1 = sort_idx1 + 1;
                end
            end

            // Engine 2
            for (int i = 0; i < engine2_count; i++) begin
                if (i != min_idx2) begin
                    sorted_x2[sort_idx2] = engine2_x[i];
                    sorted_y2[sort_idx2] = engine2_y[i];
                    sort_idx2 = sort_idx2 + 1;
                end
            end
        end
    end

    // Build convex hull using Graham scan
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            build_idx1 <= 0;
            build_idx2 <= 0;
            hull1_size <= 0;
            hull2_size <= 0;
        end else if (current_state == BUILD_HULL && counter == 0) begin
            // Engine 1
            hull1_x[0] = min_x1;
            hull1_y[0] = min_y1;
            hull1_x[1] = sorted_x1[0];
            hull1_y[1] = sorted_y1[0];
            hull1_size = 2;

            for (int i = 1; i < sort_idx1; i++) begin
                while (hull1_size >= 2 && cross_product(hull1_x[hull1_size-2], hull1_y[hull1_size-2], hull1_x[hull1_size-1], hull1_y[hull1_size-1], sorted_x1[i], sorted_y1[i]) <= 0) begin
                    hull1_size = hull1_size - 1;
                end
                hull1_x[hull1_size] = sorted_x1[i];
                hull1_y[hull1_size] = sorted_y1[i];
                hull1_size = hull1_size + 1;
            end

            // Engine 2
            hull2_x[0] = min_x2;
            hull2_y[0] = min_y2;
            hull2_x[1] = sorted_x2[0];
            hull2_y[1] = sorted_y2[0];
            hull2_size = 2;

            for (int i = 1; i < sort_idx2; i++) begin
                while (hull2_size >= 2 && cross_product(hull2_x[hull2_size-2], hull2_y[hull2_size-2], hull2_x[hull2_size-1], hull2_y[hull2_size-1], sorted_x2[i], sorted_y2[i]) <= 0) begin
                    hull2_size = hull2_size - 1;
                end
                hull2_x[hull2_size] = sorted_x2[i];
                hull2_y[hull2_size] = sorted_y2[i];
                hull2_size = hull2_size + 1;
            end
        end
    end

    // Compare hulls
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            compare_idx1 <= 0;
            compare_idx2 <= 0;
            safe <= 0;
        end else if (current_state == COMPARE_HULLS && counter == 0) begin
            if (hull1_size != hull2_size) begin
                safe = 0;
            end else begin
                safe = 1;
                for (int i = 0; i < hull1_size; i++) begin
                    if (hull1_x[i] != hull2_x[i] || hull1_y[i] != hull2_y[i]) begin
                        safe = 0;
                    end
                end
            end
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
        end else if (current_state == DONE) begin
            done <= 1;
        end else if (current_state == IDLE) begin
            done <= 0;
        end
    end

    // Cross product function
    function signed [31:0] cross_product(
        input [15:0] ax, input [15:0] ay,
        input [15:0] bx, input [15:0] by,
        input [15:0] cx, input [15:0] cy
    );
        signed [31:0] abx, aby, acx, acy;
        abx = bx - ax;
        aby = by - ay;
        acx = cx - ax;
        acy = cy - ay;
        cross_product = abx * acy - aby * acx;
    endfunction

endmodule