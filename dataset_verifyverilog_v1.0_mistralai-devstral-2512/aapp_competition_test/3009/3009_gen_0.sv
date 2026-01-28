module lighting_balancer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] lamps_x [0:15],
    input wire [9:0] lamps_y [0:15],
    input wire signed [15:0] lamps_e [0:15],
    input wire [3:0] num_lamps,
    output reg [31:0] result,
    output reg valid,
    output reg impossible,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] PREPARE = 4'd1;
    localparam [3:0] SUBSET_LOOP = 4'd2;
    localparam [3:0] CONVEX_HULL = 4'd3;
    localparam [3:0] PERIMETER = 4'd4;
    localparam [3:0] UPDATE_MIN = 4'd5;
    localparam [3:0] COMPLETE = 4'd6;

    reg [3:0] state, next_state;

    // Internal registers
    reg [15:0] subset_counter;
    reg [15:0] current_subset;
    reg [15:0] total_energy;
    reg [15:0] target_energy;
    reg [15:0] subset_energy;
    reg [15:0] min_perimeter;
    reg [15:0] current_perimeter;
    reg [15:0] point_count;
    reg [15:0] hull_size;
    reg [15:0] i, j, k;

    // Point arrays (Q10.6 format)
    reg signed [15:0] points_x [0:15];
    reg signed [15:0] points_y [0:15];
    reg signed [15:0] hull_x [0:15];
    reg signed [15:0] hull_y [0:15];

    // Temporary registers for calculations
    reg signed [31:0] dx, dy;
    reg signed [31:0] distance;
    reg signed [31:0] temp_sum;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset_counter <= 16'd0;
            current_subset <= 16'd0;
            total_energy <= 16'd0;
            target_energy <= 16'd0;
            subset_energy <= 16'd0;
            min_perimeter <= 16'd0;
            current_perimeter <= 16'd0;
            point_count <= 16'd0;
            hull_size <= 16'd0;
            i <= 16'd0;
            j <= 16'd0;
            k <= 16'd0;
            result <= 32'd0;
            valid <= 1'b0;
            impossible <= 1'b0;
            done <= 1'b0;

            // Initialize point arrays
            for (i = 0; i < 16; i = i + 1) begin
                points_x[i] <= 16'd0;
                points_y[i] <= 16'd0;
                hull_x[i] <= 16'd0;
                hull_y[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PREPARE;
                end
            end

            PREPARE: begin
                // Compute total energy
                temp_sum = 16'd0;
                for (i = 0; i < num_lamps; i = i + 1) begin
                    temp_sum = temp_sum + lamps_e[i];
                end
                total_energy = temp_sum[15:0];

                // Check if balanced partition is possible
                if (total_energy[0] == 1'b0 && total_energy != 16'd0) begin
                    target_energy = total_energy / 16'd2;
                    next_state = SUBSET_LOOP;
                end else begin
                    impossible = 1'b1;
                    next_state = COMPLETE;
                end
            end

            SUBSET_LOOP: begin
                // Iterate through all subsets
                if (subset_counter < (1 << num_lamps)) begin
                    current_subset = subset_counter;
                    subset_energy = 16'd0;

                    // Compute subset energy
                    for (i = 0; i < num_lamps; i = i + 1) begin
                        if (current_subset[i]) begin
                            subset_energy = subset_energy + lamps_e[i];
                        end
                    end

                    // Check if this subset matches target energy
                    if (subset_energy == target_energy) begin
                        // Collect points in this subset
                        point_count = 16'd0;
                        for (i = 0; i < num_lamps; i = i + 1) begin
                            if (current_subset[i]) begin
                                points_x[point_count] = lamps_x[i] << 6; // Q10.6
                                points_y[point_count] = lamps_y[i] << 6; // Q10.6
                                point_count = point_count + 1;
                            end
                        end

                        // Proceed to convex hull if we have at least 3 points
                        if (point_count >= 3) begin
                            next_state = CONVEX_HULL;
                        end
                    end

                    subset_counter = subset_counter + 1;
                end else begin
                    next_state = COMPLETE;
                end
            end

            CONVEX_HULL: begin
                // Sort points by x then y (bubble sort for simplicity)
                for (i = 0; i < point_count - 1; i = i + 1) begin
                    for (j = 0; j < point_count - i - 1; j = j + 1) begin
                        if (points_x[j] > points_x[j + 1] ||
                            (points_x[j] == points_x[j + 1] && points_y[j] > points_y[j + 1])) begin
                            // Swap
                            temp_sum = points_x[j];
                            points_x[j] = points_x[j + 1];
                            points_x[j + 1] = temp_sum[15:0];

                            temp_sum = points_y[j];
                            points_y[j] = points_y[j + 1];
                            points_y[j + 1] = temp_sum[15:0];
                        end
                    end
                end

                // Build lower hull
                hull_size = 16'd0;
                for (i = 0; i < point_count; i = i + 1) begin
                    while (hull_size >= 2 &&
                          cross_product(hull_x[hull_size - 2], hull_y[hull_size - 2],
                                       hull_x[hull_size - 1], hull_y[hull_size - 1],
                                       points_x[i], points_y[i]) <= 0) begin
                        hull_size = hull_size - 1;
                    end
                    hull_x[hull_size] = points_x[i];
                    hull_y[hull_size] = points_y[i];
                    hull_size = hull_size + 1;
                end

                // Build upper hull
                k = hull_size + 1;
                for (i = point_count - 1; i >= 0; i = i - 1) begin
                    while (k - hull_size >= 2 &&
                          cross_product(hull_x[k - 2], hull_y[k - 2],
                                       hull_x[k - 1], hull_y[k - 1],
                                       points_x[i], points_y[i]) <= 0) begin
                        k = k - 1;
                    end
                    hull_x[k] = points_x[i];
                    hull_y[k] = points_y[i];
                    k = k + 1;
                end

                hull_size = k - 1;
                next_state = PERIMETER;
            end

            PERIMETER: begin
                // Compute perimeter of convex hull
                current_perimeter = 16'd0;
                for (i = 0; i < hull_size; i = i + 1) begin
                    j = (i + 1) % hull_size;
                    dx = hull_x[j] - hull_x[i];
                    dy = hull_y[j] - hull_y[i];
                    distance = sqrt_q16_16(dx * dx + dy * dy);
                    current_perimeter = current_perimeter + distance[15:0];
                end
                next_state = UPDATE_MIN;
            end

            UPDATE_MIN: begin
                // Update minimum perimeter
                if (min_perimeter == 16'd0 || current_perimeter < min_perimeter) begin
                    min_perimeter = current_perimeter;
                end
                next_state = SUBSET_LOOP;
            end

            COMPLETE: begin
                if (impossible) begin
                    result = 32'd0;
                    valid = 1'b0;
                    impossible = 1'b1;
                end else begin
                    result = min_perimeter << 16; // Q16.16 format
                    valid = 1'b1;
                    impossible = 1'b0;
                end
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Cross product function
    function signed [31:0] cross_product(
        input signed [15:0] ax,
        input signed [15:0] ay,
        input signed [15:0] bx,
        input signed [15:0] by,
        input signed [15:0] cx,
        input signed [15:0] cy
    );
        cross_product = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
    endfunction

    // Square root approximation (Q16.16 format)
    function signed [31:0] sqrt_q16_16(
        input signed [31:0] x
    );
        reg signed [31:0] op, res, one;
        integer i;

        op = x;
        res = 32'd0;
        one = 32'd1 << 30;

        for (i = 0; i < 16; i = i + 1) begin
            if (op >= res + one) begin
                op = op - res - one;
                res = (res >> 1) + one;
            end else begin
                res = res >> 1;
            end
            one = one >> 2;
        end

        sqrt_q16_16 = res;
    endfunction

endmodule