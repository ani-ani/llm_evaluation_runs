module archimedes_solver (
    input clk,
    input rst_n,
    input start,
    input [31:0] b_fixed,
    input [31:0] tx_fixed,
    input [31:0] ty_fixed,
    output reg [31:0] result_x,
    output reg [31:0] result_y,
    output reg done
);

    // Constants
    localparam [31:0] PI_FIXED = 32'h0000C90F; // 3.1415926535 in Q16.16
    localparam [31:0] TWO_PI_FIXED = 32'h0001921F; // 6.283185307 in Q16.16
    localparam [31:0] EIGHT_PI_FIXED = 32'h0003243E; // 25.132741228 in Q16.16
    localparam [31:0] STEP_FIXED = 32'h0000028F; // 0.01 in Q16.16 (655)
    localparam [31:0] THRESHOLD_FIXED = 32'h0000199A; // 0.1 in Q16.16 (6553)
    localparam [31:0] INTERSECT_MARGIN_FIXED = 32'h0000199A; // 0.1 in Q16.16

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        CALCULATE,
        CHECK_DIST,
        UPDATE,
        DONE
    } state_t;
    state_t state, next_state;

    // Internal registers
    reg [31:0] phi_fixed;
    reg [31:0] x_fixed;
    reg [31:0] y_fixed;
    reg [31:0] vx_fixed;
    reg [31:0] vy_fixed;
    reg [31:0] best_x_fixed;
    reg [31:0] best_y_fixed;
    reg [31:0] min_dist_fixed;
    reg [31:0] current_dist_fixed;
    reg [31:0] target_radius_fixed;
    reg [31:0] spiral_radius_fixed;
    reg [31:0] cos_phi_fixed;
    reg [31:0] sin_phi_fixed;
    reg [31:0] temp1_fixed;
    reg [31:0] temp2_fixed;
    reg [31:0] temp3_fixed;
    reg [31:0] temp4_fixed;
    reg [31:0] temp5_fixed;
    reg [31:0] temp6_fixed;
    reg [31:0] temp7_fixed;
    reg [31:0] temp8_fixed;
    reg [31:0] temp9_fixed;
    reg [31:0] temp10_fixed;
    reg [31:0] temp11_fixed;
    reg [31:0] temp12_fixed;
    reg [31:0] temp13_fixed;
    reg [31:0] temp14_fixed;
    reg [31:0] temp15_fixed;
    reg [31:0] temp16_fixed;
    reg [31:0] temp17_fixed;
    reg [31:0] temp18_fixed;
    reg [31:0] temp19_fixed;
    reg [31:0] temp20_fixed;
    reg [31:0] temp21_fixed;
    reg [31:0] temp22_fixed;
    reg [31:0] temp23_fixed;
    reg [31:0] temp24_fixed;
    reg [31:0] temp25_fixed;
    reg [31:0] temp26_fixed;
    reg [31:0] temp27_fixed;
    reg [31:0] temp28_fixed;
    reg [31:0] temp29_fixed;
    reg [31:0] temp30_fixed;
    reg [31:0] temp31_fixed;
    reg [31:0] temp32_fixed;
    reg [31:0] temp33_fixed;
    reg [31:0] temp34_fixed;
    reg [31:0] temp35_fixed;
    reg [31:0] temp36_fixed;
    reg [31:0] temp37_fixed;
    reg [31:0] temp38_fixed;
    reg [31:0] temp39_fixed;
    reg [31:0] temp40_fixed;
    reg [31:0] temp41_fixed;
    reg [31:0] temp42_fixed;
    reg [31:0] temp43_fixed;
    reg [31:0] temp44_fixed;
    reg [31:0] temp45_fixed;
    reg [31:0] temp46_fixed;
    reg [31:0] temp47_fixed;
    reg [31:0] temp48_fixed;
    reg [31:0] temp49_fixed;
    reg [31:0] temp50_fixed;
    reg [31:0] temp51_fixed;
    reg [31:0] temp52_fixed;
    reg [31:0] temp53_fixed;
    reg [31:0] temp54_fixed;
    reg [31:0] temp55_fixed;
    reg [31:0] temp56_fixed;
    reg [31:0] temp57_fixed;
    reg [31:0] temp58_fixed;
    reg [31:0] temp59_fixed;
    reg [31:0] temp60_fixed;
    reg [31:0] temp61_fixed;
    reg [31:0] temp62_fixed;
    reg [31:0] temp63_fixed;
    reg [31:0] temp64_fixed;
    reg [31:0] temp65_fixed;
    reg [31:0] temp66_fixed;
    reg [31:0] temp67_fixed;
    reg [31:0] temp68_fixed;
    reg [31:0] temp69_fixed;
    reg [31:0] temp70_fixed;
    reg [31:0] temp71_fixed;
    reg [31:0] temp72_fixed;
    reg [31:0] temp73_fixed;
    reg [31:0] temp74_fixed;
    reg [31:0] temp75_fixed;
    reg [31:0] temp76_fixed;
    reg [31:0] temp77_fixed;
    reg [31:0] temp78_fixed;
    reg [31:0] temp79_fixed;
    reg [31:0] temp80_fixed;
    reg [31:0] temp81_fixed;
    reg [31:0] temp82_fixed;
    reg [31:0] temp83_fixed;
    reg [31:0] temp84_fixed;
    reg [31:0] temp85_fixed;
    reg [31:0] temp86_fixed;
    reg [31:0] temp87_fixed;
    reg [31:0] temp88_fixed;
    reg [31:0] temp89_fixed;
    reg [31:0] temp90_fixed;
    reg [31:0] temp91_fixed;
    reg [31:0] temp92_fixed;
    reg [31:0] temp93_fixed;
    reg [31:0] temp94_fixed;
    reg [31:0] temp95_fixed;
    reg [31:0] temp96_fixed;
    reg [31:0] temp97_fixed;
    reg [31:0] temp98_fixed;
    reg [31:0] temp99_fixed;
    reg [31:0] temp100_fixed;

    // CORDIC constants
    localparam [31:0] CORDIC_ITERATIONS = 16;
    localparam [31:0] CORDIC_ANGLE_TABLE [0:15] = '{32'h0000791E, 32'h000045C0, 32'h000023B1, 32'h000011DA, 32'h000008ED, 32'h00000477, 32'h0000023B, 32'h0000011E, 32'h0000008F, 32'h00000047, 32'h00000024, 32'h00000012, 32'h00000009, 32'h00000004, 32'h00000002, 32'h00000001};

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALCULATE;
                end else begin
                    next_state = IDLE;
                end
            end
            CALCULATE: begin
                next_state = CHECK_DIST;
            end
            CHECK_DIST: begin
                next_state = UPDATE;
            end
            UPDATE: begin
                if (phi_fixed >= EIGHT_PI_FIXED) begin
                    next_state = DONE;
                end else begin
                    next_state = CALCULATE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phi_fixed <= 0;
            x_fixed <= 0;
            y_fixed <= 0;
            vx_fixed <= 0;
            vy_fixed <= 0;
            best_x_fixed <= 0;
            best_y_fixed <= 0;
            min_dist_fixed <= 32'h7FFFFFFF;
            current_dist_fixed <= 0;
            target_radius_fixed <= 0;
            spiral_radius_fixed <= 0;
            cos_phi_fixed <= 0;
            sin_phi_fixed <= 0;
            done <= 0;
            result_x <= 0;
            result_y <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        phi_fixed <= 0;
                        min_dist_fixed <= 32'h7FFFFFFF;
                        done <= 0;
                    end
                end
                CALCULATE: begin
                    // Compute cos(phi) and sin(phi) using CORDIC
                    temp1_fixed = phi_fixed;
                    temp2_fixed = 32'h00008000; // 1.0 in Q16.16
                    temp3_fixed = 0;
                    for (int i = 0; i < CORDIC_ITERATIONS; i = i + 1) begin
                        if (temp1_fixed[31]) begin
                            temp4_fixed = temp2_fixed + (temp3_fixed >>> i);
                            temp5_fixed = temp3_fixed - (temp2_fixed >>> i);
                            temp1_fixed = temp1_fixed + CORDIC_ANGLE_TABLE[i];
                        end else begin
                            temp4_fixed = temp2_fixed - (temp3_fixed >>> i);
                            temp5_fixed = temp3_fixed + (temp2_fixed >>> i);
                            temp1_fixed = temp1_fixed - CORDIC_ANGLE_TABLE[i];
                        end
                        temp2_fixed = temp4_fixed;
                        temp3_fixed = temp5_fixed;
                    end
                    cos_phi_fixed = temp2_fixed;
                    sin_phi_fixed = temp3_fixed;

                    // Compute x = b * phi * cos(phi)
                    temp6_fixed = $signed(b_fixed) * $signed(phi_fixed);
                    temp7_fixed = temp6_fixed[47:16]; // Keep upper 32 bits
                    temp8_fixed = $signed(temp7_fixed) * $signed(cos_phi_fixed);
                    x_fixed = temp8_fixed[47:16];

                    // Compute y = b * phi * sin(phi)
                    temp9_fixed = $signed(b_fixed) * $signed(phi_fixed);
                    temp10_fixed = temp9_fixed[47:16];
                    temp11_fixed = $signed(temp10_fixed) * $signed(sin_phi_fixed);
                    y_fixed = temp11_fixed[47:16];

                    // Compute vx = b * (cos(phi) - phi * sin(phi))
                    temp12_fixed = $signed(phi_fixed) * $signed(sin_phi_fixed);
                    temp13_fixed = temp12_fixed[47:16];
                    temp14_fixed = cos_phi_fixed - temp13_fixed;
                    temp15_fixed = $signed(b_fixed) * $signed(temp14_fixed);
                    vx_fixed = temp15_fixed[47:16];

                    // Compute vy = b * (sin(phi) + phi * cos(phi))
                    temp16_fixed = $signed(phi_fixed) * $signed(cos_phi_fixed);
                    temp17_fixed = temp16_fixed[47:16];
                    temp18_fixed = sin_phi_fixed + temp17_fixed;
                    temp19_fixed = $signed(b_fixed) * $signed(temp18_fixed);
                    vy_fixed = temp19_fixed[47:16];

                    // Compute target radius
                    temp20_fixed = $signed(tx_fixed) * $signed(tx_fixed);
                    temp21_fixed = $signed(ty_fixed) * $signed(ty_fixed);
                    temp22_fixed = temp20_fixed + temp21_fixed;
                    // Approximate sqrt using Newton-Raphson (simplified)
                    temp23_fixed = 32'h00008000; // Initial guess 1.0
                    temp24_fixed = $signed(temp22_fixed) * $signed(temp23_fixed);
                    temp25_fixed = temp24_fixed[47:16];
                    temp26_fixed = temp25_fixed + temp23_fixed;
                    temp27_fixed = temp26_fixed >>> 1;
                    temp28_fixed = $signed(temp22_fixed) / $signed(temp27_fixed);
                    temp29_fixed = temp27_fixed + temp28_fixed;
                    target_radius_fixed = temp29_fixed >>> 1;

                    // Compute spiral radius
                    temp30_fixed = $signed(b_fixed) * $signed(phi_fixed);
                    spiral_radius_fixed = temp30_fixed[47:16];
                end
                CHECK_DIST: begin
                    // Check if target is outside spiral radius + margin
                    temp31_fixed = spiral_radius_fixed + INTERSECT_MARGIN_FIXED;
                    if (target_radius_fixed > temp31_fixed) begin
                        // Compute distance from target to line (x,y) in direction (vx,vy)
                        // Line equation: (tx - x)*vy - (ty - y)*vx = 0
                        // Distance = |(tx - x)*vy - (ty - y)*vx| / sqrt(vx^2 + vy^2)
                        temp32_fixed = tx_fixed - x_fixed;
                        temp33_fixed = ty_fixed - y_fixed;
                        temp34_fixed = $signed(temp32_fixed) * $signed(vy_fixed);
                        temp35_fixed = $signed(temp33_fixed) * $signed(vx_fixed);
                        temp36_fixed = temp34_fixed - temp35_fixed;
                        temp37_fixed = $signed(temp36_fixed) * $signed(temp36_fixed);

                        // Compute denominator sqrt(vx^2 + vy^2)
                        temp38_fixed = $signed(vx_fixed) * $signed(vx_fixed);
                        temp39_fixed = $signed(vy_fixed) * $signed(vy_fixed);
                        temp40_fixed = temp38_fixed + temp39_fixed;
                        temp41_fixed = 32'h00008000; // Initial guess 1.0
                        temp42_fixed = $signed(temp40_fixed) * $signed(temp41_fixed);
                        temp43_fixed = temp42_fixed[47:16];
                        temp44_fixed = temp43_fixed + temp41_fixed;
                        temp45_fixed = temp44_fixed >>> 1;
                        temp46_fixed = $signed(temp40_fixed) / $signed(temp45_fixed);
                        temp47_fixed = temp45_fixed + temp46_fixed;
                        temp48_fixed = temp47_fixed >>> 1;

                        // Compute distance
                        if (temp48_fixed != 0) begin
                            temp49_fixed = $signed(temp37_fixed) / $signed(temp48_fixed);
                            current_dist_fixed = temp49_fixed[47:16];
                        end else begin
                            current_dist_fixed = 32'h7FFFFFFF;
                        end
                    end else begin
                        current_dist_fixed = 32'h7FFFFFFF;
                    end
                end
                UPDATE: begin
                    // Check if current distance is better
                    if (current_dist_fixed < min_dist_fixed && current_dist_fixed < THRESHOLD_FIXED) begin
                        min_dist_fixed = current_dist_fixed;
                        best_x_fixed = x_fixed;
                        best_y_fixed = y_fixed;
                    end
                    // Increment phi
                    phi_fixed = phi_fixed + STEP_FIXED;
                end
                DONE: begin
                    result_x = best_x_fixed;
                    result_y = best_y_fixed;
                    done = 1;
                end
                default: begin
                end
            endcase
        end
    end

endmodule