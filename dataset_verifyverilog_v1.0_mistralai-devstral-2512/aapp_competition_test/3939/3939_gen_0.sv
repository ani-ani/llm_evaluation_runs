module ArrayTransformCheck(
    input clk,
    input rst_n,
    input start,
    input [7:0] k,
    input [7:0] a [0:15],
    input [4:0] n,
    output reg result,
    output reg done
);

    reg [7:0] k_exists;
    reg [7:0] condition1 [0:15];
    reg [7:0] condition2 [0:15];
    reg [7:0] condition3 [0:15];
    reg [7:0] condition4 [0:15];
    reg [7:0] any_condition [0:15];
    reg [15:0] any_condition_reduced;
    reg [15:0] k_exists_reduced;
    reg [15:0] n_mask;
    reg [15:0] n_minus_1_mask;
    reg [15:0] n_minus_2_mask;
    reg [15:0] n_plus_1_mask;
    reg [15:0] n_plus_2_mask;
    reg [15:0] valid_indices;
    reg [15:0] valid_conditions;
    reg [15:0] final_or;
    reg [15:0] k_exists_final;
    reg [15:0] n_equals_1;
    reg [15:0] n_equals_1_final;
    reg [15:0] result_pre;
    reg [15:0] result_final;
    reg [15:0] done_pre;
    reg [15:0] done_final;

    integer i;

    always @(*) begin
        // Generate masks for valid indices
        n_mask = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            if (i < n) begin
                n_mask[i] = 1'b1;
            end else begin
                n_mask[i] = 1'b0;
            end
        end

        n_minus_1_mask = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            if (i < n - 1) begin
                n_minus_1_mask[i] = 1'b1;
            end else begin
                n_minus_1_mask[i] = 1'b0;
            end
        end

        n_minus_2_mask = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            if (i < n - 2) begin
                n_minus_2_mask[i] = 1'b1;
            end else begin
                n_minus_2_mask[i] = 1'b0;
            end
        end

        n_plus_1_mask = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            if (i > 0) begin
                n_plus_1_mask[i] = 1'b1;
            end else begin
                n_plus_1_mask[i] = 1'b0;
            end
        end

        n_plus_2_mask = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            if (i > 1) begin
                n_plus_2_mask[i] = 1'b1;
            end else begin
                n_plus_2_mask[i] = 1'b0;
            end
        end

        // Check if k exists in array
        for (i = 0; i < 16; i = i + 1) begin
            if (a[i] == k) begin
                k_exists[i] = 1'b1;
            end else begin
                k_exists[i] = 1'b0;
            end
        end

        // Check conditions
        for (i = 0; i < 16; i = i + 1) begin
            // Condition 1: i < n-1 and a[i] >= k and a[i+1] >= k
            if (n_minus_1_mask[i] && (a[i] >= k) && (a[i+1] >= k)) begin
                condition1[i] = 1'b1;
            end else begin
                condition1[i] = 1'b0;
            end

            // Condition 2: i > 0 and a[i] >= k and a[i-1] >= k
            if (n_plus_1_mask[i] && (a[i] >= k) && (a[i-1] >= k)) begin
                condition2[i] = 1'b1;
            end else begin
                condition2[i] = 1'b0;
            end

            // Condition 3: i > 1 and a[i] >= k and a[i-2] >= k
            if (n_plus_2_mask[i] && (a[i] >= k) && (a[i-2] >= k)) begin
                condition3[i] = 1'b1;
            end else begin
                condition3[i] = 1'b0;
            end

            // Condition 4: i < n-2 and a[i] >= k and a[i+2] >= k
            if (n_minus_2_mask[i] && (a[i] >= k) && (a[i+2] >= k)) begin
                condition4[i] = 1'b1;
            end else begin
                condition4[i] = 1'b0;
            end

            // Any condition true
            any_condition[i] = condition1[i] | condition2[i] | condition3[i] | condition4[i];
        end

        // Reduce conditions
        any_condition_reduced = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            any_condition_reduced[i] = any_condition[i];
        end

        k_exists_reduced = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            k_exists_reduced[i] = k_exists[i];
        end

        // Valid indices
        valid_indices = n_mask;

        // Valid conditions
        valid_conditions = any_condition_reduced & valid_indices;

        // Final OR
        final_or = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            final_or[i] = valid_conditions[i];
        end

        // Check if n == 1
        n_equals_1 = 16'd0;
        if (n == 5'd1) begin
            n_equals_1[0] = 1'b1;
        end else begin
            n_equals_1[0] = 1'b0;
        end

        n_equals_1_final = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            n_equals_1_final[i] = n_equals_1[i];
        end

        // Result pre
        result_pre = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            if (k_exists_reduced[i] && (n_equals_1_final[i] || final_or[i])) begin
                result_pre[i] = 1'b1;
            end else begin
                result_pre[i] = 1'b0;
            end
        end

        // Result final
        result_final = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            result_final[i] = result_pre[i];
        end

        // Done pre
        done_pre = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            if (start) begin
                done_pre[i] = 1'b1;
            end else begin
                done_pre[i] = 1'b0;
            end
        end

        // Done final
        done_final = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            done_final[i] = done_pre[i];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            result <= result_final[0];
            done <= done_final[0];
        end
    end

endmodule