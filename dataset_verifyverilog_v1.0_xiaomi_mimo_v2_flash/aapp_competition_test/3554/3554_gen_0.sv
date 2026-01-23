module three_headed_monkey (
    input [31:0] D,
    input [31:0] W,
    input [31:0] C,
    output reg [31:0] result
);

    reg [31:0] F_int;
    reg [31:0] L_int;
    reg [31:0] deliverable_int;
    reg [31:0] n_int;
    reg [31:0] f_num;
    reg [31:0] f_den;
    reg [31:0] d1_num;
    reg [31:0] d1_den;
    reg [31:0] T_n_num;
    reg [31:0] T_n_den;
    reg [31:0] R_num;
    reg [31:0] R_den;
    reg [31:0] target_num;
    reg [31:0] target_den;
    reg [31:0] T_i_num;
    reg [31:0] T_i_den;
    reg [31:0] i_val;
    reg [31:0] deliverable_num;
    reg [31:0] deliverable_den;
    reg [31:0] temp_num;
    reg [31:0] temp_den;
    reg [63:0] mult_temp;
    reg [63:0] mult_temp2;
    reg [63:0] div_temp;
    reg [63:0] div_temp2;
    reg [31:0] loop_counter;
    reg [31:0] max_loop;
    reg [31:0] i_loop;
    reg [31:0] sum_num;
    reg [31:0] sum_den;
    reg [31:0] term_num;
    reg [31:0] term_den;
    reg [31:0] compare_num1;
    reg [31:0] compare_den1;
    reg [31:0] compare_num2;
    reg [31:0] compare_den2;
    reg [63:0] cross1;
    reg [63:0] cross2;
    reg cmp_result;
    
    // Internal helper function for comparison (a/b >= c/d => ad >= bc)
    // Returns 1 if a/b >= c/d
    function automatic [0:0] is_gte;
        input [31:0] a_num;
        input [31:0] a_den;
        input [31:0] b_num;
        input [31:0] b_den;
        begin
            if (b_den == 32'd0) begin
                is_gte = 1'b0;
            end else begin
                cross1 = a_num * b_den;
                cross2 = b_num * a_den;
                is_gte = (cross1 >= cross2);
            end
        end
    endfunction

    // Internal helper for gcd
    function automatic [31:0] gcd_func;
        input [31:0] x;
        input [31:0] y;
        reg [31:0] a;
        reg [31:0] b;
        reg [31:0] temp;
        begin
            a = x;
            b = y;
            while (b != 32'd0) begin
                temp = b;
                b = a % b;
                a = temp;
            end
            gcd_func = a;
        end
    endfunction

    // Internal helper for division of rationals (a/b) / (c/d) = (a*d)/(b*c)
    function automatic [63:0] div_rational;
        input [31:0] a_num;
        input [31:0] a_den;
        input [31:0] b_num;
        input [31:0] b_den;
        reg [63:0] num;
        reg [63:0] den;
        reg [31:0] g_num;
        reg [31:0] g_den;
        begin
            num = a_num * b_den;
            den = a_den * b_num;
            // Reduce fraction
            if (den != 64'd0) begin
                g_num = gcd_func(num[31:0], den[31:0]);
                if (g_num != 32'd0) begin
                    num = num / g_num;
                    den = den / g_num;
                end
            end
            div_rational = {num[31:0], den[31:0]};
        end
    endfunction

    // Internal helper for subtraction
    function automatic [63:0] sub_rational;
        input [31:0] a_num;
        input [31:0] a_den;
        input [31:0] b_num;
        input [31:0] b_den;
        reg [63:0] num;
        reg [63:0] den;
        reg [31:0] g_num;
        reg [31:0] g_den;
        begin
            num = (a_num * b_den) - (b_num * a_den);
            den = a_den * b_den;
            // Reduce fraction
            if (den != 64'd0 && num != 64'd0) begin
                g_num = gcd_func(num[31:0], den[31:0]);
                if (g_num != 32'd0) begin
                    num = num / g_num;
                    den = den / g_num;
                end
            end
            sub_rational = {num[31:0], den[31:0]};
        end
    endfunction

    // Internal helper for addition
    function automatic [63:0] add_rational;
        input [31:0] a_num;
        input [31:0] a_den;
        input [31:0] b_num;
        input [31:0] b_den;
        reg [63:0] num;
        reg [63:0] den;
        reg [31:0] g_num;
        reg [31:0] g_den;
        begin
            num = (a_num * b_den) + (b_num * a_den);
            den = a_den * b_den;
            // Reduce fraction
            if (den != 64'd0 && num != 64'd0) begin
                g_num = gcd_func(num[31:0], den[31:0]);
                if (g_num != 32'd0) begin
                    num = num / g_num;
                    den = den / g_num;
                end
            end
            add_rational = {num[31:0], den[31:0]};
        end
    endfunction

    // Internal helper for multiplication
    function automatic [63:0] mul_rational;
        input [31:0] a_num;
        input [31:0] a_den;
        input [31:0] b_num;
        input [31:0] b_den;
        reg [63:0] num;
        reg [63:0] den;
        reg [31:0] g_num;
        reg [31:0] g_den;
        begin
            num = a_num * b_num;
            den = a_den * b_den;
            // Reduce fraction
            if (den != 64'd0 && num != 64'd0) begin
                g_num = gcd_func(num[31:0], den[31:0]);
                if (g_num != 32'd0) begin
                    num = num / g_num;
                    den = den / g_num;
                end
            end
            mul_rational = {num[31:0], den[31:0]};
        end
    endfunction

    // Internal helper for division by integer
    function automatic [63:0] div_by_int;
        input [31:0] a_num;
        input [31:0] a_den;
        input [31:0] b;
        reg [63:0] num;
        reg [63:0] den;
        reg [31:0] g_num;
        reg [31:0] g_den;
        begin
            num = a_num;
            den = a_den * b;
            // Reduce fraction
            if (den != 64'd0 && num != 64'd0) begin
                g_num = gcd_func(num[31:0], den[31:0]);
                if (g_num != 32'd0) begin
                    num = num / g_num;
                    den = den / g_num;
                end
            end
            div_by_int = {num[31:0], den[31:0]};
        end
    endfunction

    // Internal helper for multiplication by integer
    function automatic [63:0] mul_by_int;
        input [31:0] a_num;
        input [31:0] a_den;
        input [31:0] b;
        reg [63:0] num;
        reg [63:0] den;
        reg [31:0] g_num;
        reg [31:0] g_den;
        begin
            num = a_num * b;
            den = a_den;
            // Reduce fraction
            if (den != 64'd0 && num != 64'd0) begin
                g_num = gcd_func(num[31:0], den[31:0]);
                if (g_num != 32'd0) begin
                    num = num / g_num;
                    den = den / g_num;
                end
            end
            mul_by_int = {num[31:0], den[31:0]};
        end
    endfunction

    // Main calculation
    always @(*) begin
        // Initialize
        F_int = W;
        L_int = D;
        deliverable_int = 32'd0;
        
        // Check for zero C
        if (C == 32'd0) begin
            deliverable_int = 32'd0;
        end
        // Check if F <= C (i.e., W <= C)
        else if (F_int <= L_int) begin
            // F <= C case
            if (F_int > L_int) begin
                // deliverable_normalized = (F - L) / 1 = F - L
                if (F_int >= L_int) begin
                    deliverable_int = F_int - L_int;
                end else begin
                    deliverable_int = 32'd0;
                end
            end else begin
                deliverable_int = 32'd0;
            end
        end else begin
            // F > C case (W > C)
            // Compute n = floor(W / C)
            n_int = W / C;
            
            // Compute f_num / f_den = (W % C) / C
            // But we need to reduce, so:
            f_num = W % C;
            f_den = C;
            if (f_num != 32'd0) begin
                mult_temp = gcd_func(f_num, f_den);
                if (mult_temp != 32'd0) begin
                    f_num = f_num / mult_temp;
                    f_den = f_den / mult_temp;
                end
            end
            
            // Compute d1 = f / (2*n + 1)
            // d1_num / d1_den = f_num / (f_den * (2*n + 1))
            mult_temp = 2 * n_int + 1;
            temp_num = f_num;
            temp_den = f_den * mult_temp;
            // Reduce
            if (temp_den != 32'd0) begin
                mult_temp2 = gcd_func(temp_num, temp_den);
                if (mult_temp2 != 32'd0) begin
                    temp_num = temp_num / mult_temp2;
                    temp_den = temp_den / mult_temp2;
                end
            end
            d1_num = temp_num;
            d1_den = temp_den;
            
            // Compute T_n = sum_{k=1}^{n} 1/(2k-1)
            sum_num = 1;
            sum_den = 1;
            for (i_loop = 2; i_loop <= n_int; i_loop = i_loop + 1) begin
                term_num = 1;
                term_den = 2 * i_loop - 1;
                sum_rational(sum_num, sum_den, term_num, term_den);
                sum_num = temp_num;
                sum_den = temp_den;
            end
            T_n_num = sum_num;
            T_n_den = sum_den;
            
            // Compute R = L - d1
            // Check if L >= d1 + T_n
            // First compute d1 + T_n
            temp_num = d1_num;
            temp_den = d1_den;
            add_rational(temp_num, temp_den, T_n_num, T_n_den);
            temp_num = temp_num;
            temp_den = temp_den;
            
            // Compare L (which is D/C) with (d1 + T_n)
            // L is D/C, so L_num = D, L_den = C
            compare_num1 = D;
            compare_den1 = C;
            compare_num2 = temp_num;
            compare_den2 = temp_den;
            cmp_result = is_gte(compare_num1, compare_den1, compare_num2, compare_den2);
            
            if (cmp_result) begin
                // L >= d1 + T_n
                deliverable_int = 32'd0;
            end else begin
                // L < d1 + T_n
                // Compute R = L - d1
                // L_num = D, L_den = C
                temp_num = D;
                temp_den = C;
                sub_rational(temp_num, temp_den, d1_num, d1_den);
                R_num = temp_num;
                R_den = temp_den;
                
                // Compute target = T_n - R
                sub_rational(T_n_num, T_n_den, R_num, R_den);
                target_num = temp_num;
                target_den = temp_den;
                
                // Find smallest i>=1 such that T_i >= target
                // T_i starts at 1/1 = 1
                T_i_num = 1;
                T_i_den = 1;
                i_val = 1;
                
                // Compare T_i with target
                // T_i_num / T_i_den >= target_num / target_den?
                cmp_result = is_gte(T_i_num, T_i_den, target_num, target_den);
                
                // Loop until T_i >= target or safety limit
                loop_counter = 0;
                max_loop = 32'd1000;
                while (!cmp_result && loop_counter < max_loop) begin
                    i_val = i_val + 1;
                    term_num = 1;
                    term_den = 2 * i_val - 1;
                    // Add term to T_i
                    add_rational(T_i_num, T_i_den, term_num, term_den);
                    T_i_num = temp_num;
                    T_i_den = temp_den;
                    // Re-compare
                    cmp_result = is_gte(T_i_num, T_i_den, target_num, target_den);
                    loop_counter = loop_counter + 1;
                end
                
                // deliverable_normalized = i - (2*i - 1) * (T_i - target)
                // Compute T_i - target
                sub_rational(T_i_num, T_i_den, target_num, target_den);
                temp_num = temp_num;
                temp_den = temp_den;
                
                // Compute (2*i - 1) * (T_i - target)
                // (2*i - 1) is integer, so multiply by it
                mul_rational(2 * i_val - 1, 1, temp_num, temp_den);
                temp_num = temp_num;
                temp_den = temp_den;
                
                // Compute i - result
                // i is i_val/1
                sub_rational(i_val, 1, temp_num, temp_den);
                deliverable_num = temp_num;
                deliverable_den = temp_den;
                
                // Convert to ml: deliverable = deliverable_normalized * C
                // deliverable_normalized = deliverable_num / deliverable_den
                // deliverable = (deliverable_num / deliverable_den) * C = (deliverable_num * C) / deliverable_den
                if (deliverable_den != 32'd0) begin
                    mult_temp = deliverable_num * C;
                    // Divide by deliverable_den
                    deliverable_int = mult_temp / deliverable_den;
                end else begin
                    deliverable_int = 32'd0;
                end
            end
        end
        
        result = deliverable_int;
    end

endmodule