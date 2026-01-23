module PoolShark (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] data_in,
    input wire [1:0] data_valid,
    output reg [15:0] d_out,
    output reg [15:0] theta_out,
    output reg done,
    output reg impossible
);

    // State definitions
    localparam [5:0] S_IDLE = 0;
    localparam [5:0] S_LOAD = 1;
    localparam [5:0] S_CALC_P3 = 2;
    localparam [5:0] S_CALC_BT = 3;
    localparam [5:0] S_CALC_P2 = 4;
    localparam [5:0] S_LOOP_D = 5;
    localparam [5:0] S_CHECK_HIT = 6;
    localparam [5:0] S_CALC_REFLECT = 7;
    localparam [5:0] S_CHECK_B2 = 8;
    localparam [5:0] S_FOUND = 9;
    localparam [5:0] S_IMPOSSIBLE = 10;

    reg [5:0] state;
    reg [4:0] input_cnt;
    reg [4:0] d_cnt;

    // Storage registers (Q16.16)
    reg signed [31:0] w_reg, l_reg, r_reg, h_reg;
    reg signed [31:0] x1, y1, x2, y2, x3, y3;

    // Intermediate calculation registers
    reg signed [31:0] in_A, in_B;
    wire signed [63:0] mul_out = in_A * in_B;

    // Geometry points
    reg signed [31:0] P3_x, P3_y; // P_contact_3
    reg signed [31:0] B_cue_x, B_cue_y; // B_cue_target
    reg signed [31:0] P2_x, P2_y; // P_contact_2

    // Current d and start position
    reg signed [31:0] d_val; // d in Q16.16
    reg signed [31:0] start_x, start_y;

    // Vectors
    reg signed [31:0] vec_start_x, vec_start_y; // B_cue - Start
    reg signed [31:0] vec_B_x, vec_B_y; // B_cue - B1
    reg signed [31:0] vec_target_x, vec_target_y; // P2 - B_cue

    // Reflection components
    reg signed [31:0] dot_VN;
    reg signed [31:0] V_new_x, V_new_y;

    // Rounding and output
    reg signed [31:0] raw_d, raw_theta;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            input_cnt <= 0;
            d_cnt <= 0;
            done <= 0;
            impossible <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    impossible <= 0;
                    if (start) begin
                        state <= S_LOAD;
                        input_cnt <= 0;
                    end
                end

                S_LOAD: begin
                    if (data_valid[0]) begin
                        case (input_cnt)
                            0: w_reg <= {16'h0, data_in};
                            1: l_reg <= {16'h0, data_in};
                            2: r_reg <= {16'h0, data_in};
                            3: x1 <= {16'h0, data_in};
                            4: y1 <= {16'h0, data_in};
                            5: x2 <= {16'h0, data_in};
                            6: y2 <= {16'h0, data_in};
                            7: x3 <= {16'h0, data_in};
                            8: y3 <= {16'h0, data_in};
                            9: h_reg <= {16'h0, data_in};
                        endcase
                        input_cnt <= input_cnt + 1;
                    end
                    if (input_cnt == 10 && data_valid[0]) begin
                        state <= S_CALC_P3;
                    end
                end

                S_CALC_P3: begin
                    // Compute Vec1 = (w - x1, l - y1)
                    in_A <= w_reg - x1;
                    in_B <= w_reg - x1;
                    state <= S_CALC_P3 + 1;
                end

                S_CALC_P3 + 1: begin
                    // Store Vec1x^2
                    vec_start_x <= mul_out[47:16];
                    in_A <= l_reg - y1;
                    in_B <= l_reg - y1;
                    state <= S_CALC_P3 + 2;
                end

                S_CALC_P3 + 2: begin
                    // Store Vec1y^2
                    vec_start_y <= mul_out[47:16];
                    // Sum for length squared
                    in_A <= vec_start_x + vec_start_y;
                    in_B <= 32'h00010000; // 1.0
                    state <= S_CALC_P3 + 3;
                end

                S_CALC_P3 + 3: begin
                    // Approximate sqrt using multiplier (simplified)
                    // Assume we have a sqrt unit or use iterative method
                    // For now, use a placeholder
                    vec_B_x <= in_A; // Placeholder for sqrt
                    // Compute P3 = B3 - 2r * Vec1 / sqrt
                    // We'll approximate division as well
                    in_A <= x3 - x1;
                    in_B <= y3 - y1;
                    state <= S_CALC_BT;
                end

                S_CALC_BT: begin
                    // Compute B_cue_target
                    // Placeholder for calculation
                    B_cue_x <= x1 - r_reg;
                    B_cue_y <= y1;
                    state <= S_CALC_P2;
                end

                S_CALC_P2: begin
                    // Compute P_contact_2
                    // Placeholder
                    P2_x <= x2 - r_reg;
                    P2_y <= y2;
                    state <= S_LOOP_D;
                    d_cnt <= 0;
                end

                S_LOOP_D: begin
                    // Iterate d from r to w-r
                    d_val <= r_reg + (d_cnt << 8); // d in Q16.16
                    start_x <= d_val;
                    start_y <= h_reg;
                    state <= S_CHECK_HIT;
                end

                S_CHECK_HIT: begin
                    // Check if Start->B_cue is valid
                    vec_start_x <= B_cue_x - start_x;
                    vec_start_y <= B_cue_y - start_y;
                    vec_B_x <= B_cue_x - x1;
                    vec_B_y <= B_cue_y - y1;
                    // Check dot product < 0
                    in_A <= vec_start_x * vec_B_x + vec_start_y * vec_B_y;
                    if (in_A < 0) begin
                        state <= S_CALC_REFLECT;
                    end else begin
                        d_cnt <= d_cnt + 1;
                        if (d_cnt > 1200) begin
                            state <= S_IMPOSSIBLE;
                        end else begin
                            state <= S_LOOP_D;
                        end
                    end
                end

                S_CALC_REFLECT: begin
                    // Compute reflection
                    dot_VN <= vec_start_x * vec_B_x + vec_start_y * vec_B_y;
                    V_new_x <= 2 * dot_VN * vec_B_x - vec_start_x * (vec_B_x * vec_B_x + vec_B_y * vec_B_y);
                    V_new_y <= 2 * dot_VN * vec_B_y - vec_start_y * (vec_B_x * vec_B_x + vec_B_y * vec_B_y);
                    state <= S_CHECK_B2;
                end

                S_CHECK_B2: begin
                    // Check if V_new points to P2
                    vec_target_x <= P2_x - B_cue_x;
                    vec_target_y <= P2_y - B_cue_y;
                    // Check cross product == 0 and dot > 0
                    in_A <= V_new_x * vec_target_y - V_new_y * vec_target_x;
                    in_B <= V_new_x * vec_target_x + V_new_y * vec_target_y;
                    if (in_A == 0 && in_B > 0) begin
                        state <= S_FOUND;
                    end else begin
                        d_cnt <= d_cnt + 1;
                        if (d_cnt > 1200) begin
                            state <= S_IMPOSSIBLE;
                        end else begin
                            state <= S_LOOP_D;
                        end
                    end
                end

                S_FOUND: begin
                    // Calculate theta
                    raw_theta <= 32'h00000000; // Placeholder
                    // Round d and theta
                    d_out <= d_val[31:16];
                    theta_out <= raw_theta[31:16];
                    done <= 1;
                    state <= S_IDLE;
                end

                S_IMPOSSIBLE: begin
                    impossible <= 1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule