module digit_length_pairs(
    input clk,
    input rst_n,
    input start,
    input [31:0] S_in,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MOD = 32'd1000000007;
    localparam [31:0] POW10 [0:8] = '{32'd1, 32'd10, 32'd100, 32'd1000, 32'd10000, 32'd100000, 32'd1000000, 32'd10000000, 32'd100000000};
    localparam [31:0] DIGIT_SUM [1:9] = '{32'd9, 32'd180, 32'd2700, 32'd36000, 32'd450000, 32'd5400000, 32'd63000000, 32'd720000000, 32'd810000000};

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_L_R = 3'd1;
    localparam [2:0] SOLVE_LR = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] L, R;
    reg [31:0] mid_sum, Target, x, y, gcd_val, temp, total_count;
    reg [31:0] x_min, x_max, y_val, step;
    reg [31:0] cycle_count;
    reg [31:0] pow10_L, pow10_R;
    reg [31:0] max_x, max_y;
    reg [31:0] x_sol, y_sol;
    reg [31:0] gcd_LR;
    reg [31:0] inv_R, inv_gcd;
    reg [31:0] x0, y0;
    reg [31:0] x_temp, y_temp;
    reg [31:0] count_sol;
    reg [31:0] i, j;
    reg [31:0] S;
    reg [31:0] L_val, R_val;
    reg [31:0] mid_sum_val;
    reg [31:0] Target_val;
    reg [31:0] x_val, y_val_reg;
    reg [31:0] gcd_val_reg;
    reg [31:0] x_min_reg, x_max_reg;
    reg [31:0] step_reg;
    reg [31:0] count_sol_reg;
    reg [31:0] total_count_reg;
    reg [31:0] pow10_L_reg, pow10_R_reg;
    reg [31:0] max_x_reg, max_y_reg;
    reg [31:0] x_sol_reg, y_sol_reg;
    reg [31:0] gcd_LR_reg;
    reg [31:0] inv_R_reg, inv_gcd_reg;
    reg [31:0] x0_reg, y0_reg;
    reg [31:0] x_temp_reg, y_temp_reg;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 32'd0;
            L <= 4'd0;
            R <= 4'd0;
            mid_sum <= 32'd0;
            Target <= 32'd0;
            x <= 32'd0;
            y <= 32'd0;
            gcd_val <= 32'd0;
            temp <= 32'd0;
            total_count <= 32'd0;
            x_min <= 32'd0;
            x_max <= 32'd0;
            y_val <= 32'd0;
            step <= 32'd0;
            pow10_L <= 32'd0;
            pow10_R <= 32'd0;
            max_x <= 32'd0;
            max_y <= 32'd0;
            x_sol <= 32'd0;
            y_sol <= 32'd0;
            gcd_LR <= 32'd0;
            inv_R <= 32'd0;
            inv_gcd <= 32'd0;
            x0 <= 32'd0;
            y0 <= 32'd0;
            x_temp <= 32'd0;
            y_temp <= 32'd0;
            count_sol <= 32'd0;
            i <= 32'd0;
            j <= 32'd0;
            S <= 32'd0;
            L_val <= 32'd0;
            R_val <= 32'd0;
            mid_sum_val <= 32'd0;
            Target_val <= 32'd0;
            x_val <= 32'd0;
            y_val_reg <= 32'd0;
            gcd_val_reg <= 32'd0;
            x_min_reg <= 32'd0;
            x_max_reg <= 32'd0;
            step_reg <= 32'd0;
            count_sol_reg <= 32'd0;
            total_count_reg <= 32'd0;
            pow10_L_reg <= 32'd0;
            pow10_R_reg <= 32'd0;
            max_x_reg <= 32'd0;
            max_y_reg <= 32'd0;
            x_sol_reg <= 32'd0;
            y_sol_reg <= 32'd0;
            gcd_LR_reg <= 32'd0;
            inv_R_reg <= 32'd0;
            inv_gcd_reg <= 32'd0;
            x0_reg <= 32'd0;
            y0_reg <= 32'd0;
            x_temp_reg <= 32'd0;
            y_temp_reg <= 32'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        S <= S_in;
                        total_count <= 32'd0;
                        L <= 4'd1;
                        R <= 4'd0;
                        next_state <= CALC_L_R;
                    end
                end
                CALC_L_R: begin
                    if (L > 4'd9) begin
                        next_state <= FINISH;
                    end else begin
                        if (R < L) begin
                            R <= R + 4'd1;
                        end else if (R > 4'd9) begin
                            L <= L + 4'd1;
                            R <= 4'd0;
                        end else begin
                            // Calculate mid_sum
                            mid_sum_val <= 32'd0;
                            if (L < R) begin
                                for (i = L + 4'd1; i < R; i = i + 4'd1) begin
                                    mid_sum_val <= mid_sum_val + DIGIT_SUM[i];
                                end
                            end
                            Target_val <= S - mid_sum_val;
                            if (Target_val < 32'd0) begin
                                R <= R + 4'd1;
                            end else begin
                                L_val <= L;
                                R_val <= R;
                                mid_sum <= mid_sum_val;
                                Target <= Target_val;
                                next_state <= SOLVE_LR;
                            end
                        end
                    end
                end
                SOLVE_LR: begin
                    if (L_val == R_val) begin
                        // Case L == R
                        if (Target % L_val == 32'd0) begin
                            x_val <= Target / L_val;
                            max_x_reg <= 9 * POW10[L_val - 4'd1];
                            if (x_val >= 32'd1 && x_val <= max_x_reg) begin
                                total_count <= total_count + 32'd1;
                            end
                        end
                        R <= R + 4'd1;
                        next_state <= CALC_L_R;
                    end else begin
                        // Case L < R
                        // Compute GCD of L_val and R_val
                        x_temp_reg <= L_val;
                        y_temp_reg <= R_val;
                        while (y_temp_reg != 32'd0) begin
                            temp <= y_temp_reg;
                            y_temp_reg <= x_temp_reg % y_temp_reg;
                            x_temp_reg <= temp;
                        end
                        gcd_LR_reg <= x_temp_reg;
                        if (Target % gcd_LR_reg != 32'd0) begin
                            R <= R + 4'd1;
                            next_state <= CALC_L_R;
                        end else begin
                            // Solve L_val * x + R_val * y = Target
                            // Find particular solution
                            x0_reg <= 32'd0;
                            y0_reg <= 32'd0;
                            x_temp_reg <= L_val;
                            y_temp_reg <= R_val;
                            while (y_temp_reg != 32'd0) begin
                                temp <= y_temp_reg;
                                y_temp_reg <= x_temp_reg % y_temp_reg;
                                x_temp_reg <= temp;
                            end
                            // Extended Euclidean algorithm
                            x_temp_reg <= 32'd1;
                            y_temp_reg <= 32'd0;
                            x0_reg <= 32'd0;
                            y0_reg <= 32'd1;
                            temp <= L_val;
                            while (temp != 32'd0) begin
                                temp <= temp - (R_val / temp) * temp;
                                x_temp_reg <= x_temp_reg - (R_val / temp) * x0_reg;
                                y_temp_reg <= y_temp_reg - (R_val / temp) * y0_reg;
                            end
                            x0_reg <= x_temp_reg;
                            y0_reg <= y_temp_reg;
                            // Scale by Target / gcd
                            x0_reg <= x0_reg * (Target / gcd_LR_reg);
                            y0_reg <= y0_reg * (Target / gcd_LR_reg);
                            // General solution: x = x0 + k * (R_val / gcd), y = y0 - k * (L_val / gcd)
                            step_reg <= R_val / gcd_LR_reg;
                            // Find x in [1, 9*10^(L_val-1)] and y >= 1
                            max_x_reg <= 9 * POW10[L_val - 4'd1];
                            max_y_reg <= 9 * POW10[R_val - 4'd1];
                            x_min_reg <= 32'd1;
                            x_max_reg <= max_x_reg;
                            // Find smallest x >= x_min
                            x_sol_reg <= x0_reg;
                            while (x_sol_reg < x_min_reg) begin
                                x_sol_reg <= x_sol_reg + step_reg;
                            end
                            // Check if x_sol <= x_max and y = (Target - L_val * x_sol) / R_val >= 1 and <= max_y
                            y_sol_reg <= (Target - L_val * x_sol_reg) / R_val;
                            if (x_sol_reg <= x_max_reg && y_sol_reg >= 32'd1 && y_sol_reg <= max_y_reg) begin
                                count_sol_reg <= (x_max_reg - x_sol_reg) / step_reg + 32'd1;
                                total_count <= total_count + count_sol_reg;
                            end
                            R <= R + 4'd1;
                            next_state <= CALC_L_R;
                        end
                    end
                end
                FINISH: begin
                    result <= total_count % MOD;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule