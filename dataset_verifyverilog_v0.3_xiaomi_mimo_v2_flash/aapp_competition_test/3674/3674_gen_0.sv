module find_number_small(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] m,
    input wire [5:0] n,
    input wire [7:0] p,
    input wire [7:0] q,
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] SETUP_L    = 4'd1;
    localparam [3:0] SETUP_D    = 4'd2;
    localparam [3:0] SETUP_MIN  = 4'd3;
    localparam [3:0] SETUP_M    = 4'd4;
    localparam [3:0] SETUP_ITER = 4'd5;
    localparam [3:0] CALC_B     = 4'd6;
    localparam [3:0] CALC_N     = 4'd7;
    localparam [3:0] CHECK_N    = 4'd8;
    localparam [3:0] CALC_REM   = 4'd9;
    localparam [3:0] CHECK_REM  = 4'd10;
    localparam [3:0] STORE_SOL  = 4'd11;
    localparam [3:0] NEXT_ITER  = 4'd12;
    localparam [3:0] FINISH     = 4'd13;

    // Internal registers
    reg [3:0] state, next_state;
    reg [5:0] L_reg, L_next;              // m - n
    reg [5:0] d_reg, d_next;              // digits in p
    reg [31:0] min_N_reg, min_N_next;     // 10^(m-1)
    reg [31:0] max_N_reg, max_N_next;     // 10^m - 1
    reg [31:0] M_reg, M_next;             // 10^L
    reg [31:0] A_reg, A_next;             // Current A iteration
    reg [31:0] B_reg, B_next;             // A * 10^d + p
    reg [31:0] N_reg, N_next;             // q * B
    reg [31:0] rem_reg, rem_next;         // N % M
    reg [31:0] sol_reg, sol_next;         // Current smallest solution
    reg [5:0] cnt_reg, cnt_next;          // Loop counter
    reg found_reg, found_next;            // Solution found flag
    reg [1:0] power_state, power_state_next;  // For computing 10^k
    reg [5:0] power_exp, power_exp_next;  // Exponent for power computation
    reg [31:0] power_result, power_result_next;
    reg [5:0] digit_cnt, digit_cnt_next;  // For counting digits
    reg [31:0] temp_val, temp_val_next;   // Temporary for computation
    reg [31:0] modulo_temp, modulo_temp_next;
    reg [1:0] wait_cnt, wait_cnt_next;    // Wait counter for modulo

    // Output registers
    reg done_next, valid_next;
    reg [31:0] result_next;

    // Helper for 10^k (k=0 to 6)
    function [31:0] power_of_10;
        input [5:0] k;
        begin
            case (k)
                6'd0: power_of_10 = 32'd1;
                6'd1: power_of_10 = 32'd10;
                6'd2: power_of_10 = 32'd100;
                6'd3: power_of_10 = 32'd1000;
                6'd4: power_of_10 = 32'd10000;
                6'd5: power_of_10 = 32'd100000;
                6'd6: power_of_10 = 32'd1000000;
                default: power_of_10 = 32'd1;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            L_reg <= 6'd0;
            d_reg <= 6'd0;
            min_N_reg <= 32'd0;
            max_N_reg <= 32'd0;
            M_reg <= 32'd0;
            A_reg <= 32'd0;
            B_reg <= 32'd0;
            N_reg <= 32'd0;
            rem_reg <= 32'd0;
            sol_reg <= 32'd0;
            cnt_reg <= 6'd0;
            found_reg <= 1'b0;
            power_state <= 2'd0;
            power_exp <= 6'd0;
            power_result <= 32'd0;
            digit_cnt <= 6'd0;
            temp_val <= 32'd0;
            modulo_temp <= 32'd0;
            wait_cnt <= 2'd0;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 32'd0;
        end else begin
            state <= next_state;
            L_reg <= L_next;
            d_reg <= d_next;
            min_N_reg <= min_N_next;
            max_N_reg <= max_N_next;
            M_reg <= M_next;
            A_reg <= A_next;
            B_reg <= B_next;
            N_reg <= N_next;
            rem_reg <= rem_next;
            sol_reg <= sol_next;
            cnt_reg <= cnt_next;
            found_reg <= found_next;
            power_state <= power_state_next;
            power_exp <= power_exp_next;
            power_result <= power_result_next;
            digit_cnt <= digit_cnt_next;
            temp_val <= temp_val_next;
            modulo_temp <= modulo_temp_next;
            wait_cnt <= wait_cnt_next;
            done <= done_next;
            valid <= valid_next;
            result <= result_next;
        end
    end

    always @(*) begin
        // Default assignments
        next_state = state;
        L_next = L_reg;
        d_next = d_reg;
        min_N_next = min_N_reg;
        max_N_next = max_N_reg;
        M_next = M_reg;
        A_next = A_reg;
        B_next = B_reg;
        N_next = N_reg;
        rem_next = rem_reg;
        sol_next = sol_reg;
        cnt_next = cnt_reg;
        found_next = found_reg;
        power_state_next = power_state;
        power_exp_next = power_exp;
        power_result_next = power_result;
        digit_cnt_next = digit_cnt;
        temp_val_next = temp_val;
        modulo_temp_next = modulo_temp;
        wait_cnt_next = wait_cnt;
        done_next = 1'b0;
        valid_next = valid;
        result_next = result;

        case (state)
            IDLE: begin
                done_next = 1'b0;
                valid_next = 1'b0;
                result_next = 32'd0;
                if (start) begin
                    next_state = SETUP_L;
                end
            end

            SETUP_L: begin
                // L = m - n
                L_next = m - n;
                next_state = SETUP_D;
            end

            SETUP_D: begin
                // Count digits in p
                if (digit_cnt == 6'd0) begin
                    temp_val_next = {24'd0, p};
                    digit_cnt_next = 6'd1;
                end else if (digit_cnt <= 6'd3) begin
                    if (temp_val >= 32'd100) begin
                        d_next = 3'd3;
                        digit_cnt_next = 6'd0;
                        next_state = SETUP_MIN;
                    end else if (temp_val >= 32'd10) begin
                        d_next = 3'd2;
                        digit_cnt_next = 6'd0;
                        next_state = SETUP_MIN;
                    end else begin
                        d_next = 3'd1;
                        digit_cnt_next = 6'd0;
                        next_state = SETUP_MIN;
                    end
                end else begin
                    digit_cnt_next = 6'd0;
                    next_state = SETUP_MIN;
                end
            end

            SETUP_MIN: begin
                // Compute min_N = 10^(m-1)
                if (m == 6'd0) begin
                    min_N_next = 32'd1;
                    max_N_next = 32'd0;
                end else begin
                    min_N_next = power_of_10(m - 6'd1);
                    max_N_next = power_of_10(m) - 32'd1;
                end
                next_state = SETUP_M;
            end

            SETUP_M: begin
                // Compute M = 10^L
                M_next = power_of_10(L_reg);
                A_next = 32'd0;
                cnt_next = 6'd0;
                found_next = 1'b0;
                sol_next = 32'd0;
                next_state = SETUP_ITER;
            end

            SETUP_ITER: begin
                // Check if A >= M
                if (A_reg >= M_reg) begin
                    next_state = FINISH;
                end else begin
                    next_state = CALC_B;
                end
            end

            CALC_B: begin
                // B = A * 10^d + p
                B_next = (A_reg * power_of_10(d_reg)) + {24'd0, p};
                next_state = CALC_N;
            end

            CALC_N: begin
                // N = q * B
                N_next = {24'd0, q} * B_reg;
                next_state = CHECK_N;
            end

            CHECK_N: begin
                // Check if min_N <= N <= max_N
                if (N_reg >= min_N_reg && N_reg <= max_N_reg) begin
                    next_state = CALC_REM;
                end else begin
                    next_state = NEXT_ITER;
                end
            end

            CALC_REM: begin
                // Compute remainder = N % M (M=1 when L=0)
                if (L_reg == 6'd0) begin
                    rem_next = 32'd0;
                    next_state = CHECK_REM;
                end else begin
                    // Division algorithm
                    modulo_temp_next = N_reg;
                    cnt_next = 6'd0;
                    next_state = CHECK_REM;
                end
            end

            CHECK_REM: begin
                if (L_reg == 6'd0) begin
                    if (rem_reg == A_reg) begin
                        next_state = STORE_SOL;
                    end else begin
                        next_state = NEXT_ITER;
                    end
                end else begin
                    // Remainder calculation using repeated subtraction
                    if (modulo_temp >= M_reg) begin
                        modulo_temp_next = modulo_temp - M_reg;
                        cnt_next = cnt_reg + 6'd1;
                    end else begin
                        rem_next = modulo_temp;
                        if (rem_next == A_reg) begin
                            next_state = STORE_SOL;
                        end else begin
                            next_state = NEXT_ITER;
                        end
                    end
                end
            end

            STORE_SOL: begin
                // Store new solution
                sol_next = N_reg;
                found_next = 1'b1;
                next_state = NEXT_ITER;
            end

            NEXT_ITER: begin
                A_next = A_reg + 32'd1;
                next_state = SETUP_ITER;
            end

            FINISH: begin
                done_next = 1'b1;
                if (found_reg) begin
                    valid_next = 1'b1;
                    result_next = sol_reg;
                end else begin
                    valid_next = 1'b0;
                    result_next = 32'd0;
                end
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule