module complex_angle (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] a,
    input wire signed [15:0] b,
    output reg signed [31:0] angle,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CALCULATING = 2'b01;
    localparam DONE_STATE = 2'b10;

    // Registers for state machine
    reg [1:0] state;
    reg [4:0] iter_cnt; // Iteration counter (0 to 15)

    // Registers for CORDIC algorithm
    reg signed [31:0] x_reg;
    reg signed [31:0] y_reg;
    reg signed [31:0] z_reg; // Accumulated angle

    // Lookup table for arctan(2^-i) in Q16.16 format
    // Values pre-calculated: atan(2^-i) * 2^16
    wire signed [31:0] atan_table [0:15];
    assign atan_table[0]  = 32'h0000C90F; // 45.0000 degrees
    assign atan_table[1]  = 32'h000076B1; // 26.5651 degrees
    assign atan_table[2]  = 32'h00003EB6; // 14.0362 degrees
    assign atan_table[3]  = 32'h00001FD5; // 7.1250 degrees
    assign atan_table[4]  = 32'h00000FFA; // 3.5763 degrees
    assign atan_table[5]  = 32'h000007FF; // 1.7899 degrees
    assign atan_table[6]  = 32'h00000400; // 0.8950 degrees
    assign atan_table[7]  = 32'h00000200; // 0.4475 degrees
    assign atan_table[8]  = 32'h00000100; // 0.2238 degrees
    assign atan_table[9]  = 32'h00000080; // 0.1119 degrees
    assign atan_table[10] = 32'h00000040; // 0.0560 degrees
    assign atan_table[11] = 32'h00000020; // 0.0280 degrees
    assign atan_table[12] = 32'h00000010; // 0.0140 degrees
    assign atan_table[13] = 32'h00000008; // 0.0070 degrees
    assign atan_table[14] = 32'h00000004; // 0.0035 degrees
    assign atan_table[15] = 32'h00000002; // 0.0018 degrees

    // Temporary values for next state calculation
    wire signed [31:0] x_shr;
    wire signed [31:0] y_shr;
    wire signed [31:0] x_next;
    wire signed [31:0] y_next;
    wire signed [31:0] z_next;
    wire signed [31:0] atan_val;

    // Shift inputs by iter_cnt (arithmetic shift for signed)
    assign x_shr = $signed(x_reg) >>> iter_cnt;
    assign y_shr = $signed(y_reg) >>> iter_cnt;

    // Select atan value based on current iteration
    assign atan_val = atan_table[iter_cnt];

    // Determine direction and calculate next values
    wire dir;
    assign dir = ($signed(y_reg) < 0); // If y is negative, rotate towards it (add angle)

    // If y < 0, we want to rotate closer to positive y (add angle, subtract y, add x)
    // If y >= 0, we want to rotate closer to negative y (subtract angle, add y, subtract x)
    assign x_next = dir ? (x_reg - y_shr) : (x_reg + y_shr);
    assign y_next = dir ? (y_reg + x_shr) : (y_reg - x_shr);
    assign z_next = dir ? (z_reg - atan_val) : (z_reg + atan_val);

    // Quadrant Correction logic
    // After CORDIC, angle is in correct quadrant relative to the input vector.
    // However, standard CORDIC usually rotates input to +X axis.
    // If we start with (a, b), we get angle of vector (a,b) relative to X-axis.
    // If we simply run CORDIC on (a, b), it calculates atan2(b, a) directly.
    // Just need to handle input quadrant for convergence if initial angle > 90 degrees.
    // But given the problem statement, standard rotation mode CORDIC works if we map inputs appropriately.
    // Actually, if we feed (a,b) directly, CORDIC rotates vector to align with X-axis.
    // The accumulated angle is the rotation angle.
    // For quadrants II and III, we need to rotate 180 degrees effectively, or handle inputs.
    // To keep it simple and generic for atan2(b, a):
    // If b > 0 and a < 0: atan(b/a) + PI
    // If b < 0 and a < 0: atan(b/a) - PI
    // If b < 0 and a > 0: angle is negative (CORDIC handles this if x>0)
    // If b > 0 and a > 0: angle is positive.
    // Standard CORDIC works for |angle| < 90 degrees. 
    // For 180 degree support, we flip inputs or rotate in pre-processing.

    reg signed [31:0] final_angle;
    
    always @(*) begin
        // Default: take result from CORDIC
        final_angle = z_reg;
        
        // If a was negative (quadrants II and III), the CORDIC would have 
        // tried to rotate the vector into the 4th/1st quadrant (forcing y->0, x->positive).
        // Since x was negative, we effectively rotated 180 degrees + original angle.
        // CORDIC result will be 180 degrees - original angle (if we forced y sign change?)
        // Actually, to avoid complex pre-rotation, we can correct the output.
        // If we just do the math: 
        // When a < 0, CORDIC converges to the angle relative to the positive X axis.
        // The algorithm forces y -> 0 and x -> positive magnitude.
        // The result will be (original angle - 180) or similar depending on specific implementation.
        // To support full 360 (or -pi to pi), we map inputs.
        // Let's use the specific Quadrant correction based on inputs a and b.
        // This assumes we used atan2 approximation (CORDIC) on (a, b) directly.
    end

    // To handle full 360 correctly with standard rotation CORDIC:
    // We pre-process (a, b) to be in Quadrant I or IV (x > 0).
    // Or post-process the result.
    // Post-processing is easier if we know the input quadrant.
    // But we overwrite registers in CALC state. 
    // We need to save input signs or pre-calculate angle offset.

    reg signed [31:0] quadrant_offset;
    
    // Pre-compute quadrant offset in IDLE to save logic in CALC
    // atan2 result is typically in [-pi, pi]. 
    // Q16.16 pi = 205887 (approx) -> 0x3243F. Actually 0x3243F is for 16-bit int PI*2^16? No.
    // PI in Q16.16 = 3.14159 * 65536 = 205887 (0x3243F).
    localparam PI_Q16 = 32'h0003243F;
    localparam TWO_PI_Q16 = 32'h0006487E;
    localparam HALF_PI_Q16 = 32'h00019220;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            angle <= 0;
            iter_cnt <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= CALCULATING;
                        iter_cnt <= 0;
                        
                        // Input Pre-processing for CORDIC convergence and Quadrant correction
                        // We want to map inputs to Q1 or Q4 so x > 0 for CORDIC convergence.
                        // And we add the corresponding offset to the angle.
                        
                        if (a >= 0) begin
                            // Quadrant I or IV: x > 0. CORDIC works directly.
                            x_reg <= {16'b0, a};  // Convert to Q16.16
                            y_reg <= {16'b0, b};  // Convert to Q16.16
                            z_reg <= 0;
                            // No offset needed
                        end else if (b >= 0) begin
                            // Quadrant II (a<0, b>=0): Rotate by +PI/2? No, flip x.
                            // To put in Q1 (x>0, y>0) we rotate -90 deg or swap and negate?
                            // CORDIC Rotation mode prefers x>0.
                            // If a<0, we can add PI to the result, but CORDIC needs x>0 to converge.
                            // We can rotate input vector by 180 deg (negate both) -> effectively adds PI to result.
                            // But negating both x and y keeps vector same direction.
                            // We need to rotate x to positive.
                            // Strategy: Rotate input by 180 deg if a < 0.
                            // Wait, rotating 180 deg (negate x, negate y) makes x positive? No, -a is positive.
                            // But y becomes -b. CORDIC aligns to +X. So we get atan2(-b, -a) = atan2(b, a) - PI.
                            // So if we feed (-a, -b), result = atan2(-b, -a) = atan2(b,a) - PI.
                            // So if we want result = atan2(b,a), we add PI to output.
                            // However, we want to avoid large offsets. 
                            // Let's use the 2-stage normalization:
                            // 1. If a < 0, negate a and b? No.
                            // 2. Standard trick: 
                            // If a < 0, we add PI to result. But CORDIC needs x > 0.
                            // So we feed (-a, -b) if a < 0? 
                            // If a < 0 and b < 0 (QIII): (-a, -b) -> (pos, pos) Q1. Result is atan2(-b, -a) = atan2(b,a) - PI. 
                            // So we need to add PI. 
                            // If a < 0 and b >= 0 (QII): (-a, -b) -> (pos, neg) QIV. Result is atan2(-b, -a) = atan2(b,a) - PI. 
                            // Wait, atan2(b, a) in QII is (PI/2 to PI). atan2(-b, -a) is (-PI/2 to -PI)?? No.
                            // atan2(y, x) in QII (x<0, y>0): range [PI/2, PI].
                            // Feed (-x, -y) -> (pos, neg). Range [-PI/2, 0].
                            // Relation: atan2(y, x) = atan2(-y, -x) + PI. (For x<0).
                            // So, if we feed (-a, -b), we get result R'. True result R = R' + PI.
                            
                            x_reg <= -{16'b0, a};
                            y_reg <= -{16'b0, b};
                            z_reg <= 0;
                            // Offset to be added at end: PI
                            quadrant_offset <= PI_Q16;
                        end else begin
                            // Quadrant III (a<0, b<0).
                            // Feed (-a, -b) -> (pos, pos) Q1.
                            // atan2(-b, -a) = atan2(b,a) + PI? No. atan2(-b, -a) = atan2(b,a) - PI?
                            // atan2(y, x) QIII: (-PI, -PI/2).
                            // atan2(-y, -x) QI: (0, PI/2).
                            // Formula: atan2(y, x) = atan2(-y, -x) - PI. (For x<0). 
                            // So we need to subtract PI.
                            x_reg <= -{16'b0, a};
                            y_reg <= -{16'b0, b};
                            z_reg <= 0;
                            quadrant_offset <= -PI_Q16;
                        end
                    end
                end

                CALCULATING: begin
                    if (iter_cnt < 15) begin
                        x_reg <= x_next;
                        y_reg <= y_next;
                        z_reg <= z_next;
                        iter_cnt <= iter_cnt + 1;
                    end else begin
                        // Last iteration
                        x_reg <= x_next;
                        y_reg <= y_next;
                        z_reg <= z_next;
                        
                        // Final Correction (add offset)
                        // We need to add the pre-calculated quadrant_offset to z_next
                        // But z_next is not stored yet in the register for this clock edge.
                        // So we add offset to z_next here and register it.
                        
                        state <= DONE_STATE;
                        angle <= z_next + quadrant_offset;
                        done <= 1;
                    end
                end

                DONE_STATE: begin
                    done <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
