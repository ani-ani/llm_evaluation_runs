module energy_balancer (
    input clk,
    input rst_n,
    input start,
    input [7:0] coord_x [0:7],
    input [7:0] coord_y [0:7],
    input [31:0] energy [0:7],
    input [2:0] num_lamps,
    output reg [31:0] min_perimeter,
    output reg valid,
    output reg impossible
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        PRECOMPUTE,
        SUBSET_ITERATION,
        CONVEX_HULL,
        COMPARE,
        DONE
    } state_t;

    // State registers
    state_t current_state, next_state;
    reg [9:0] subset_counter;
    reg [31:0] total_energy;
    reg [31:0] target_energy;
    reg [31:0] current_perimeter;
    reg [31:0] temp_min_perimeter;
    reg [31:0] subset_sum;
    reg [7:0] subset_mask [0:7];
    reg [31:0] hull_perimeter;
    reg [31:0] hull_points_x [0:7];
    reg [31:0] hull_points_y [0:7];
    reg [2:0] hull_size;
    reg [2:0] hull_counter;
    reg [2:0] lamp_counter;
    reg [2:0] subset_lamp_counter;
    reg [31:0] x_sorted [0:7];
    reg [31:0] y_sorted [0:7];
    reg [31:0] x_temp [0:7];
    reg [31:0] y_temp [0:7];
    reg [31:0] x_hull [0:7];
    reg [31:0] y_hull [0:7];
    reg [2:0] hull_lower_size;
    reg [2:0] hull_upper_size;
    reg [31:0] x_lower [0:7];
    reg [31:0] y_lower [0:7];
    reg [31:0] x_upper [0:7];
    reg [31:0] y_upper [0:7];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            subset_counter <= 0;
            total_energy <= 0;
            target_energy <= 0;
            current_perimeter <= 0;
            temp_min_perimeter <= 0;
            subset_sum <= 0;
            hull_perimeter <= 0;
            hull_size <= 0;
            hull_counter <= 0;
            lamp_counter <= 0;
            subset_lamp_counter <= 0;
            hull_lower_size <= 0;
            hull_upper_size <= 0;
            min_perimeter <= 0;
            valid <= 0;
            impossible <= 0;
            for (int i = 0; i < 8; i++) begin
                subset_mask[i] <= 0;
                hull_points_x[i] <= 0;
                hull_points_y[i] <= 0;
                x_sorted[i] <= 0;
                y_sorted[i] <= 0;
                x_temp[i] <= 0;
                y_temp[i] <= 0;
                x_hull[i] <= 0;
                y_hull[i] <= 0;
                x_lower[i] <= 0;
                y_lower[i] <= 0;
                x_upper[i] <= 0;
                y_upper[i] <= 0;
            end
        end else begin
            current_state <= next_state;
            if (current_state == PRECOMPUTE) begin
                total_energy <= compute_total_energy();
                if (total_energy[0] == 1'b0) begin
                    target_energy <= total_energy >> 1;
                    impossible <= 0;
                end else begin
                    impossible <= 1;
                end
            end else if (current_state == SUBSET_ITERATION) begin
                subset_counter <= subset_counter + 1;
                subset_sum <= compute_subset_sum(subset_counter);
            end else if (current_state == CONVEX_HULL) begin
                if (hull_counter == 0) begin
                    // Sort points
                    sort_points();
                    // Build convex hull
                    build_convex_hull();
                end
            end else if (current_state == COMPARE) begin
                if (current_perimeter < temp_min_perimeter || temp_min_perimeter == 0) begin
                    temp_min_perimeter <= current_perimeter;
                end
            end else if (current_state == DONE) begin
                min_perimeter <= temp_min_perimeter;
                valid <= 1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = PRECOMPUTE;
                end
            end
            PRECOMPUTE: begin
                if (impossible) begin
                    next_state = DONE;
                end else begin
                    next_state = SUBSET_ITERATION;
                end
            end
            SUBSET_ITERATION: begin
                if (subset_counter == (1 << num_lamps) - 1) begin
                    next_state = DONE;
                end else if (subset_sum == target_energy) begin
                    next_state = CONVEX_HULL;
                end
            end
            CONVEX_HULL: begin
                if (hull_counter == 0) begin
                    next_state = COMPARE;
                end
            end
            COMPARE: begin
                next_state = SUBSET_ITERATION;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Compute total energy
    function [31:0] compute_total_energy;
        integer i;
        reg [31:0] sum;
        begin
            sum = 0;
            for (i = 0; i < num_lamps; i = i + 1) begin
                sum = sum + energy[i];
            end
            compute_total_energy = sum;
        end
    endfunction

    // Compute subset sum
    function [31:0] compute_subset_sum;
        input [9:0] subset;
        integer i;
        reg [31:0] sum;
        begin
            sum = 0;
            for (i = 0; i < num_lamps; i = i + 1) begin
                if (subset[i]) begin
                    sum = sum + energy[i];
                end
            end
            compute_subset_sum = sum;
        end
    endfunction

    // Sort points by x then y
    task sort_points;
        integer i, j;
        reg [31:0] temp_x, temp_y;
        begin
            for (i = 0; i < num_lamps; i = i + 1) begin
                x_sorted[i] = coord_x[i] << 16;
                y_sorted[i] = coord_y[i] << 16;
            end
            for (i = 0; i < num_lamps - 1; i = i + 1) begin
                for (j = i + 1; j < num_lamps; j = j + 1) begin
                    if (x_sorted[j] < x_sorted[i] || (x_sorted[j] == x_sorted[i] && y_sorted[j] < y_sorted[i])) begin
                        temp_x = x_sorted[i];
                        temp_y = y_sorted[i];
                        x_sorted[i] = x_sorted[j];
                        y_sorted[i] = y_sorted[j];
                        x_sorted[j] = temp_x;
                        y_sorted[j] = temp_y;
                    end
                end
            end
        end
    endtask

    // Build convex hull
    task build_convex_hull;
        integer i;
        reg [31:0] x0, y0, x1, y1, x2, y2;
        reg [31:0] dx1, dy1, dx2, dy2;
        reg [31:0] cross;
        begin
            // Lower hull
            hull_lower_size = 0;
            for (i = 0; i < num_lamps; i = i + 1) begin
                while (hull_lower_size >= 2) begin
                    x0 = x_lower[hull_lower_size - 2];
                    y0 = y_lower[hull_lower_size - 2];
                    x1 = x_lower[hull_lower_size - 1];
                    y1 = y_lower[hull_lower_size - 1];
                    x2 = x_sorted[i];
                    y2 = y_sorted[i];
                    dx1 = x1 - x0;
                    dy1 = y1 - y0;
                    dx2 = x2 - x1;
                    dy2 = y2 - y1;
                    cross = dx1 * dy2 - dx2 * dy1;
                    if (cross <= 0) begin
                        hull_lower_size = hull_lower_size - 1;
                    end else begin
                        break;
                    end
                end
                x_lower[hull_lower_size] = x_sorted[i];
                y_lower[hull_lower_size] = y_sorted[i];
                hull_lower_size = hull_lower_size + 1;
            end

            // Upper hull
            hull_upper_size = 0;
            for (i = num_lamps - 1; i >= 0; i = i - 1) begin
                while (hull_upper_size >= 2) begin
                    x0 = x_upper[hull_upper_size - 2];
                    y0 = y_upper[hull_upper_size - 2];
                    x1 = x_upper[hull_upper_size - 1];
                    y1 = y_upper[hull_upper_size - 1];
                    x2 = x_sorted[i];
                    y2 = y_sorted[i];
                    dx1 = x1 - x0;
                    dy1 = y1 - y0;
                    dx2 = x2 - x1;
                    dy2 = y2 - y1;
                    cross = dx1 * dy2 - dx2 * dy1;
                    if (cross <= 0) begin
                        hull_upper_size = hull_upper_size - 1;
                    end else begin
                        break;
                    end
                end
                x_upper[hull_upper_size] = x_sorted[i];
                y_upper[hull_upper_size] = y_sorted[i];
                hull_upper_size = hull_upper_size + 1;
            end

            // Combine hulls
            hull_size = hull_lower_size + hull_upper_size - 2;
            for (i = 0; i < hull_lower_size; i = i + 1) begin
                x_hull[i] = x_lower[i];
                y_hull[i] = y_lower[i];
            end
            for (i = 1; i < hull_upper_size - 1; i = i + 1) begin
                x_hull[hull_lower_size - 1 + i] = x_upper[i];
                y_hull[hull_lower_size - 1 + i] = y_upper[i];
            end

            // Compute perimeter
            current_perimeter = 0;
            for (i = 0; i < hull_size; i = i + 1) begin
                x1 = x_hull[i];
                y1 = y_hull[i];
                x2 = x_hull[(i + 1) % hull_size];
                y2 = y_hull[(i + 1) % hull_size];
                current_perimeter = current_perimeter + compute_distance(x1, y1, x2, y2);
            end
        end
    endtask

    // Compute distance between two points
    function [31:0] compute_distance;
        input [31:0] x1, y1, x2, y2;
        reg [31:0] dx, dy, dx2, dy2, sum, sqrt_val;
        begin
            dx = x2 - x1;
            dy = y2 - y1;
            dx2 = dx * dx;
            dy2 = dy * dy;
            sum = dx2 + dy2;
            sqrt_val = sqrt_fixed(sum);
            compute_distance = sqrt_val;
        end
    endfunction

    // Fixed-point square root
    function [31:0] sqrt_fixed;
        input [31:0] val;
        reg [31:0] x, y, temp;
        integer i;
        begin
            if (val == 0) begin
                sqrt_fixed = 0;
            end else begin
                x = val;
                y = 1 << 16;
                for (i = 0; i < 16; i = i + 1) begin
                    temp = y + (x >> y);
                    y = temp >> 1;
                end
                sqrt_fixed = y;
            end
        end
    endfunction

endmodule