module WaterHeightCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] x [0:7],
    input wire signed [15:0] y [0:7],
    input wire [15:0] D,
    input wire [15:0] L,
    output reg [31:0] water_height,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_INTERSECTION = 3'd1;
    localparam [2:0] INTEGRATE_AREA = 3'd2;
    localparam [2:0] CHECK_VOLUME = 3'd3;
    localparam [2:0] UPDATE_SEARCH = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;

    // Binary search variables
    reg signed [31:0] low, high, mid;
    reg signed [31:0] current_area;
    reg signed [31:0] target_area;
    reg [7:0] iteration_count;
    localparam [7:0] MAX_ITERATIONS = 8'd100;

    // Integration variables
    reg signed [31:0] y_slice;
    reg signed [31:0] y_step;
    reg [7:0] slice_count;
    localparam [7:0] NUM_SLICES = 8'd100;
    reg signed [31:0] total_area;

    // Intersection variables
    reg signed [31:0] x_left, x_right;
    reg [2:0] edge_index;
    reg [2:0] num_intersections;

    // Find max y for binary search range
    reg signed [31:0] max_y;

    // Fixed-point constants
    localparam signed [31:0] FIXED_1 = 32'd65536; // 1.0 in Q16.16
    localparam signed [31:0] FIXED_0_5 = 32'd32768; // 0.5 in Q16.16
    localparam signed [31:0] FIXED_0_01 = 32'd655; // 0.01 in Q16.16

    // Find maximum y value
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_y <= 32'd0;
        end else if (state == IDLE && start) begin
            max_y <= 32'd0;
            for (integer i = 0; i < 8; i = i + 1) begin
                if (y[i] > max_y[15:0]) begin
                    max_y <= {{16'd0}, y[i]};
                end
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            water_height <= 32'd0;
            valid <= 1'b0;
            low <= 32'd0;
            high <= 32'd0;
            mid <= 32'd0;
            current_area <= 32'd0;
            target_area <= 32'd0;
            iteration_count <= 8'd0;
            y_slice <= 32'd0;
            y_step <= 32'd0;
            slice_count <= 8'd0;
            total_area <= 32'd0;
            x_left <= 32'd0;
            x_right <= 32'd0;
            edge_index <= 3'd0;
            num_intersections <= 3'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE_INTERSECTION;
                    // Initialize binary search
                    low = 32'd0;
                    high = max_y;
                    // Calculate target area: L * 1000 / D (in cm²)
                    // L is in liters, D in cm, so area = (L * 1000) / D
                    target_area = ({{16'd0}, L} * 32'd1000) / {{16'd0}, D};
                    iteration_count = 8'd0;
                end
            end

            COMPUTE_INTERSECTION: begin
                next_state = INTEGRATE_AREA;
            end

            INTEGRATE_AREA: begin
                if (slice_count < NUM_SLICES - 1) begin
                    next_state = INTEGRATE_AREA;
                end else begin
                    next_state = CHECK_VOLUME;
                end
            end

            CHECK_VOLUME: begin
                next_state = UPDATE_SEARCH;
            end

            UPDATE_SEARCH: begin
                if (iteration_count < MAX_ITERATIONS - 1) begin
                    next_state = COMPUTE_INTERSECTION;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Binary search update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mid <= 32'd0;
        end else if (state == UPDATE_SEARCH) begin
            if (current_area < target_area) begin
                low = mid;
            end else begin
                high = mid;
            end
            mid = (low + high) / 2;
            iteration_count = iteration_count + 8'd1;
        end
    end

    // Integration computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_slice <= 32'd0;
            y_step <= 32'd0;
            slice_count <= 8'd0;
            total_area <= 32'd0;
        end else if (state == COMPUTE_INTERSECTION) begin
            // Initialize integration
            y_slice = 32'd0;
            y_step = high / {{16'd0}, NUM_SLICES};
            slice_count = 8'd0;
            total_area = 32'd0;
        end else if (state == INTEGRATE_AREA) begin
            // Find intersections at current y_slice
            x_left = 32'd32768; // Initialize to max value
            x_right = 32'd-32768; // Initialize to min value
            num_intersections = 3'd0;

            // Check all edges
            for (integer i = 0; i < 7; i = i + 1) begin
                reg signed [31:0] x1, y1, x2, y2;
                reg signed [31:0] denom, t;
                reg signed [31:0] x_intersect;

                x1 = {{16'd0}, x[i]};
                y1 = {{16'd0}, y[i]};
                x2 = {{16'd0}, x[i+1]};
                y2 = {{16'd0}, y[i+1]};

                // Check if edge crosses current y_slice
                if ((y1 <= y_slice && y2 > y_slice) || (y2 <= y_slice && y1 > y_slice)) begin
                    denom = y2 - y1;
                    if (denom != 32'd0) begin
                        t = (y_slice - y1) / denom;
                        x_intersect = x1 + (t * (x2 - x1));

                        // Update left and right intersections
                        if (x_intersect < x_left) begin
                            x_left = x_intersect;
                        end
                        if (x_intersect > x_right) begin
                            x_right = x_intersect;
                        end
                        num_intersections = num_intersections + 3'd1;
                    end
                end
            end

            // If we have exactly 2 intersections, compute width
            if (num_intersections == 3'd2) begin
                reg signed [31:0] width;
                width = x_right - x_left;
                if (width > 32'd0) begin
                    // Trapezoidal rule: average of current and next width
                    reg signed [31:0] next_width;
                    reg signed [31:0] next_y;
                    next_y = y_slice + y_step;

                    // Find intersections at next y
                    x_left = 32'd32768;
                    x_right = 32'd-32768;
                    num_intersections = 3'd0;

                    for (integer i = 0; i < 7; i = i + 1) begin
                        reg signed [31:0] x1, y1, x2, y2;
                        reg signed [31:0] denom, t;
                        reg signed [31:0] x_intersect;

                        x1 = {{16'd0}, x[i]};
                        y1 = {{16'd0}, y[i]};
                        x2 = {{16'd0}, x[i+1]};
                        y2 = {{16'd0}, y[i+1]};

                        if ((y1 <= next_y && y2 > next_y) || (y2 <= next_y && y1 > next_y)) begin
                            denom = y2 - y1;
                            if (denom != 32'd0) begin
                                t = (next_y - y1) / denom;
                                x_intersect = x1 + (t * (x2 - x1));

                                if (x_intersect < x_left) begin
                                    x_left = x_intersect;
                                end
                                if (x_intersect > x_right) begin
                                    x_right = x_intersect;
                                end
                                num_intersections = num_intersections + 3'd1;
                            end
                        end
                    end

                    if (num_intersections == 3'd2) begin
                        next_width = x_right - x_left;
                        if (next_width > 32'd0) begin
                            total_area = total_area + (width + next_width) * y_step * FIXED_0_5;
                        end
                    end
                end
            end

            // Move to next slice
            y_slice = y_slice + y_step;
            slice_count = slice_count + 8'd1;
        end else if (state == CHECK_VOLUME) begin
            current_area = total_area;
        end else if (state == DONE_STATE) begin
            water_height = mid;
            valid = 1'b1;
        end else begin
            valid = 1'b0;
        end
    end

endmodule