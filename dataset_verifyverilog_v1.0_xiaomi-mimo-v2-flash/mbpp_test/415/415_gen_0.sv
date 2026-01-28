module max_product_pair (
    input clk,
    input rst_n,
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    output reg [7:0] pair_a,
    output reg [7:0] pair_b,
    output reg valid
);

    // Stage 1: Find maximum and minimum values
    // Use signed comparison
    reg signed [7:0] stage1_max;
    reg signed [7:0] stage1_min;
    reg stage1_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1_max <= 8'sd0;
            stage1_min <= 8'sd0;
            stage1_valid <= 1'b0;
        end else begin
            // Find maximum and minimum in parallel
            stage1_max <= arr_0;
            if (arr_1 > stage1_max) stage1_max <= arr_1;
            if (arr_2 > stage1_max) stage1_max <= arr_2;
            if (arr_3 > stage1_max) stage1_max <= arr_3;
            if (arr_4 > stage1_max) stage1_max <= arr_4;
            if (arr_5 > stage1_max) stage1_max <= arr_5;
            if (arr_6 > stage1_max) stage1_max <= arr_6;
            if (arr_7 > stage1_max) stage1_max <= arr_7;

            stage1_min <= arr_0;
            if (arr_1 < stage1_min) stage1_min <= arr_1;
            if (arr_2 < stage1_min) stage1_min <= arr_2;
            if (arr_3 < stage1_min) stage1_min <= arr_3;
            if (arr_4 < stage1_min) stage1_min <= arr_4;
            if (arr_5 < stage1_min) stage1_min <= arr_5;
            if (arr_6 < stage1_min) stage1_min <= arr_6;
            if (arr_7 < stage1_min) stage1_min <= arr_7;

            stage1_valid <= 1'b1;
        end
    end

    // Stage 2: Compute products and select maximum product
    // Product of two 8-bit signed numbers fits in 16 bits
    reg signed [15:0] prod_max;
    reg signed [15:0] prod_min;
    reg stage2_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prod_max <= 16'sd0;
            prod_min <= 16'sd0;
            stage2_valid <= 1'b0;
        end else begin
            // Compute max*max and min*min
            prod_max <= stage1_max * stage1_max;
            prod_min <= stage1_min * stage1_min;
            stage2_valid <= stage1_valid;
        end
    end

    // Output stage: Select pair with maximum product
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pair_a <= 8'sd0;
            pair_b <= 8'sd0;
            valid <= 1'b0;
        end else begin
            if (stage2_valid) begin
                // Compare products and assign outputs
                if (prod_max >= prod_min) begin
                    pair_a <= stage1_max;
                    pair_b <= stage1_max;
                end else begin
                    pair_a <= stage1_min;
                    pair_b <= stage1_min;
                end
                valid <= 1'b1;
            end else begin
                valid <= 1'b0;
            end
        end
    end

endmodule