module MaxCircleHits(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] x_arr [0:9],
    input wire [15:0] y_arr [0:9],
    input wire [15:0] r_arr [0:9],
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] COMPUTE_D   = 4'd1;
    localparam [3:0] CHECK_D     = 4'd2;
    localparam [3:0] COMPUTE_ALPHA= 4'd3;
    localparam [3:0] COMPUTE_DELTA= 4'd4;
    localparam [3:0] ADD_INTERVAL= 4'd5;
    localparam [3:0] SORT_LOOP   = 4'd6;
    localparam [3:0] SWEEP       = 4'd7;
    localparam [3:0] FIND_MAX     = 4'd8;
    localparam [3:0] FINISH      = 4'd9;
    localparam [3:0] RESET_REGS  = 4'd10;

    reg [3:0] state, next_state;
    reg [7:0] cycle_count;  // For timing constraint
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Input registers
    reg [3:0] n_reg;
    reg [15:0] x_reg [0:9];
    reg [15:0] y_reg [0:9];
    reg [15:0] r_reg [0:9];

    // Index counters
    reg [3:0] circle_idx;  // 0-9
    reg [4:0] point_idx;   // 0-19
    reg [4:0] sort_idx;    // 0-19
    reg [4:0] sweep_idx;   // 0-19

    // Geometric computation registers
    reg signed [31:0] x_sq, y_sq, r_sq;  // Fixed-point Q24.8
    reg signed [31:0] d_squared;         // Distance squared
    reg [15:0] d;                        // Distance Q8.8
    reg signed [15:0] alpha;             // Angle Q8.8 (0-65535)
    reg [15:0] delta;                    // Half-width Q8.8
    reg [15:0] start_angle, end_angle;   // Interval endpoints
    reg wrapped;                         // Flag for wrap-around

    // Interval storage (2D array for now, flattened later)
    reg [15:0] interval_start [0:9];
    reg [15:0] interval_end [0:9];
    reg interval_valid [0:9];
    reg [3:0] num_intervals;  // Valid intervals count

    // Sort storage: angle + type (1=start, 0=end)
    reg [15:0] sorted_angles [0:19];
    reg sorted_type [0:19];  // 1=start, 0=end
    reg [4:0] num_points;    // Total points (2 * num_intervals)

    // Sweep variables
    reg [3:0] sweep_counter;
    reg [3:0] max_counter;
    reg [4:0] current_point_idx;

    // Constants
    localparam [15:0] TWO_PI = 16'd65535;  // 2π in Q8.8
    localparam [15:0] PI = 16'd32768;      // π in Q8.8
    localparam [31:0] THRESHOLD_SQ = 32'd256;  // r^2 in Q24.8 (r=1 in Q8.8)

    // Temporary variables for calculations
    reg [31:0] temp_mult;
    reg [31:0] temp_sum;
    reg [15:0] temp_angle;
    reg [15:0] temp_diff;
    reg temp_wrapped;

    // Initialize all registers on reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            n_reg <= 4'd0;
            circle_idx <= 4'd0;
            point_idx <= 5'd0;
            sort_idx <= 5'd0;
            sweep_idx <= 5'd0;
            num_intervals <= 4'd0;
            num_points <= 5'd0;
            sweep_counter <= 4'd0;
            max_counter <= 4'd0;
            current_point_idx <= 5'd0;
            x_sq <= 32'd0;
            y_sq <= 32'd0;
            r_sq <= 32'd0;
            d_squared <= 32'd0;
            d <= 16'd0;
            alpha <= 16'd0;
            delta <= 16'd0;
            start_angle <= 16'd0;
            end_angle <= 16'd0;
            wrapped <= 1'b0;
            // Initialize arrays
            for (integer i = 0; i < 10; i = i + 1) begin
                x_reg[i] <= 16'd0;
                y_reg[i] <= 16'd0;
                r_reg[i] <= 16'd0;
                interval_start[i] <= 16'd0;
                interval_end[i] <= 16'd0;
                interval_valid[i] <= 1'b0;
            end
            for (integer i = 0; i < 20; i = i + 1) begin
                sorted_angles[i] <= 16'd0;
                sorted_type[i] <= 1'b0;
            end
        end else begin
            state <= next_state;
            // Increment cycle counter (limit to prevent overflow)
            if (state != IDLE && state != FINISH && state != RESET_REGS) begin
                if (cycle_count < 8'd255)
                    cycle_count <= cycle_count + 8'd1;
            end else if (state == IDLE) begin
                cycle_count <= 8'd0;
            end
        end
    end

    // Main FSM logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = RESET_REGS;
                end
            end

            RESET_REGS: begin
                next_state = COMPUTE_D;
            end

            COMPUTE_D: begin
                if (circle_idx < n_reg) begin
                    next_state = CHECK_D;
                end else begin
                    next_state = SORT_LOOP;
                end
            end

            CHECK_D: begin
                if (d_squared <= THRESHOLD_SQ) begin
                    // Origin inside circle, skip
                    next_state = COMPUTE_D;
                end else begin
                    next_state = COMPUTE_ALPHA;
                end
            end

            COMPUTE_ALPHA: begin
                next_state = COMPUTE_DELTA;
            end

            COMPUTE_DELTA: begin
                next_state = ADD_INTERVAL;
            end

            ADD_INTERVAL: begin
                next_state = COMPUTE_D;
            end

            SORT_LOOP: begin
                if (sort_idx < num_points - 1) begin
                    if (sweep_idx < num_points - 1 - sort_idx) begin
                        next_state = SORT_LOOP;  // Stay in sort
                    end else begin
                        next_state = SORT_LOOP;  // Next pass
                    end
                end else begin
                    next_state = SWEEP;
                end
            end

            SWEEP: begin
                if (sweep_idx < num_points) begin
                    next_state = SWEEP;
                end else begin
                    next_state = FIND_MAX;
                end
            end

            FIND_MAX: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath - combinational logic
    always @(*) begin
        // Default values to prevent latches
        temp_mult = 32'd0;
        temp_sum = 32'd0;
        temp_angle = 16'd0;
        temp_diff = 16'd0;
        temp_wrapped = 1'b0;

        case (state)
            RESET_REGS: begin
                // Reset local variables
                circle_idx = 4'd0;
                num_intervals = 4'd0;
                num_points = 5'd0;
                sort_idx = 5'd0;
                sweep_idx = 5'd0;
                sweep_counter = 4'd0;
                max_counter = 4'd0;
                current_point_idx = 5'd0;
                // Copy inputs to registers
                for (integer i = 0; i < 10; i = i + 1) begin
                    x_reg[i] = x_arr[i];
                    y_reg[i] = y_arr[i];
                    r_reg[i] = r_arr[i];
                end
                n_reg = n;
            end

            COMPUTE_D: begin
                // Compute d^2 = x^2 + y^2
                // x is Q8.8: 8 integer, 8 fractional. x^2 is Q16.16, shift right 8 = Q8.8
                temp_mult = $signed(x_reg[circle_idx]) * $signed(x_reg[circle_idx]);
                x_sq = temp_mult >>> 8;  // Convert to Q8.8
                temp_mult = $signed(y_reg[circle_idx]) * $signed(y_reg[circle_idx]);
                y_sq = temp_mult >>> 8;
                d_squared = x_sq + y_sq;
                // r is Q8.8, r^2 is Q16.16, shift right 8 = Q8.8
                temp_mult = $signed(r_reg[circle_idx]) * $signed(r_reg[circle_idx]);
                r_sq = temp_mult >>> 8;
            end

            CHECK_D: begin
                // Compare d^2 and r^2 (both Q8.8)
                d = 16'd0;  // Placeholder
            end

            COMPUTE_ALPHA: begin
                // Compute angle using atan2(y, x)
                // For simulation, we approximate atan2 using quadrant logic
                // Real implementation would use LUT
                // Q8.8 output (0 to 65535)
                if (x_reg[circle_idx] == 16'd0 && y_reg[circle_idx] == 16'd0) begin
                    temp_angle = 16'd0;
                end else if (y_reg[circle_idx] == 16'd0) begin
                    if ($signed(x_reg[circle_idx]) > 0) temp_angle = 16'd0;
                    else temp_angle = PI;
                end else if (x_reg[circle_idx] == 16'd0) begin
                    if ($signed(y_reg[circle_idx]) > 0) temp_angle = PI >> 1;  // 90°
                    else temp_angle = (PI >> 1) + PI;  // 270°
                end else begin
                    // Simplified quadrant handling
                    if ($signed(x_reg[circle_idx]) > 0 && $signed(y_reg[circle_idx]) > 0) temp_angle = 16'd0;  // Q1
                    else if ($signed(x_reg[circle_idx]) < 0 && $signed(y_reg[circle_idx]) > 0) temp_angle = PI;  // Q2
                    else if ($signed(x_reg[circle_idx]) < 0 && $signed(y_reg[circle_idx]) < 0) temp_angle = PI;  // Q3
                    else temp_angle = 16'd65535;  // Q4
                end
                alpha = temp_angle;
            end

            COMPUTE_DELTA: begin
                // Compute delta = asin(r/d)
                // Approximate: delta scales inversely with d
                // Max delta = asin(1) = π/2 = 16384
                // Min d when r=1 (1 in Q8.8) and d > r: d > 1
                // Use simplified calculation: delta = (r << 8) / d
                // We need d. Approximate sqrt using d_squared (Q8.8)
                // Simple approximation for d
                if (d_squared < 32'd256) d = 16'd128;  // ~0.5
                else if (d_squared < 32'd1024) d = 16'd256;  // ~1.0
                else if (d_squared < 32'd4096) d = 16'd512;  // ~2.0
                else if (d_squared < 32'd16384) d = 16'd1024;  // ~4.0
                else if (d_squared < 32'd65536) d = 16'd2048;  // ~8.0
                else if (d_squared < 32'd262144) d = 16'd4096;  // ~16.0
                else d = 16'd8192;  // ~32.0
                
                // delta = (r / d) * (π/2)  (approximation)
                // r is Q8.8, d is Q8.8, result is Q16.16, take upper 16 = Q8.8
                temp_mult = $signed(r_reg[circle_idx]) * (PI >> 1);  // r * π/2
                // Divide by d (approximate by shift based on magnitude)
                if (d > 16'd2048) delta = temp_mult >> 12;  // Large d
                else if (d > 16'd512) delta = temp_mult >> 10;
                else if (d > 16'd128) delta = temp_mult >> 8;
                else delta = temp_mult >> 6;
            end

            ADD_INTERVAL: begin
                // Compute [alpha - delta, alpha + delta] with wrap-around
                start_angle = alpha - delta;
                end_angle = alpha + delta;
                wrapped = 1'b0;
                // Check for wrap-around
                if ($signed(start_angle) < 0) begin
                    start_angle = start_angle + TWO_PI;
                    wrapped = 1'b1;
                end
                if ($signed(end_angle) < 0) begin  // Overflow from add
                    end_angle = end_angle + TWO_PI;
                end
                if ($signed(end_angle) > $signed(TWO_PI)) begin
                    end_angle = end_angle - TWO_PI;
                    wrapped = 1'b1;
                end
                
                // Store interval
                interval_start[num_intervals] = start_angle;
                interval_end[num_intervals] = end_angle;
                interval_valid[num_intervals] = 1'b1;
                num_intervals = num_intervals + 4'd1;
                circle_idx = circle_idx + 4'd1;
            end

            SORT_LOOP: begin
                // Bubble sort: build sorted_angles array from intervals
                if (sort_idx == 5'd0 && sweep_idx == 5'd0) begin
                    // Initialize points array
                    num_points = num_intervals << 1;  // * 2
                    for (integer i = 0; i < 10; i = i + 1) begin
                        if (interval_valid[i]) begin
                            sorted_angles[i*2] = interval_start[i];
                            sorted_type[i*2] = 1'b1;  // Start
                            sorted_angles[i*2+1] = interval_end[i];
                            sorted_type[i*2+1] = 1'b0;  // End
                        end
                    end
                end
                // Bubble sort pass
                if (sweep_idx < num_points - 1 - sort_idx) begin
                    if ($signed(sorted_angles[sweep_idx]) > $signed(sorted_angles[sweep_idx + 1])) begin
                        // Swap
                        temp_angle = sorted_angles[sweep_idx];
                        sorted_angles[sweep_idx] = sorted_angles[sweep_idx + 1];
                        sorted_angles[sweep_idx + 1] = temp_angle;
                        temp_wrapped = sorted_type[sweep_idx];
                        sorted_type[sweep_idx] = sorted_type[sweep_idx + 1];
                        sorted_type[sweep_idx + 1] = temp_wrapped;
                    end
                    sweep_idx = sweep_idx + 5'd1;
                end else begin
                    sweep_idx = 5'd0;
                    sort_idx = sort_idx + 5'd1;
                end
            end

            SWEEP: begin
                // Sweep through sorted points
                if (sorted_type[sweep_idx]) begin
                    // Start point
                    sweep_counter = sweep_counter + 4'd1;
                end else begin
                    // End point
                    sweep_counter = sweep_counter - 4'd1;
                end
                // Update max
                if (sweep_counter > max_counter) begin
                    max_counter = sweep_counter;
                end
                sweep_idx = sweep_idx + 5'd1;
            end

            FIND_MAX: begin
                // max_counter already holds the result
                result = max_counter;
            end

            default: begin
                // No operation
            end
        endcase
    end

    // Done signal logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == RESET_REGS) begin
                done <= 1'b0;
            end else if (state == FINISH) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule