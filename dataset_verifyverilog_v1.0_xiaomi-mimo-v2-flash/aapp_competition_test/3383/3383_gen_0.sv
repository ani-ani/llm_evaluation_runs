module ice_cream_optimization (
    input clk,
    input rst_n,
    input start,
    input [29:0] n,
    input [6:0] k,
    input [7:0] a,
    input [7:0] b,
    input [6:0][15:0] t,
    input [6:0][6:0][15:0] u,
    output reg [47:0] result,
    output reg done,
    output reg valid
);

    // Parameters for saturation
    localparam [47:0] MAX_Q24_24 = 48'h7FFFFFFFFFFF;
    localparam [47:0] MIN_Q24_24 = 48'h800000000000;
    localparam [31:0] MAX_32 = 32'h7FFFFFFF;
    localparam [31:0] MIN_32 = 32'h80000000;

    // Q8.8 to Q24.24 conversion constant
    localparam [23:0] CONV_SHIFT = 24'd16;
    localparam [23:0] MAX_ITER = 24'd100;

    // State declarations
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] INIT_MATRIX   = 4'd1;
    localparam [3:0] FLOYD_WARSHALL = 4'd2;
    localparam [3:0] EXP_INIT      = 4'd3;
    localparam [3:0] EXP_LOOP      = 4'd4;
    localparam [3:0] EXP_MULT      = 4'd5;
    localparam [3:0] CALC_COST     = 4'd6;
    localparam [3:0] DIV_START     = 4'd7;
    localparam [3:0] DIV_LOOP      = 4'd8;
    localparam [3:0] FINISH        = 4'd9;

    reg [3:0] state, next_state;
    reg [29:0] n_reg;
    reg [6:0] k_reg;
    reg [7:0] a_reg, b_reg;
    reg [31:0] cost_reg;
    reg [29:0] n_copy;
    reg [23:0] iter_counter;
    reg [7:0] fw_counter, fw_i, fw_j, fw_k;
    reg [7:0] exp_counter;
    reg [6:0] row_idx, col_idx;
    reg [6:0] temp_idx;
    reg sign_flag;

    // Max-plus matrices (100x100 max, flattened to 1D array for synthesis)
    // We'll use 2D arrays internally but flatten for storage
    reg signed [31:0] M_base [0:99] [0:99];  // Q24.24
    reg signed [31:0] M_result [0:99] [0:99]; // Q24.24
    reg signed [31:0] M_pow [0:99] [0:99];    // Q24.24
    reg signed [31:0] M_temp [0:99] [0:99];   // Q24.24

    // Result vector (tastiness for n scoops starting from each flavor)
    reg signed [31:0] res_vec [0:99]; // Q24.24
    reg signed [31:0] res_vec_temp [0:99];

    // Division registers
    reg [47:0] numerator;      // 48-bit for Q24.24
    reg [47:0] denominator;    // 48-bit for Q24.24
    reg [47:0] quotient;
    reg [47:0] remainder;
    reg [7:0] div_bit;

    // Helper signals
    reg [31:0] temp_sum;
    reg [31:0] temp_max;
    reg [31:0] temp_mult_a;
    reg [31:0] temp_mult_b;
    reg signed [63:0] mult_temp;
    reg [7:0] max_plus_k;

    // Cycle counter for safety
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd1000000;

    integer i, j;

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 48'd0;
            done <= 1'b0;
            valid <= 1'b0;
            n_reg <= 30'd0;
            k_reg <= 7'd0;
            a_reg <= 8'd0;
            b_reg <= 8'd0;
            cost_reg <= 32'd0;
            n_copy <= 30'd0;
            iter_counter <= 24'd0;
            fw_counter <= 8'd0;
            fw_i <= 8'd0;
            fw_j <= 8'd0;
            fw_k <= 8'd0;
            exp_counter <= 8'd0;
            row_idx <= 7'd0;
            col_idx <= 7'd0;
            temp_idx <= 7'd0;
            sign_flag <= 1'b0;
            numerator <= 48'd0;
            denominator <= 48'd0;
            quotient <= 48'd0;
            remainder <= 48'd0;
            div_bit <= 8'd0;
            temp_sum <= 32'd0;
            temp_max <= 32'd0;
            temp_mult_a <= 32'd0;
            temp_mult_b <= 32'd0;
            mult_temp <= 64'd0;
            max_plus_k <= 8'd0;
            cycle_count <= 32'd0;
            
            // Initialize matrices
            for (i = 0; i < 100; i = i + 1) begin
                for (j = 0; j < 100; j = j + 1) begin
                    M_base[i][j] <= MIN_32;
                    M_result[i][j] <= MIN_32;
                    M_pow[i][j] <= MIN_32;
                    M_temp[i][j] <= MIN_32;
                end
                res_vec[i] <= MIN_32;
                res_vec_temp[i] <= MIN_32;
            end
        end else begin
            cycle_count <= cycle_count + 32'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    result <= 48'd0;
                    iter_counter <= 24'd0;
                    fw_counter <= 8'd0;
                    fw_i <= 8'd0;
                    fw_j <= 8'd0;
                    fw_k <= 8'd0;
                    exp_counter <= 8'd0;
                    row_idx <= 7'd0;
                    col_idx <= 7'd0;
                    temp_idx <= 7'd0;
                    cycle_count <= 32'd0;
                    quotient <= 48'd0;
                    
                    if (start) begin
                        n_reg <= n;
                        k_reg <= k;
                        a_reg <= a;
                        b_reg <= b;
                        n_copy <= n;
                        state <= INIT_MATRIX;
                    end
                end

                INIT_MATRIX: begin
                    // Initialize M_base[i][j] = t[j] + u[i][j]
                    // Convert t[j] and u[i][j] from Q8.8 to Q24.24
                    if (row_idx < k_reg) begin
                        if (col_idx < k_reg) begin
                            // t[col_idx] is Q8.8, convert to Q24.24 (shift left by 16)
                            // u[row_idx][col_idx] is Q8.8
                            temp_sum = {t[col_idx], 16'd0}; // t[j] << 16
                            temp_mult_a = {u[row_idx][col_idx], 16'd0}; // u[i][j] << 16
                            
                            // Saturating addition for max-plus base
                            if (temp_sum >= 0 && temp_mult_a >= 0) begin
                                if (temp_sum > (MAX_32 - temp_mult_a)) begin
                                    M_base[row_idx][col_idx] <= MAX_32;
                                end else begin
                                    M_base[row_idx][col_idx] <= temp_sum + temp_mult_a;
                                end
                            end else if (temp_sum < 0 && temp_mult_a < 0) begin
                                if (temp_sum < (MIN_32 - temp_mult_a)) begin
                                    M_base[row_idx][col_idx] <= MIN_32;
                                end else begin
                                    M_base[row_idx][col_idx] <= temp_sum + temp_mult_a;
                                end
                            end else begin
                                M_base[row_idx][col_idx] <= temp_sum + temp_mult_a;
                            end
                            
                            col_idx <= col_idx + 7'd1;
                        end else begin
                            col_idx <= 7'd0;
                            row_idx <= row_idx + 7'd1;
                        end
                    end else begin
                        // Initialize M_pow = I (identity for max-plus is all MIN_32 except diag 0)
                        // But for matrix exponentiation, we start with M_pow = I (which is 0 on diag)
                        // Actually for max-plus algebra:
                        // Identity I has 0 on diagonal, -inf elsewhere
                        // When multiplying, we want (A^n) * I = A^n
                        for (i = 0; i < 100; i = i + 1) begin
                            for (j = 0; j < 100; j = j + 1) begin
                                if (i == j) begin
                                    M_pow[i][j] <= 32'd0; // Q24.24 zero
                                end else begin
                                    M_pow[i][j] <= MIN_32;
                                end
                                M_result[i][j] <= M_base[i][j]; // Start with base
                            end
                        end
                        state <= FLOYD_WARSHALL;
                        fw_counter <= 8'd0;
                        fw_i <= 8'd0;
                        fw_j <= 8'd0;
                        fw_k <= 8'd0;
                    end
                end

                FLOYD_WARSHALL: begin
                    // Compute all-pairs longest paths in M_base (up to 100 steps)
                    // Floyd-Warshall: for k: for i: for j: dist[i][j] = max(dist[i][j], dist[i][k] + dist[k][j])
                    // This handles negative weights and cycles
                    if (fw_counter < k_reg) begin
                        if (fw_i < k_reg) begin
                            if (fw_j < k_reg) begin
                                // Max-plus multiply: dist[i][j] = max(dist[i][j], dist[i][k] + dist[k][j])
                                if (M_base[fw_i][fw_counter] > MIN_32 && M_base[fw_counter][fw_j] > MIN_32) begin
                                    temp_sum = M_base[fw_i][fw_counter] + M_base[fw_counter][fw_j];
                                    // Saturating addition
                                    if (M_base[fw_i][fw_counter] > 0 && M_base[fw_counter][fw_j] > 0) begin
                                        if (M_base[fw_i][fw_counter] > (MAX_32 - M_base[fw_counter][fw_j])) begin
                                            temp_sum = MAX_32;
                                        end
                                    end else if (M_base[fw_i][fw_counter] < 0 && M_base[fw_counter][fw_j] < 0) begin
                                        if (M_base[fw_i][fw_counter] < (MIN_32 - M_base[fw_counter][fw_j])) begin
                                            temp_sum = MIN_32;
                                        end
                                    end
                                    
                                    if (temp_sum > M_base[fw_i][fw_j]) begin
                                        M_base[fw_i][fw_j] <= temp_sum;
                                    end
                                end
                                fw_j <= fw_j + 8'd1;
                            end else begin
                                fw_j <= 8'd0;
                                fw_i <= fw_i + 8'd1;
                            end
                        end else begin
                            fw_i <= 8'd0;
                            fw_counter <= fw_counter + 8'd1;
                        end
                    end else begin
                        state <= EXP_INIT;
                    end
                end

                EXP_INIT: begin
                    // n_copy = n (clamped to 2e9 is already handled by input)
                    // Check if n is 0 or 1
                    if (n_copy == 30'd0) begin
                        // 0 scoops, tastiness = 0
                        for (i = 0; i < 100; i = i + 1) begin
                            res_vec[i] <= 32'd0;
                        end
                        state <= CALC_COST;
                    end else if (n_copy == 30'd1) begin
                        // 1 scoop, result is M_base (single scoop)
                        // But we need max tastiness from any start to any end
                        // Actually for 1 scoop, it's just t[j]
                        // Wait, the problem says: tastiness for n scoops starting from any flavour
                        // Base case: 1 scoop starting from flavor i, ending at j: M[i][j]
                        // We need to find max over all paths of length n
                        // Initialize res_vec with base case
                        for (i = 0; i < 100; i = i + 1) begin
                            // For 1 scoop starting at i, max taste is max over j of M[i][j]
                            temp_max = MIN_32;
                            for (j = 0; j < 100; j = j + 1) begin
                                if (M_base[i][j] > temp_max) begin
                                    temp_max = M_base[i][j];
                                end
                            end
                            res_vec[i] <= temp_max;
                        end
                        state <= CALC_COST;
                    end else begin
                        // Initialize for exponentiation
                        // M_pow = I (0 on diag, -inf elsewhere)
                        for (i = 0; i < 100; i = i + 1) begin
                            for (j = 0; j < 100; j = j + 1) begin
                                if (i == j) begin
                                    M_pow[i][j] <= 32'd0;
                                end else begin
                                    M_pow[i][j] <= MIN_32;
                                end
                            end
                        end
                        exp_counter <= 8'd0;
                        // Copy base to M_temp for iterative squaring
                        for (i = 0; i < 100; i = i + 1) begin
                            for (j = 0; j < 100; j = j + 1) begin
                                M_temp[i][j] <= M_base[i][j];
                            end
                        end
                        state <= EXP_LOOP;
                    end
                end

                EXP_LOOP: begin
                    // Iterative matrix exponentiation: M^n
                    // Process n_copy bit by bit (shift right)
                    if (n_copy > 30'd0) begin
                        if (n_copy[0]) begin
                            // Multiply: M_pow = M_pow * M_temp (max-plus multiply)
                            // M_temp is the current power of 2
                            // Initialize M_result to MIN_32
                            for (i = 0; i < 100; i = i + 1) begin
                                for (j = 0; j < 100; j = j + 1) begin
                                    M_result[i][j] <= MIN_32;
                                end
                            end
                            row_idx <= 7'd0;
                            col_idx <= 7'd0;
                            max_plus_k <= 8'd0;
                            state <= EXP_MULT;
                        end else begin
                            n_copy <= n_copy >> 1;
                            // Square M_temp
                            // M_temp = M_temp * M_temp
                            for (i = 0; i < 100; i = i + 1) begin
                                for (j = 0; j < 100; j = j + 1) begin
                                    M_result[i][j] <= MIN_32;
                                end
                            end
                            row_idx <= 7'd0;
                            col_idx <= 7'd0;
                            max_plus_k <= 8'd100; // Use flag to distinguish squaring
                            state <= EXP_MULT;
                        end
                    end else begin
                        // Exponentiation complete
                        // Compute max tastiness from any start
                        for (i = 0; i < 100; i = i + 1) begin
                            temp_max = MIN_32;
                            for (j = 0; j < 100; j = j + 1) begin
                                if (M_pow[i][j] > temp_max) begin
                                    temp_max = M_pow[i][j];
                                end
                            end
                            res_vec[i] <= temp_max;
                        end
                        state <= CALC_COST;
                    end
                end

                EXP_MULT: begin
                    // Perform matrix multiplication: A = A * B
                    // A: M_pow (if max_plus_k < 100) or M_temp (if max_plus_k == 100)
                    // B: M_temp
                    // Result: M_result
                    
                    // Inner loop: compute M_result[row_idx][col_idx]
                    if (row_idx < k_reg) begin
                        if (col_idx < k_reg) begin
                            // Max-plus multiply
                            // M_result[i][j] = max_k (A[i][k] + B[k][j])
                            if (max_plus_k < 100) begin
                                // Normal multiplication: M_pow * M_temp
                                temp_sum = M_pow[row_idx][max_plus_k] + M_temp[max_plus_k][col_idx];
                            end else begin
                                // Squaring: M_temp * M_temp
                                temp_sum = M_temp[row_idx][max_plus_k] + M_temp[max_plus_k][col_idx];
                            end
                            
                            // Check for overflow in addition
                            if ((max_plus_k < 100 && M_pow[row_idx][max_plus_k] > MIN_32 && M_temp[max_plus_k][col_idx] > MIN_32) ||
                                (max_plus_k >= 100 && M_temp[row_idx][max_plus_k] > MIN_32 && M_temp[max_plus_k][col_idx] > MIN_32)) begin
                                
                                // Saturate addition
                                reg [31:0] val_a, val_b;
                                if (max_plus_k < 100) begin
                                    val_a = M_pow[row_idx][max_plus_k];
                                    val_b = M_temp[max_plus_k][col_idx];
                                end else begin
                                    val_a = M_temp[row_idx][max_plus_k];
                                    val_b = M_temp[max_plus_k][col_idx];
                                end

                                if (val_a > 0 && val_b > 0) begin
                                    if (val_a > (MAX_32 - val_b)) begin
                                        temp_sum = MAX_32;
                                    end
                                end else if (val_a < 0 && val_b < 0) begin
                                    if (val_a < (MIN_32 - val_b)) begin
                                        temp_sum = MIN_32;
                                    end
                                end

                                if (temp_sum > M_result[row_idx][col_idx]) begin
                                    M_result[row_idx][col_idx] <= temp_sum;
                                end
                            end
                            
                            max_plus_k <= max_plus_k + 8'd1;
                        end else begin
                            col_idx <= 7'd0;
                            max_plus_k <= 8'd0;
                            row_idx <= row_idx + 7'd1;
                        end
                    end else begin
                        // Multiplication complete
                        if (max_plus_k < 100) begin
                            // Update M_pow = M_result
                            for (i = 0; i < 100; i = i + 1) begin
                                for (j = 0; j < 100; j = j + 1) begin
                                    M_pow[i][j] <= M_result[i][j];
                                end
                            end
                            n_copy <= n_copy >> 1;
                            state <= EXP_LOOP;
                        end else begin
                            // Update M_temp = M_result
                            for (i = 0; i < 100; i = i + 1) begin
                                for (j = 0; j < 100; j = j + 1) begin
                                    M_temp[i][j] <= M_result[i][j];
                                end
                            end
                            n_copy <= n_copy >> 1;
                            state <= EXP_LOOP;
                        end
                    end
                end

                CALC_COST: begin
                    // cost = n * a + b
                    // Saturate to 32-bit
                    // n <= 2e9, a <= 200, so n*a <= 400e9 = 4e11 ~ 39 bits
                    // Max is 2e9 * 200 = 4e11, which is > 32 bits (max 4.29e9)
                    // Saturate at 32-bit max
                    
                    // Check saturation
                    // 2e9 * 200 = 400e9. 2^32-1 = 4.29e9
                    // So it WILL saturate if n is large
                    
                    if (n_reg > 21474836) begin // 2^31 / 100 roughly
                        cost_reg <= MAX_32;
                    end else begin
                        // Normal calc
                        // n * a (both are small enough for 32-bit)
                        temp_mult_a = n_reg * a_reg;
                        // Add b
                        if (temp_mult_a > (MAX_32 - b_reg)) begin
                            cost_reg <= MAX_32;
                        end else begin
                            cost_reg <= temp_mult_a + b_reg;
                        end
                    end
                    
                    state <= DIV_START;
                end

                DIV_START: begin
                    // Division: result = (max_tastiness / cost) * 2^24
                    // Inputs: res_vec[i] (Q24.24), cost_reg (integer)
                    // Output: result (Q24.24) which is (max_tastiness / cost) * 2^24
                    // This is equivalent to (res_vec[i] / cost_reg)
                    // res_vec[i] is signed 32-bit Q24.24
                    // cost_reg is unsigned 32-bit
                    
                    // Find max tastiness from all starting flavors
                    temp_max = MIN_32;
                    for (i = 0; i < 100; i = i + 1) begin
                        if (res_vec[i] > temp_max) begin
                            temp_max = res_vec[i];
                        end
                    end
                    
                    // Handle sign
                    if (temp_max < 0) begin
                        sign_flag <= 1'b1;
                        numerator <= -temp_max; // Absolute value
                    end else begin
                        sign_flag <= 1'b0;
                        numerator <= temp_max;
                    end
                    
                    denominator <= cost_reg;
                    quotient <= 48'd0;
                    remainder <= 48'd0;
                    div_bit <= 8'd0;
                    
                    // Special cases
                    if (cost_reg == 32'd0) begin
                        // Division by zero -> max result
                        if (temp_max < 0) begin
                            result <= MIN_Q24_24;
                        end else begin
                            result <= MAX_Q24_24;
                        end
                        state <= FINISH;
                    end else if (temp_max == 32'd0) begin
                        result <= 48'd0;
                        state <= FINISH;
                    end else begin
                        state <= DIV_LOOP;
                    end
                end

                DIV_LOOP: begin
                    // Long division for numerator / denominator
                    // We need 48-bit precision
                    // Implementation: shift-subtract algorithm
                    
                    if (div_bit < 8'd48) begin
                        // Shift remainder left
                        remainder <= {remainder[46:0], numerator[47]};
                        numerator <= {numerator[46:0], 1'b0};
                        
                        // Shift quotient left
                        quotient <= {quotient[46:0], 1'b0};
                        
                        // Check if remainder >= denominator
                        if (remainder >= denominator) begin
                            remainder <= remainder - denominator;
                            quotient <= quotient | 48'd1;
                        end
                        
                        div_bit <= div_bit + 8'd1;
                    end else begin
                        // Division complete
                        if (sign_flag) begin
                            // Negative result (two's complement)
                            // result = ~quotient + 1
                            result <= ~quotient + 48'd1;
                        end else begin
                            result <= quotient;
                        end
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule