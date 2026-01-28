module area_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [31:0] c,
    output reg [31:0] area,
    output reg done
);

    // State declarations
    localparam [4:0] IDLE          = 5'd0;
    localparam [4:0] SQUARE_A      = 5'd1;
    localparam [4:0] SQUARE_B      = 5'd2;
    localparam [4:0] SQUARE_C      = 5'd3;
    localparam [4:0] CALC_S        = 5'd4;
    localparam [4:0] CALC_P1       = 5'd5;
    localparam [4:0] CALC_P2       = 5'd6;
    localparam [4:0] CALC_P3       = 5'd7;
    localparam [4:0] CALC_P4       = 5'd8;
    localparam [4:0] CALC_P5       = 5'd9;
    localparam [4:0] CALC_P6       = 5'd10;
    localparam [4:0] CALC_D        = 5'd11;
    localparam [4:0] CHECK_D       = 5'd12;
    localparam [4:0] SQRT_INIT     = 5'd13;
    localparam [4:0] SQRT_LOOP     = 5'd14;
    localparam [4:0] CALC_T        = 5'd15;
    localparam [4:0] CHECK_T       = 5'd16;
    localparam [4:0] CALC_AREA     = 5'd17;
    localparam [4:0] DONE_STATE    = 5'd18;
    localparam [4:0] ERROR_STATE   = 5'd19;

    reg [4:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Intermediate registers (64-bit for Q16.16 operations)
    reg signed [63:0] a_reg, b_reg, c_reg;
    reg signed [63:0] a2, b2, c2;
    reg signed [63:0] S;
    reg signed [63:0] p1, p2, p3, p4, p5, p6; // Products
    reg signed [63:0] D;
    reg signed [63:0] sqrt_D;
    reg signed [63:0] t;
    reg signed [63:0] lower_bound;
    reg signed [63:0] temp_mult;
    
    // Square root variables
    reg signed [63:0] sqrt_val;
    reg signed [63:0] sqrt_rem;
    reg signed [63:0] sqrt_root;
    reg [5:0] sqrt_bit;
    
    // Constants
    localparam [31:0] SQRT3_DIV4 = 16'd28378; // Q16.16 format: sqrt(3)/4
    
    // Helper for abs value
    wire signed [63:0] abs_diff_ab = (a2 > b2) ? (a2 - b2) : (b2 - a2);
    wire signed [63:0] abs_diff_bc = (b2 > c2) ? (b2 - c2) : (c2 - b2);
    wire signed [63:0] abs_diff_ac = (a2 > c2) ? (a2 - c2) : (c2 - a2);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            area <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            a_reg <= 64'd0;
            b_reg <= 64'd0;
            c_reg <= 64'd0;
            a2 <= 64'd0;
            b2 <= 64'd0;
            c2 <= 64'd0;
            S <= 64'd0;
            p1 <= 64'd0;
            p2 <= 64'd0;
            p3 <= 64'd0;
            p4 <= 64'd0;
            p5 <= 64'd0;
            p6 <= 64'd0;
            D <= 64'd0;
            sqrt_D <= 64'd0;
            t <= 64'd0;
            lower_bound <= 64'd0;
            temp_mult <= 64'd0;
            sqrt_val <= 64'd0;
            sqrt_rem <= 64'd0;
            sqrt_root <= 64'd0;
            sqrt_bit <= 6'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Load inputs (Q16.16 -> extend to Q32.32 for internal calc)
                        a_reg <= {16'd0, a, 16'd0};
                        b_reg <= {16'd0, b, 16'd0};
                        c_reg <= {16'd0, c, 16'd0};
                    end
                end
                
                SQUARE_A: begin
                    // a2 = (a * a) >> 16
                    temp_mult <= a_reg * a_reg;
                end
                SQUARE_B: begin
                    b2 <= temp_mult[47:16]; // Extract Q16.16
                    temp_mult <= b_reg * b_reg;
                end
                SQUARE_C: begin
                    c2 <= temp_mult[47:16];
                    temp_mult <= c_reg * c_reg;
                end
                
                CALC_S: begin
                    a2 <= temp_mult[47:16];
                    // S = a2 + b2 + c2 (all Q16.16)
                    S <= a2 + b2 + c2;
                end
                
                CALC_P1: begin
                    // p1 = (a2 * b2) >> 16
                    temp_mult <= a2 * b2;
                end
                CALC_P2: begin
                    p1 <= temp_mult[47:16];
                    // p2 = (a2 * c2) >> 16
                    temp_mult <= a2 * c2;
                end
                CALC_P3: begin
                    p2 <= temp_mult[47:16];
                    // p3 = (b2 * c2) >> 16
                    temp_mult <= b2 * c2;
                end
                CALC_P4: begin
                    p3 <= temp_mult[47:16];
                    // p4 = (a2 * a2) >> 16
                    temp_mult <= a2 * a2;
                end
                CALC_P5: begin
                    p4 <= temp_mult[47:16];
                    // p5 = (b2 * b2) >> 16
                    temp_mult <= b2 * b2;
                end
                CALC_P6: begin
                    p5 <= temp_mult[47:16];
                    // p6 = (c2 * c2) >> 16
                    temp_mult <= c2 * c2;
                end
                
                CALC_D: begin
                    p6 <= temp_mult[47:16];
                    // D = 3 * ( 2*(p1+p2+p3) - (p4+p5+p6) )
                    // Calculate temp = 2*(p1+p2+p3) - (p4+p5+p6)
                    temp_mult <= ( (p1 + p2 + p3) << 1 ) - (p4 + p5 + p6);
                end
                
                CHECK_D: begin
                    D <= temp_mult * 32'sd3; // D in Q16.16 (scaled)
                    if (temp_mult < 0) begin
                        // D < 0, invalid
                        area <= 32'hFFFFFFFF;
                    end
                end
                
                SQRT_INIT: begin
                    if (D >= 0) begin
                        // Prepare for sqrt: val = D * 65536 (to get better precision in Q32.32)
                        // Actually, we need sqrt(D) where D is Q16.16. 
                        // Result should be Q16.16. 
                        // sqrt(D) = sqrt(D << 16) >> 8
                        // Let's just compute integer sqrt of D scaled up.
                        sqrt_val <= D <<< 16; // Shift left 16 for precision
                        sqrt_root <= 64'd0;
                        sqrt_rem <= 64'd0;
                        sqrt_bit <= 6'd31; // 32 iterations (D is 64-bit max)
                    end
                end
                
                SQRT_LOOP: begin
                    // Non-restoring algorithm or simple restoring
                    // Simple restoring square root (bit-by-bit)
                    if (sqrt_bit > 0) begin
                        sqrt_rem <= (sqrt_rem <<< 2) | ((sqrt_val >> (sqrt_bit*2)) & 2'd3);
                        sqrt_root <= sqrt_root <<< 1;
                        
                        if (sqrt_rem >= (sqrt_root <<< 1) + 1) begin
                            sqrt_rem <= sqrt_rem - ((sqrt_root <<< 1) + 1);
                            sqrt_root <= sqrt_root + 1;
                        end
                        sqrt_bit <= sqrt_bit - 6'd1;
                    end
                end
                
                CALC_T: begin
                    // sqrt_D = sqrt_root >> 8 (convert Q32.32 -> Q16.16)
                    sqrt_D <= sqrt_root >>> 8;
                    // t = (S + sqrt_D) >> 1
                    t <= (S + (sqrt_root >>> 8)) >>> 1;
                end
                
                CHECK_T: begin
                    // lower_bound = max( |a2-b2|, 2*c2-a2-b2, 2*b2-a2-c2, 2*a2-b2-c2 )
                    // Note: These calcs are in Q16.16 (scaled by 2)
                    // val1 = |a2 - b2|
                    // val2 = 2*c2 - a2 - b2
                    // val3 = 2*b2 - a2 - c2
                    // val4 = 2*a2 - b2 - c2
                    
                    // Find max
                    lower_bound <= abs_diff_ab; // Initialize
                    
                    // Check val2
                    temp_mult <= (c2 <<< 1) - a2 - b2;
                end
                
                CALC_AREA: begin
                    // Check remaining bounds
                    if (temp_mult > lower_bound) lower_bound <= temp_mult;
                    
                    // Check val3
                    temp_mult <= (b2 <<< 1) - a2 - c2;
                    if (((b2 <<< 1) - a2 - c2) > lower_bound) lower_bound <= ((b2 <<< 1) - a2 - c2);
                    
                    // Check val4
                    if (((a2 <<< 1) - b2 - c2) > lower_bound) lower_bound <= ((a2 <<< 1) - b2 - c2);
                    
                    // Final check
                    if (t < lower_bound) begin
                        area <= 32'hFFFFFFFF;
                    end else begin
                        // area = (28378 * t) >> 16
                        temp_mult <= SQRT3_DIV4 * t[31:0]; // t is Q16.16, upper bits likely 0 for valid range
                        // (since we are dealing with geometry, t shouldn't be huge)
                    end
                end
                
                DONE_STATE: begin
                    if (temp_mult[63:32] == 0) begin
                        area <= temp_mult[31:0]; // Result is 32-bit Q16.16
                    end else begin
                        // Saturate or error if overflow (though unlikely for valid triangles)
                        area <= 32'hFFFFFFFF;
                    end
                    done <= 1'b1;
                end
                
                ERROR_STATE: begin
                    // Just asserts done for invalid cases
                    done <= 1'b1;
                end
            endcase
            
            // Cycle counter
            if (state != IDLE && state != DONE_STATE && state != ERROR_STATE) begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE:           next_state = start ? SQUARE_A : IDLE;
            SQUARE_A:       next_state = SQUARE_B;
            SQUARE_B:       next_state = SQUARE_C;
            SQUARE_C:       next_state = CALC_S;
            CALC_S:         next_state = CALC_P1;
            CALC_P1:        next_state = CALC_P2;
            CALC_P2:        next_state = CALC_P3;
            CALC_P3:        next_state = CALC_P4;
            CALC_P4:        next_state = CALC_P5;
            CALC_P5:        next_state = CALC_P6;
            CALC_P6:        next_state = CALC_D;
            CALC_D:         next_state = CHECK_D;
            CHECK_D:        next_state = (D < 0) ? ERROR_STATE : SQRT_INIT;
            SQRT_INIT:      next_state = SQRT_LOOP;
            SQRT_LOOP:      next_state = (sqrt_bit == 0) ? CALC_T : SQRT_LOOP;
            CALC_T:         next_state = CHECK_T;
            CHECK_T:        next_state = CALC_AREA;
            CALC_AREA:      next_state = DONE_STATE;
            DONE_STATE:     next_state = IDLE;
            ERROR_STATE:    next_state = IDLE;
            default:        next_state = IDLE;
        endcase
        
        // Timeout protection
        if (cycle_count >= MAX_CYCLES) begin
            next_state = ERROR_STATE;
        end
    end

endmodule