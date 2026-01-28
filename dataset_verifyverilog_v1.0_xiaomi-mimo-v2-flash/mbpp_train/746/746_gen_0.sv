module AreaSector (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] radius,
    input wire [31:0] angle,
    output reg [31:0] result,
    output reg done,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK     = 3'd1;
    localparam [2:0] SQ_R      = 3'd2;
    localparam [2:0] PI_MUL    = 3'd3;
    localparam [2:0] ANG_MUL   = 3'd4;
    localparam [2:0] DIV_360   = 3'd5;
    localparam [2:0] SATURATE  = 3'd6;
    localparam [2:0] FINISH    = 3'd7;

    // Fixed-point constants
    localparam [31:0] PI_Q16_16     = 32'h3243F;       // π ~ 3.14159265
    localparam [31:0] MAX_ANGLE     = 32'h01680000;    // 360.0
    localparam [31:0] DIV_RECIP     = 32'h000015E;     // 1/360 Q16.16 ~ 0.00277777
    localparam [31:0] MAX_AREA      = 32'hFFFFFFFF;    // Saturate max
    localparam [31:0] ZERO          = 32'h00000000;

    // Internal registers
    reg [2:0] state, next_state;
    reg [31:0] r_reg, ang_reg;
    reg [47:0] temp_mul_1;  // r^2 (2x32 = 48 bits max, Q32.32)
    reg [63:0] temp_mul_2;  // pi * r^2 (32+48 = 80 bits, truncated to 64)
    reg [79:0] temp_mul_3;  // * angle (64+32 = 96 bits, truncated to 80)
    reg [31:0] result_reg;
    reg error_reg;
    reg [7:0] cycle_count;
    
    // Status flags
    reg angle_valid;
    reg overflow_flag;

    // Combinational outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            error <= 1'b0;
            r_reg <= 32'd0;
            ang_reg <= 32'd0;
            temp_mul_1 <= 48'd0;
            temp_mul_2 <= 64'd0;
            temp_mul_3 <= 80'd0;
            result_reg <= 32'd0;
            error_reg <= 1'b0;
            cycle_count <= 8'd0;
            angle_valid <= 1'b0;
            overflow_flag <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        r_reg <= radius;
                        ang_reg <= angle;
                    end
                end

                CHECK: begin
                    // Check if angle > 360.0
                    if (angle > MAX_ANGLE) begin
                        angle_valid <= 1'b0;
                    end else begin
                        angle_valid <= 1'b1;
                    end
                end

                SQ_R: begin
                    // r^2: 32-bit * 32-bit -> 48-bit
                    if (angle_valid) begin
                        temp_mul_1 <= r_reg[15:0] * r_reg[15:0];  // Q16.16 * Q16.16 = Q32.32
                    end
                end

                PI_MUL: begin
                    // pi * r^2: 32-bit * 48-bit -> 80-bit (keep 64 MSB)
                    if (angle_valid) begin
                        temp_mul_2 <= PI_Q16_16 * temp_mul_1[47:16];  // Shift for Q16.16
                    end
                end

                ANG_MUL: begin
                    // * angle: 64-bit * 32-bit -> 96-bit (keep 80 MSB)
                    if (angle_valid) begin
                        temp_mul_3 <= temp_mul_2[63:16] * ang_reg[15:0];
                    end
                end

                DIV_360: begin
                    // Divide by 360: multiply by reciprocal
                    // Shift back to Q16.16
                    if (angle_valid) begin
                        result_reg <= temp_mul_3[63:32] * DIV_RECIP;
                        // Check for overflow (shouldn't happen with valid angles)
                        overflow_flag <= (temp_mul_3[79:64] != 0);
                    end
                end

                SATURATE: begin
                    // Clamp result to valid range
                    if (angle_valid && !overflow_flag) begin
                        result <= result_reg;
                    end else begin
                        result <= 32'd0;
                    end
                    error_reg <= (!angle_valid || overflow_flag);
                end

                FINISH: begin
                    // Generate done/error pulses
                    if (angle_valid && !overflow_flag) begin
                        done <= 1'b1;
                        error <= 1'b0;
                    end else begin
                        done <= 1'b0;
                        error <= 1'b1;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end
            endcase
        end
    end

    // Next state logic with cycle counter to prevent infinite loops
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CHECK;
                else next_state = IDLE;
            end
            
            CHECK: begin
                if (angle_valid) next_state = SQ_R;
                else next_state = SATURATE;  // Invalid angle, skip computation
            end
            
            SQ_R: begin
                next_state = PI_MUL;
            end
            
            PI_MUL: begin
                next_state = ANG_MUL;
            end
            
            ANG_MUL: begin
                next_state = DIV_360;
            end
            
            DIV_360: begin
                next_state = SATURATE;
            end
            
            SATURATE: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                // Return to idle after 1 cycle
                if (cycle_count >= 8'd1) begin
                    next_state = IDLE;
                end else begin
                    next_state = FINISH;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule