module dict_sum (
    input [7:0] num_items,
    input [7:0][15:0] values,
    output [15:0] sum
);

    // Internal signals for masked values
    wire [15:0] masked_values [7:0];
    wire [15:0] stage1_sum [3:0];
    wire [15:0] stage2_sum [1:0];
    wire [15:0] stage3_sum;

    // Mask values based on num_items (combinational logic)
    // Assumes num_items is 1-8, but handles 0 case safely
    // If index < num_items, pass value; else 0
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : mask_gen
            assign masked_values[i] = (num_items > i) ? values[i] : 16'd0;
        end
    endgenerate

    // Stage 1: 8 -> 4 adders
    assign stage1_sum[0] = masked_values[0] + masked_values[1];
    assign stage1_sum[1] = masked_values[2] + masked_values[3];
    assign stage1_sum[2] = masked_values[4] + masked_values[5];
    assign stage1_sum[3] = masked_values[6] + masked_values[7];

    // Stage 2: 4 -> 2 adders
    assign stage2_sum[0] = stage1_sum[0] + stage1_sum[1];
    assign stage2_sum[1] = stage1_sum[2] + stage1_sum[3];

    // Stage 3: 2 -> 1 adder
    assign stage3_sum = stage2_sum[0] + stage2_sum[1];

    // Output
    assign sum = stage3_sum;

endmodule