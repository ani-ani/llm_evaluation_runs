module complex_angle_calculator(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] a,
    input signed [15:0] b,
    output reg [31:0] angle,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK_Z   = 3'd1;
    localparam [2:0] NORMALIZE = 3'd2;
    localparam [2:0] ITERATE   = 3'd3;
    localparam [2:0] ADJUST    = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Quadrant constants (Q16.16)
    localparam [31:0] PI_HALF = 32'h00019220; // π/2 ≈ 1.5708 * 2^16
    localparam [31:0] PI      = 32'h00032440; // π ≈ 3.1416 * 2^16
    localparam [31:0] PI_HALF_NEG = 32'hFFE66DE0; // -π/2 in 32-bit two's complement

    // CORDIC angles (arctan(2^-i) * 2^16 for i=0 to 14)
    // Stored as Q16.16
    wire signed [31:0] atan_table [0:14];
    assign atan_table[0]  = 32'h0000C90F; // arctan(1)    * 2^16
    assign atan_table[1]  = 32'h000076B0; // arctan(0.5)  * 2^16
    assign atan_table[2]  = 32'h00003EB7; // arctan(0.25) * 2^16
    assign atan_table[3]  = 32'h00001FD6; // arctan(0.125)* 2^16
    assign atan_table[4]  = 32'h00000FFB; // arctan(0.0625)* 2^16
    assign atan_table[5]  = 32'h000007FF; // arctan(0.03125)* 2^16
    assign atan_table[6]  = 32'h00000400; // arctan(0.015625)* 2^16
    assign atan_table[7]  = 32'h00000200; // arctan(0.0078125)* 2^16
    assign atan_table[8]  = 32'h00000100; // arctan(0.00390625)* 2^16
    assign atan_table[9]  = 32'h00000080; // arctan(0.001953125)* 2^16
    assign atan_table[10] = 32'h00000040; // arctan(0.0009765625)* 2^16
    assign atan_table[11] = 32'h00000020;
    assign atan_table[12] = 32'h00000010;
    assign atan_table[13] = 32'h00000008;
    assign atan_table[14] = 32'h00000004;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] count;
    reg [15:0] x, y; // Q8.8 (normalized to 0.5-1.0 or 1.0-2.0)
    reg signed [31:0] z; // Q16.16 accumulation
    reg [1:0] quadrant; // 0:1, 1:2, 2:3, 3:4
    reg x_sign, y_sign;

    // Temporary wires for next state logic
    reg [15:0] next_x, next_y;
    reg [31:0] next_z;
    reg [15:0] next_count;

    // Next state logic (combinational)
    always @(*) begin
        next_state = state;
        next_x = x;
        next_y = y;
        next_z = z;
        next_count = count;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_Z;
                end
            end

            CHECK_Z: begin
                // Check for division by zero or quadrant
                if (a == 16'sd0 && b == 16'sd0) begin
                    next_state = FINISH;
                end else begin
                    next_state = NORMALIZE;
                end
            end

            NORMALIZE: begin
                // Normalize vector to magnitude 1
                // Simple scaling based on MSB (CORDIC requires ~0.5-2.0 range)
                // For Q8.8, max value is 255.996
                // We ensure |x| < 1.0 by shifting right if needed
                next_x = (a[15] ? -a : a);
                next_y = (b[15] ? -b : b);
                next_z = 32'd0;
                next_count = 16'd0;
                next_state = ITERATE;
            end

            ITERATE: begin
                if (count < 16'd15) begin
                    // CORDIC iteration (rotation mode - finds angle)
                    // d = -sign(y * x_next) = sign(y) (for target angle accumulation)
                    // Actually for atan2(y,x), we want to rotate so y goes to 0
                    // Rotation angle = arctan(2^-i)
                    // If y > 0, rotate clockwise (negative angle)
                    // If y < 0, rotate counter-clockwise (positive angle)
                    // x_new = x - d * (y >> i)
                    // y_new = y + d * (x >> i)
                    // z_new = z + d * atan_table[i]
                    
                    if (y[15]) begin // y < 0, rotate CCW
                        next_x = x + (y >>> count[3:0]);
                        next_y = y - (x >>> count[3:0]);
                        next_z = z - atan_table[count[3:0]];
                    end else begin // y >= 0, rotate CW
                        next_x = x - (y >>> count[3:0]);
                        next_y = y + (x >>> count[3:0]);
                        next_z = z + atan_table[count[3:0]];
                    end
                    
                    next_count = count + 16'd1;
                end else begin
                    next_state = ADJUST;
                end
            end

            ADJUST: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            angle <= 32'd0;
            done <= 1'b0;
            x <= 16'd0;
            y <= 16'd0;
            z <= 32'd0;
            count <= 16'd0;
            quadrant <= 2'd0;
        end else begin
            state <= next_state;
            count <= next_count;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    angle <= 32'd0;
                    if (start) begin
                        // Determine quadrant (for range adjustment)
                        if (a >= 0 && b >= 0) quadrant <= 2'd0; // Q1
                        else if (a < 0 && b >= 0) quadrant <= 2'd1; // Q2
                        else if (a < 0 && b < 0) quadrant <= 2'd2; // Q3
                        else quadrant <= 2'd3; // Q4
                    end
                end

                CHECK_Z: begin
                    if (a == 16'sd0 && b == 16'sd0) begin
                        angle <= 32'd0; // Undefined -> 0
                    end
                end

                NORMALIZE: begin
                    x <= next_x;
                    y <= next_y;
                    z <= next_z;
                end

                ITERATE: begin
                    x <= next_x;
                    y <= next_y;
                    z <= next_z;
                end

                ADJUST: begin
                    // Convert CORDIC output to correct quadrant
                    // CORDIC computes atan(y/x) where x,y are positive
                    // z is Q16.16 in range [-1.57, 1.57]
                    case (quadrant)
                        2'd0: begin // Q1: angle = z
                            if (z > PI_HALF) angle <= PI_HALF;
                            else if (z < -PI_HALF) angle <= PI_HALF_NEG;
                            else angle <= z;
                        end
                        2'd1: begin // Q2: angle = PI - z (approx, actually PI + z for signed)
                            // z is negative here (since we rotated with neg y)
                            // Angle should be PI + z (where z is negative)
                            // Result range [PI/2, PI]
                            // Add PI
                            angle <= PI + z;
                        end
                        2'd2: begin // Q3: angle = -PI + z
                            // z is positive here
                            // Result range [-PI, -PI/2]
                            // Subtract PI
                            angle <= 32'hFFFCDBB8 + z; // -PI in 32-bit
                        end
                        2'd3: begin // Q4: angle = -z
                            // z is negative here
                            // Result range [-PI/2, 0]
                            // Negate z
                            if (z[31]) begin // if z negative, make positive
                                angle <= {~z[31:0] + 32'd1};
                            end else begin
                                angle <= {~z[31:0] + 32'd1};
                            end
                        end
                        default: angle <= z;
                    endcase
                end

                FINISH: begin
                    done <= 1'b1;
                end

                default: begin
                    // Do nothing
                end
            endcase
        end
    end

endmodule