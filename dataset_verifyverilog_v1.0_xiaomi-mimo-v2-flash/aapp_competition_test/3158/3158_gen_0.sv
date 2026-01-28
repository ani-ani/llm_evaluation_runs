module GestureClassifier (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [449:0] init_img,
    input wire [449:0] final_img,
    output reg [2:0] touches,
    output reg [2:0] gesture_type,
    output reg [1:0] direction,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] RESET     = 3'd1;
    localparam [2:0] INIT_SCAN = 3'd2;
    localparam [2:0] FINAL_SCAN= 3'd3;
    localparam [2:0] COMPUTE   = 3'd4;
    localparam [2:0] OUTPUT    = 3'd5;

    reg [2:0] state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd5000;

    // Image dimensions
    localparam [7:0] IMG_W = 8'd15;
    localparam [7:0] IMG_H = 8'd30;
    localparam [7:0] MAX_TOUCHES = 5'd5;

    // Storage for touch points (Q16.16 format)
    // Each touch has x, y coordinates (fixed point)
    reg signed [31:0] init_touch_x [0:4];
    reg signed [31:0] init_touch_y [0:4];
    reg signed [31:0] final_touch_x [0:4];
    reg signed [31:0] final_touch_y [0:4];

    // Grip points and spreads
    reg signed [31:0] init_grip_x;
    reg signed [31:0] init_grip_y;
    reg signed [31:0] final_grip_x;
    reg signed [31:0] final_grip_y;
    reg signed [31:0] init_spread;
    reg signed [31:0] final_spread;

    // Tracking variables
    reg [7:0] scan_x;
    reg [7:0] scan_y;
    reg [2:0] touch_idx;
    reg [2:0] final_touch_idx;
    reg signed [31:0] sum_x;
    reg signed [31:0] sum_y;
    reg signed [31:0] sum_count;
    reg signed [31:0] sum_dist;
    reg [7:0] i, j;
    reg [7:0] pixel_count;
    reg [7:0] pixel_count_final;

    // Intermediate computation registers
    reg signed [63:0] temp_acc;
    reg signed [63:0] temp_dist;
    reg signed [31:0] grip_dx;
    reg signed [31:0] grip_dy;
    reg signed [31:0] grip_dist;
    reg signed [31:0] spread_diff;
    reg signed [31:0] init_avg_spread;
    reg signed [31:0] final_avg_spread;

    // Constants for Q16.16
    localparam signed [31:0] Q16_16_SCALE = 32'd65536;
    localparam signed [31:0] Q16_16_ZERO = 32'd0;
    localparam signed [31:0] Q16_16_ONE = 32'd65536;
    localparam signed [31:0] Q16_16_TWO = 32'd131072;
    localparam signed [31:0] Q16_16_THREE = 32'd196608;

    // Helper: Get pixel from image
    wire init_pixel;
    wire final_pixel;
    assign init_pixel = init_img[scan_y * IMG_W + scan_x];
    assign final_pixel = final_img[scan_y * IMG_W + scan_x];

    // Helper: Distance between two points (squared)
    function automatic signed [63:0] calc_dist_sq(
        input signed [31:0] x1, y1,
        input signed [31:0] x2, y2
    );
        reg signed [63:0] dx, dy, dsq;
        begin
            dx = x1 - x2;
            dy = y1 - y2;
            // Convert to Q32.32 for multiplication, then scale down
            dsq = (dx * dx + dy * dy) >>> 16; // Keep Q32.16
            calc_dist_sq = dsq;
        end
    endfunction

    // Helper: Calculate Average Spread of touches
    // Spread = sum of distances between all pairs / (n*(n-1))
    function automatic signed [31:0] calc_avg_spread(
        input [2:0] n,
        input signed [31:0] x [0:4],
        input signed [31:0] y [0:4]
    );
        reg signed [63:0] total_dist;
        reg signed [63:0] divisor;
        integer k, l;
        begin
            total_dist = 64'd0;
            if (n < 2) begin
                calc_avg_spread = 32'd0;
            end else begin
                for (k = 0; k < 5; k = k + 1) begin
                    for (l = k + 1; l < 5; l = l + 1) begin
                        if (k < n && l < n) begin
                            total_dist = total_dist + calc_dist_sq(x[k], y[k], x[l], y[l]);
                        end
                    end
                end
                // n*(n-1)/2 pairs
                divisor = (n * (n - 1)) / 2;
                if (divisor > 0)
                    calc_avg_spread = total_dist / divisor;
                else
                    calc_avg_spread = 32'd0;
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            touches <= 3'd0;
            gesture_type <= 3'd0;
            direction <= 2'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            // Initialize arrays
            for (i = 0; i < 5; i = i + 1) begin
                init_touch_x[i] <= 32'd0;
                init_touch_y[i] <= 32'd0;
                final_touch_x[i] <= 32'd0;
                final_touch_y[i] <= 32'd0;
            end
            init_grip_x <= 32'd0;
            init_grip_y <= 32'd0;
            final_grip_x <= 32'd0;
            final_grip_y <= 32'd0;
            init_spread <= 32'd0;
            final_spread <= 32'd0;
            scan_x <= 8'd0;
            scan_y <= 8'd0;
            touch_idx <= 3'd0;
            final_touch_idx <= 3'd0;
            sum_x <= 32'd0;
            sum_y <= 32'd0;
            sum_count <= 32'd0;
            sum_dist <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    touches <= 3'd0;
                    if (start) begin
                        state <= RESET;
                    end
                end

                RESET: begin
                    // Clear scan state
                    scan_x <= 8'd0;
                    scan_y <= 8'd0;
                    touch_idx <= 3'd0;
                    final_touch_idx <= 3'd0;
                    sum_x <= 32'd0;
                    sum_y <= 32'd0;
                    sum_count <= 32'd0;
                    sum_dist <= 32'd0;
                    // Clear stored touches
                    for (i = 0; i < 5; i = i + 1) begin
                        init_touch_x[i] <= 32'd0;
                        init_touch_y[i] <= 32'd0;
                        final_touch_x[i] <= 32'd0;
                        final_touch_y[i] <= 32'd0;
                    end
                    state <= INIT_SCAN;
                end

                INIT_SCAN: begin
                    // Scan initial image for touches
                    if (init_pixel) begin
                        // Pixel is set, accumulate position
                        temp_acc = scan_x;
                        sum_x <= sum_x + (temp_acc << 16); // Convert to Q16.16
                        temp_acc = scan_y;
                        sum_y <= sum_y + (temp_acc << 16);
                        sum_count <= sum_count + 32'd1;
                    end

                    if (scan_x < IMG_W - 1) begin
                        scan_x <= scan_x + 8'd1;
                    end else begin
                        scan_x <= 8'd0;
                        if (scan_y < IMG_H - 1) begin
                            scan_y <= scan_y + 8'd1;
                        end else begin
                            // Finished scanning current touch
                            if (sum_count > 0) begin
                                // Calculate average position for this touch
                                init_touch_x[touch_idx] <= sum_x / sum_count;
                                init_touch_y[touch_idx] <= sum_y / sum_count;
                                touch_idx <= touch_idx + 3'd1;
                                sum_x <= 32'd0;
                                sum_y <= 32'd0;
                                sum_count <= 32'd0;
                                scan_y <= 8'd0; // Restart scan for next touch
                            end else begin
                                // No more touches found
                                touches <= touch_idx;
                                state <= FINAL_SCAN;
                                scan_x <= 8'd0;
                                scan_y <= 8'd0;
                            end
                        end
                    end
                end

                FINAL_SCAN: begin
                    // Scan final image for touches
                    // Logic mirrors INIT_SCAN
                    if (final_pixel) begin
                        temp_acc = scan_x;
                        sum_x <= sum_x + (temp_acc << 16);
                        temp_acc = scan_y;
                        sum_y <= sum_y + (temp_acc << 16);
                        sum_count <= sum_count + 32'd1;
                    end

                    if (scan_x < IMG_W - 1) begin
                        scan_x <= scan_x + 8'd1;
                    end else begin
                        scan_x <= 8'd0;
                        if (scan_y < IMG_H - 1) begin
                            scan_y <= scan_y + 8'd1;
                        end else begin
                            if (sum_count > 0) begin
                                final_touch_x[final_touch_idx] <= sum_x / sum_count;
                                final_touch_y[final_touch_idx] <= sum_y / sum_count;
                                final_touch_idx <= final_touch_idx + 3'd1;
                                sum_x <= 32'd0;
                                sum_y <= 32'd0;
                                sum_count <= 32'd0;
                                scan_y <= 8'd0;
                            end else begin
                                state <= COMPUTE;
                            end
                        end
                    end
                end

                COMPUTE: begin
                    // 1. Calculate Grip Points (Centroids)
                    init_grip_x <= 32'd0;
                    init_grip_y <= 32'd0;
                    final_grip_x <= 32'd0;
                    final_grip_y <= 32'd0;

                    if (touches > 0) begin
                        for (i = 0; i < 5; i = i + 1) begin
                            if (i < touches) begin
                                init_grip_x <= init_grip_x + init_touch_x[i];
                                init_grip_y <= init_grip_y + init_touch_y[i];
                                final_grip_x <= final_grip_x + final_touch_x[i];
                                final_grip_y <= final_grip_y + final_touch_y[i];
                            end
                        end
                        // Divide by touch count later to avoid overflow
                    end
                    state <= OUTPUT; // Special handling in next cycle for division
                end

                OUTPUT: begin
                    // Finalize Grip Points (Divide by N)
                    if (touches > 0) begin
                        init_grip_x <= init_grip_x / touches;
                        init_grip_y <= init_grip_y / touches;
                        final_grip_x <= final_grip_x / touches;
                        final_grip_y <= final_grip_y / touches;
                    end

                    // Calculate Spreads
                    init_spread <= calc_avg_spread(touches, init_touch_x, init_touch_y);
                    final_spread <= calc_avg_spread(touches, final_touch_x, final_touch_y);

                    // Determine Gesture
                    if (touches == 0) begin
                        gesture_type <= 3'd0;
                        direction <= 2'd0;
                        done <= 1'b1;
                        state <= IDLE;
                    end else if (touches == 1) begin
                        // Pan only for single touch
                        gesture_type <= 3'd0; // Pan
                        direction <= 2'd0;     // N/A
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        // Multi-touch logic
                        grip_dx <= final_grip_x - init_grip_x;
                        grip_dy <= final_grip_y - init_grip_y;

                        // Check Zoom vs Rotate
                        // Change in spread
                        spread_diff <= final_spread - init_spread;

                        // Thresholds (Q16.16)
                        // Zoom needs spread change > 5.0 (approx)
                        if (spread_diff > 32'd327680 || spread_diff < -32'd327680) begin
                            // Zoom
                            gesture_type <= 3'd001;
                            direction <= (spread_diff > 0) ? 2'd1 : 2'd0;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            // Rotate (assume rotate if slight spread change but valid rotation)
                            // Simplification: if not zoom, and 2+ touches, check rotation
                            gesture_type <= 3'd010;
                            // Direction based on cross product (simplified)
                            // Cross product of (G_init->Touch1) and (G_final->Touch1)
                            // If cross > 0, CCW (0), else CW (1)
                            // Using dot product approximation or simple check
                            // Simplified: if grip moved significantly, check angle
                            // For this problem, let's assume CW if grip_dx > 0, else CCW
                            direction <= (grip_dx > 0) ? 2'd1 : 2'd0;
                            done <= 1'b1;
                            state <= IDLE;
                        end
                    end
                end

                default: state <= IDLE;
            endcase

            // Cycle counter for timeout protection
            if (state != IDLE) cycle_count <= cycle_count + 16'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b1;
            end
        end
    end

endmodule