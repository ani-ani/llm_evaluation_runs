module ComplexToPolar (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] real_in,
    input wire signed [7:0] imag_in,
    output reg signed [31:0] magnitude,
    output reg signed [31:0] angle,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] SAMPLE      = 3'd1;
    localparam [2:0] SQRT_INIT   = 3'd2;
    localparam [2:0] SQRT_ITER   = 3'd3;
    localparam [2:0] ATAN_CALC   = 3'd4;
    localparam [2:0] FINISH      = 3'd5;

    // State register
    reg [2:0] state;
    reg [2:0] next_state;

    // Registers for input data
    reg signed [7:0]  r_reg, i_reg;
    reg signed [31:0] r_fp, i_fp;
    reg signed [31:0] r_sq, i_sq;
    reg signed [63:0] sum_temp;

    // Square root registers
    reg signed [31:0] sqrt_val;
    reg signed [31:0] sqrt_prev;
    reg signed [31:0] sqrt_next;
    reg signed [63:0] sqrt_div_temp;
    reg signed [31:0] sqrt_div_result;
    reg signed [31:0] sqrt_sum;
    reg [5:0] sqrt_counter; // Max 32 iterations

    // Angle registers
    reg signed [31:0] abs_r, abs_i;
    reg signed [63:0] atan_temp;
    reg signed [31:0] atan_val;
    reg signed [31:0] quarter_pi_fp;
    reg signed [31:0] half_pi_fp;
    reg signed [31:0] pi_fp;
    reg signed [31:0] neg_pi_fp;
    reg [1:0] quadrant;

    // Control registers
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Helper for sign extension
    wire signed [31:0] r_fp_wire = {r_reg[7], r_reg[7], r_reg[7], r_reg[7], r_reg[7], r_reg[7], r_reg[7], r_reg[7], r_reg[7], r_reg[7], r_reg[7], r_reg[7], r_reg[7], r_reg[7], r_reg[7], r_reg[7], r_reg[7:0], 16'd0};
    wire signed [31:0] i_fp_wire = {i_reg[7], i_reg[7], i_reg[7], i_reg[7], i_reg[7], i_reg[7], i_reg[7], i_reg[7], i_reg[7], i_reg[7], i_reg[7], i_reg[7], i_reg[7], i_reg[7], i_reg[7], i_reg[7], i_reg[7:0], 16'd0};

    // Precomputed constants for atan2 approximation
    // π in Q16.16 = 0x3243F = 205887
    // π/2 = 102943, π/4 = 51471
    localparam signed [31:0] PI_FP       = 32'sd205887;
    localparam signed [31:0] HALF_PI_FP  = 32'sd102943;
    localparam signed [31:0] QUARTER_PI_FP = 32'sd51471;
    localparam signed [31:0] NEG_PI_FP   = -32'sd205887;

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = SAMPLE;
            SAMPLE: next_state = SQRT_INIT;
            SQRT_INIT: next_state = SQRT_ITER;
            SQRT_ITER: if (sqrt_counter >= 5'd20) next_state = ATAN_CALC;
            ATAN_CALC: next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State transitions and logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            magnitude <= 32'd0;
            angle <= 32'd0;
            done <= 1'b0;
            r_reg <= 8'd0;
            i_reg <= 8'd0;
            r_fp <= 32'd0;
            i_fp <= 32'd0;
            r_sq <= 32'd0;
            i_sq <= 32'd0;
            sum_temp <= 64'd0;
            sqrt_val <= 32'd0;
            sqrt_prev <= 32'd0;
            sqrt_next <= 32'd0;
            sqrt_div_temp <= 64'd0;
            sqrt_div_result <= 32'd0;
            sqrt_sum <= 32'd0;
            sqrt_counter <= 5'd0;
            abs_r <= 32'd0;
            abs_i <= 32'd0;
            atan_temp <= 64'd0;
            atan_val <= 32'd0;
            quarter_pi_fp <= 32'd0;
            half_pi_fp <= HALF_PI_FP;
            pi_fp <= PI_FP;
            neg_pi_fp <= NEG_PI_FP;
            quadrant <= 2'd0;
            cycle_counter <= 8'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    cycle_counter <= 8'd0;
                    // Ensure done is low when waiting
                    done <= 1'b0;
                end

                SAMPLE: begin
                    // Sample inputs and convert to Q16.16
                    r_reg <= real_in;
                    i_reg <= imag_in;
                    r_fp <= r_fp_wire;
                    i_fp <= i_fp_wire;
                    cycle_counter <= cycle_counter + 8'd1;
                end

                SQRT_INIT: begin
                    // Calculate r^2 + i^2
                    // r_fp is Q16.16, square is Q32.32, take middle 32 bits for sum
                    r_sq <= r_fp * r_fp; // Truncates to Q32.32 (keeping MSBs)
                    i_sq <= i_fp * i_fp; // Truncates to Q32.32 (keeping MSBs)
                    // Initial guess for sqrt (magnitude of input integer)
                    sqrt_val <= (r_reg > i_reg) ? {24'd0, r_reg[7:0]} : {24'd0, i_reg[7:0]};
                    sqrt_prev <= 32'd0;
                    sqrt_counter <= 5'd0;
                    cycle_counter <= cycle_counter + 8'd1;
                end

                SQRT_ITER: begin
                    if (cycle_counter < MAX_CYCLES) begin
                        cycle_counter <= cycle_counter + 8'd1;
                    end
                    
                    if (sqrt_counter < 5'd20) begin
                        // Babylonian method for fixed point sqrt
                        // sum = (r^2 + i^2) >> 16 to get back to Q16.16 magnitude squared
                        // Actually, input is Q32.32. Let's adjust.
                        // r_sq = (r_fp * r_fp) >> 32. For calculation we need value in Q16.16
                        // Let's use r_sq[47:16] which is Q16.16 approx
                        
                        sum_temp = {r_sq[47:16], 16'd0} + {i_sq[47:16], 16'd0};
                        
                        // div: (sum / sqrt_val) ... careful with widths
                        // sum is Q16.16, sqrt_val is Q0.16 (integer part negligible in guess)
                        // Let's treat sqrt_val as Q16.16 for division logic
                        sqrt_div_temp = {sum_temp[63:0]}; // Q32.32
                        
                        // Division: sqrt_div_temp / sqrt_val
                        // sqrt_val is integer (scaled), treat as Q16.16 for division result
                        sqrt_div_result = sqrt_div_temp[63:32] == 0 ? sqrt_div_temp[31:0] / sqrt_val : 32'hFFFFFFFF;

                        // sqrt_next = (sqrt_val + sqrt_div_result) / 2
                        sqrt_next = (sqrt_val + sqrt_div_result) >>> 1;
                        
                        if (sqrt_next == sqrt_val || sqrt_next == sqrt_prev) begin
                            // Converged or oscillating
                            sqrt_counter <= 5'd20; // Force finish
                        end else begin
                            sqrt_prev <= sqrt_val;
                            sqrt_val <= sqrt_next;
                            sqrt_counter <= sqrt_counter + 5'd1;
                        end
                    end
                end

                ATAN_CALC: begin
                    if (cycle_counter < MAX_CYCLES) begin
                        cycle_counter <= cycle_counter + 8'd1;
                    end
                    
                    // Determine quadrant and absolute values
                    quadrant <= 2'd0;
                    abs_r <= r_fp;
                    abs_i <= i_fp;
                    
                    if (r_fp[31]) begin // r < 0
                        abs_r <= -r_fp;
                        if (i_fp[31]) begin // i < 0
                            abs_i <= -i_fp;
                            quadrant <= 2'd3; // Q3
                        end else begin
                            quadrant <= 2'd2; // Q2
                        end
                    end else begin // r >= 0
                        if (i_fp[31]) begin // i < 0
                            abs_i <= -i_fp;
                            quadrant <= 2'd1; // Q1
                        end else begin
                            quadrant <= 2'd0; // Q0
                        end
                    end

                    // Handle special cases
                    // Real=0, Imag=0
                    if (r_fp == 32'd0 && i_fp == 32'd0) begin
                        magnitude <= 32'd0;
                        angle <= 32'd0;
                    end else begin
                        // Magnitude is sqrt_val (already Q16.16 approx)
                        magnitude <= sqrt_val;

                        // Angle calculation using approximation: atan(y/x)
                        // y/x = abs_i / abs_r (Q16.16 / Q16.16 = Q0.32)
                        if (abs_r == 32'd0) begin
                            // r = 0, angle is π/2
                            atan_val <= HALF_PI_FP;
                        end else begin
                            // atan approx: pi/4 * (y/x) * (2 - y/x) or simple division
                            // Use 4th order polynomial or just ratio for simplicity here
                            // Let's use ratio: angle = pi/2 * (y / (x+y)) ... not great.
                            // Let's use atan(y/x) ≈ π/4 * y/x (linear approx) + correction
                            // For FPGA simplicity, we'll use a scaled polynomial approximation of atan2
                            // or just a high-order interpolator. 
                            // Given constraint of 100 cycles, let's do a linear approximation on the division result
                            
                            // Division: abs_i / abs_r
                            // Result in Q0.32. We need to scale to Q16.16
                            atan_temp = {abs_i, 32'd0}; // Q16.48
                            atan_val = atan_temp / abs_r; // Q0.48 result, keep top Q16.16 (approx)
                            // atan_val is now approx (y/x) in Q16.16
                            
                            // Scale by π/4 (0.785) to get angle in radians
                            atan_val = (atan_val * QUARTER_PI_FP) >>> 16;
                        end

                        // Adjust based on quadrant
                        case (quadrant)
                            2'd0: angle <= atan_val; // 0 to π/2
                            2'd1: angle <= -atan_val; // -π/2 to 0
                            2'd2: angle <= pi_fp - atan_val; // π/2 to π
                            2'd3: angle <= neg_pi_fp + atan_val; // -π to -π/2
                            default: angle <= 32'd0;
                        endcase
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    // Result already stored in magnitude/angle
                end
            endcase
        end
    end
endmodule