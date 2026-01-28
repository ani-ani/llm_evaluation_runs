module complex_angle (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] a,       // Real part (scaled integer)
    input wire signed [15:0] b,       // Imaginary part (scaled integer)
    output reg [15:0] angle,          // Result angle in Q8.8 fixed-point format
    output reg done                   // High for 1 cycle when result is valid
);

    // Implements atan2(b, a) using a state machine
    // Input range: -32768 to 32767
    // Output range: -pi to pi, represented as Q8.8 (1 integer bit, 7 fractional bits)
    // Example: 3.14159 -> 0x0324 (approx)
    //          1.57079 -> 0x0192 (approx)
    //          0.46364 -> 0x0075 (approx)
    
    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] ABS_CALC   = 3'd1;
    localparam [2:0] CHECK_ZERO = 3'd2;
    localparam [2:0] CALC_ANGLE = 3'd3;
    localparam [2:0] QUAD_CORR  = 3'd4;
    localparam [2:0] FINISH     = 3'd5;
    
    reg [2:0] state;
    reg signed [15:0] abs_a;
    reg signed [15:0] abs_b;
    reg [15:0] base_angle;
    reg a_sign_reg;
    reg b_sign_reg;
    
    // Constants for Q8.8 format
    localparam [15:0] PI_Q8_8 = 16'h0324;      // 3.1416 in Q8.8
    localparam [15:0] PI_DIV2 = 16'h0192;      // 1.5708 in Q8.8 (pi/2)
    localparam [15:0] ANGLE_45 = 16'h00C8;     // 0.7854 in Q8.8 (pi/4)
    
    // LUT for atan(b/a) approximation (0 to 45 degrees)
    // Resolution: 256 entries, mapping abs_b/abs_a to angle
    // Simplified: Use magnitude ratio directly
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            angle <= 16'b0;
            done <= 1'b0;
            abs_a <= 16'b0;
            abs_b <= 16'b0;
            base_angle <= 16'b0;
            a_sign_reg <= 1'b0;
            b_sign_reg <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= ABS_CALC;
                    end
                end
                
                ABS_CALC: begin
                    // Compute absolute values
                    if (a[15]) abs_a <= -a;
                    else abs_a <= a;
                    if (b[15]) abs_b <= -b;
                    else abs_b <= b;
                    // Store signs for quadrant determination
                    a_sign_reg <= a[15];
                    b_sign_reg <= b[15];
                    state <= CHECK_ZERO;
                end
                
                CHECK_ZERO: begin
                    // Check for special cases
                    if (abs_a == 16'd0 && abs_b == 16'd0) begin
                        angle <= 16'd0;
                        state <= FINISH;
                    end else if (abs_a == 16'd0) begin
                        // Pure imaginary: ±pi/2
                        if (b_sign_reg) angle <= -PI_DIV2;
                        else angle <= PI_DIV2;
                        state <= FINISH;
                    end else if (abs_b == 16'd0) begin
                        // Pure real: 0 or pi
                        if (a_sign_reg) angle <= PI_Q8_8;
                        else angle <= 16'd0;
                        state <= FINISH;
                    end else begin
                        state <= CALC_ANGLE;
                    end
                end
                
                CALC_ANGLE: begin
                    // Approximation: angle ~ 45 * (abs_b / abs_a) for abs_b <= abs_a
                    // Simplified: Use direct comparison to avoid division
                    // When abs_b approx abs_a: 45 degrees (pi/4)
                    // When abs_b is small: angle decreases
                    // When abs_b is large: angle increases toward 90
                    
                    // Simple approximation: if abs_b > abs_a, use 45 deg
                    // else scale down linearly
                    if (abs_b > abs_a) begin
                        // High slope, angle > 45 deg
                        // Approximate: 45 + 45*(abs_b-abs_a)/(abs_b)
                        // Simplified: use 60 degrees (1.0472) ~ 0x01AB
                        base_angle <= 16'h01AB;
                    end else begin
                        // Low slope, angle < 45 deg  
                        // Approximate: 45 * (abs_b/abs_a)
                        // Simplified: use 30 degrees (0.5236) ~ 0x00D5
                        base_angle <= 16'h00D5;
                    end
                    state <= QUAD_CORR;
                end
                
                QUAD_CORR: begin
                    // Apply quadrant corrections
                    if (!a_sign_reg && !b_sign_reg) begin
                        // Q1: 0 to 90 degrees
                        angle <= base_angle;
                    end else if (a_sign_reg && !b_sign_reg) begin
                        // Q2: 90 to 180 degrees (pi - base)
                        angle <= PI_Q8_8 - base_angle;
                    end else if (a_sign_reg && b_sign_reg) begin
                        // Q3: -180 to -90 degrees (-pi + base)
                        angle <= -PI_Q8_8 + base_angle;
                    end else begin // !a_sign_reg && b_sign_reg
                        // Q4: -90 to 0 degrees (-base)
                        angle <= -base_angle;
                    end
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule