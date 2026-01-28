module hovercraft_trajectory_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [23:0] x,
    input wire signed [23:0] y,
    input wire signed [23:0] v,
    input wire signed [23:0] w,
    output reg signed [31:0] result_time,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPUTE_A = 3'd1;
    localparam [2:0] COMPUTE_B = 3'd2;
    localparam [2:0] COMPARE   = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd500;

    // Fixed-point conversion registers
    reg signed [31:0] x_fp, y_fp, v_fp, w_fp;
    reg signed [31:0] d_squared, d_fp;
    reg signed [31:0] alpha, theta, arcsin_val;
    reg signed [31:0] case_a_time, case_b_time;
    reg signed [31:0] temp_mult, temp_div;

    // Square root registers
    reg [31:0] sqrt_reg, sqrt_temp;
    reg [4:0] sqrt_iter;

    // Division registers
    reg [31:0] div_reg, div_temp;
    reg [15:0] div_iter;

    // atan2 lookup table (8-bit)
    reg signed [7:0] atan2_table [0:255];
    integer i;

    // Initialize atan2 table
    initial begin
        // Simplified atan2 values for demonstration
        for (i = 0; i < 256; i = i + 1) begin
            atan2_table[i] = 8'd0; // Placeholder - actual values would be precomputed
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result_time <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize all computation registers
            x_fp <= 32'd0;
            y_fp <= 32'd0;
            v_fp <= 32'd0;
            w_fp <= 32'd0;
            d_squared <= 32'd0;
            d_fp <= 32'd0;
            alpha <= 32'd0;
            theta <= 32'd0;
            arcsin_val <= 32'd0;
            case_a_time <= 32'd0;
            case_b_time <= 32'd0;
            temp_mult <= 32'd0;
            temp_div <= 32'd0;

            sqrt_reg <= 32'd0;
            sqrt_temp <= 32'd0;
            sqrt_iter <= 5'd0;

            div_reg <= 32'd0;
            div_temp <= 32'd0;
            div_iter <= 16'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE_A;
                        // Convert inputs to Q16.16
                        x_fp <= {{8{x[23]}}, x[23:0]}; // Sign extend to 32-bit
                        y_fp <= {{8{y[23]}}, y[23:0]};
                        v_fp <= {{8{v[23]}}, v[23:0]};
                        w_fp <= {{8{w[23]}}, w[23:0]};
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_A: begin
                    // Compute d = sqrt(x^2 + y^2)
                    // First compute x^2 and y^2
                    temp_mult <= x_fp * x_fp;
                    d_squared <= temp_mult + (y_fp * y_fp);

                    // Square root computation
                    sqrt_reg <= 32'd0;
                    sqrt_temp <= d_squared;
                    sqrt_iter <= 5'd0;
                    next_state <= COMPUTE_A + 1'b1;
                end

                COMPUTE_A + 1'b1: begin
                    // Iterative square root (16 iterations)
                    if (sqrt_iter < 5'd16) begin
                        sqrt_reg <= (sqrt_reg + (d_squared / sqrt_reg)) >> 1;
                        sqrt_iter <= sqrt_iter + 5'd1;
                        next_state <= COMPUTE_A + 1'b1;
                    end else begin
                        d_fp <= sqrt_reg;
                        next_state <= COMPUTE_A + 2'b1;
                    end
                end

                COMPUTE_A + 2'b1: begin
                    // Compute alpha = atan2(y, x)
                    // Simplified: use lookup table based on quadrant
                    if (x_fp == 32'd0 && y_fp == 32'd0) begin
                        alpha <= 32'd0;
                    end else if (x_fp >= 32'd0 && y_fp >= 32'd0) begin
                        // Quadrant I
                        alpha <= atan2_table[0]; // Placeholder
                    end else if (x_fp < 32'd0 && y_fp >= 32'd0) begin
                        // Quadrant II
                        alpha <= atan2_table[64]; // Placeholder
                    end else if (x_fp < 32'd0 && y_fp < 32'd0) begin
                        // Quadrant III
                        alpha <= atan2_table[128]; // Placeholder
                    end else begin
                        // Quadrant IV
                        alpha <= atan2_table[192]; // Placeholder
                    end
                    next_state <= COMPUTE_A + 3'b1;
                end

                COMPUTE_A + 3'b1: begin
                    // Compute case A time
                    // Check if d <= 2v/|w|
                    temp_mult <= v_fp << 1; // 2v
                    temp_div <= temp_mult / (w_fp[31] ? -w_fp : w_fp); // 2v/|w|
                    
                    if (d_fp <= temp_div) begin
                        // Time = |alpha|/|w| + d/v
                        temp_mult <= alpha[31] ? -alpha : alpha; // |alpha|
                        temp_div <= temp_mult / (w_fp[31] ? -w_fp : w_fp); // |alpha|/|w|
                        case_a_time <= temp_div + (d_fp / v_fp);
                    end else begin
                        // Time = (|alpha| + pi)/|w| + (d - 2v/|w|)/v
                        temp_mult <= alpha[31] ? -alpha : alpha; // |alpha|
                        temp_mult <= temp_mult + 32'd52429; // + pi (approx 3.1415926535 in Q16.16)
                        temp_div <= temp_mult / (w_fp[31] ? -w_fp : w_fp); // (|alpha| + pi)/|w|
                        temp_mult <= d_fp - temp_div; // d - 2v/|w|
                        case_a_time <= temp_div + (temp_mult / v_fp);
                    end
                    next_state <= COMPUTE_B;
                end

                COMPUTE_B: begin
                    // Compute case B time if y < 0
                    if (y_fp < 32'd0) begin
                        // Time = |x|/v + pi/|w|
                        temp_mult <= x_fp[31] ? -x_fp : x_fp; // |x|
                        temp_div <= temp_mult / v_fp; // |x|/v
                        temp_mult <= 32'd52429; // pi in Q16.16
                        temp_mult <= temp_mult / (w_fp[31] ? -w_fp : w_fp); // pi/|w|
                        case_b_time <= temp_div + temp_mult;
                    end else begin
                        case_b_time <= 32'd100000000; // Large value if case B not applicable
                    end
                    next_state <= COMPARE;
                end

                COMPARE: begin
                    // Compare case A and case B times
                    if (case_a_time < case_b_time) begin
                        result_time <= case_a_time;
                    end else begin
                        result_time <= case_b_time;
                    end
                    next_state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule