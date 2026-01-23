module pairs_sum_to_zero (
    input signed [7:0] elements_0,
    input signed [7:0] elements_1,
    input signed [7:0] elements_2,
    input signed [7:0] elements_3,
    input signed [7:0] elements_4,
    input signed [7:0] elements_5,
    input signed [7:0] elements_6,
    input signed [7:0] elements_7,
    input [2:0] valid_count,
    output result
);

    // Store all elements in an array for easier pair checking
    wire signed [7:0] elements [0:7];
    assign elements[0] = elements_0;
    assign elements[1] = elements_1;
    assign elements[2] = elements_2;
    assign elements[3] = elements_3;
    assign elements[4] = elements_4;
    assign elements[5] = elements_5;
    assign elements[6] = elements_6;
    assign elements[7] = elements_7;

    // Check all valid pairs (i, j) where i < j
    // Pairs are checked for indices within valid_count
    wire pair_0_1_sum_zero = (valid_count > 2'd1) && (elements[0] + elements[1] == 8'sd0);
    wire pair_0_2_sum_zero = (valid_count > 3'd2) && (elements[0] + elements[2] == 8'sd0);
    wire pair_0_3_sum_zero = (valid_count > 3'd3) && (elements[0] + elements[3] == 8'sd0);
    wire pair_0_4_sum_zero = (valid_count > 3'd4) && (elements[0] + elements[4] == 8'sd0);
    wire pair_0_5_sum_zero = (valid_count > 3'd5) && (elements[0] + elements[5] == 8'sd0);
    wire pair_0_6_sum_zero = (valid_count > 3'd6) && (elements[0] + elements[6] == 8'sd0);
    wire pair_0_7_sum_zero = (valid_count > 3'd7) && (elements[0] + elements[7] == 8'sd0);

    wire pair_1_2_sum_zero = (valid_count > 3'd2) && (elements[1] + elements[2] == 8'sd0);
    wire pair_1_3_sum_zero = (valid_count > 3'd3) && (elements[1] + elements[3] == 8'sd0);
    wire pair_1_4_sum_zero = (valid_count > 3'd4) && (elements[1] + elements[4] == 8'sd0);
    wire pair_1_5_sum_zero = (valid_count > 3'd5) && (elements[1] + elements[5] == 8'sd0);
    wire pair_1_6_sum_zero = (valid_count > 3'd6) && (elements[1] + elements[6] == 8'sd0);
    wire pair_1_7_sum_zero = (valid_count > 3'd7) && (elements[1] + elements[7] == 8'sd0);

    wire pair_2_3_sum_zero = (valid_count > 3'd3) && (elements[2] + elements[3] == 8'sd0);
    wire pair_2_4_sum_zero = (valid_count > 3'd4) && (elements[2] + elements[4] == 8'sd0);
    wire pair_2_5_sum_zero = (valid_count > 3'd5) && (elements[2] + elements[5] == 8'sd0);
    wire pair_2_6_sum_zero = (valid_count > 3'd6) && (elements[2] + elements[6] == 8'sd0);
    wire pair_2_7_sum_zero = (valid_count > 3'd7) && (elements[2] + elements[7] == 8'sd0);

    wire pair_3_4_sum_zero = (valid_count > 3'd4) && (elements[3] + elements[4] == 8'sd0);
    wire pair_3_5_sum_zero = (valid_count > 3'd5) && (elements[3] + elements[5] == 8'sd0);
    wire pair_3_6_sum_zero = (valid_count > 3'd6) && (elements[3] + elements[6] == 8'sd0);
    wire pair_3_7_sum_zero = (valid_count > 3'd7) && (elements[3] + elements[7] == 8'sd0);

    wire pair_4_5_sum_zero = (valid_count > 3'd5) && (elements[4] + elements[5] == 8'sd0);
    wire pair_4_6_sum_zero = (valid_count > 3'd6) && (elements[4] + elements[6] == 8'sd0);
    wire pair_4_7_sum_zero = (valid_count > 3'd7) && (elements[4] + elements[7] == 8'sd0);

    wire pair_5_6_sum_zero = (valid_count > 3'd6) && (elements[5] + elements[6] == 8'sd0);
    wire pair_5_7_sum_zero = (valid_count > 3'd7) && (elements[5] + elements[7] == 8'sd0);

    wire pair_6_7_sum_zero = (valid_count > 3'd7) && (elements[6] + elements[7] == 8'sd0);

    // Combine all pair checks
    assign result = pair_0_1_sum_zero | pair_0_2_sum_zero | pair_0_3_sum_zero | pair_0_4_sum_zero |
                    pair_0_5_sum_zero | pair_0_6_sum_zero | pair_0_7_sum_zero | pair_1_2_sum_zero |
                    pair_1_3_sum_zero | pair_1_4_sum_zero | pair_1_5_sum_zero | pair_1_6_sum_zero |
                    pair_1_7_sum_zero | pair_2_3_sum_zero | pair_2_4_sum_zero | pair_2_5_sum_zero |
                    pair_2_6_sum_zero | pair_2_7_sum_zero | pair_3_4_sum_zero | pair_3_5_sum_zero |
                    pair_3_6_sum_zero | pair_3_7_sum_zero | pair_4_5_sum_zero | pair_4_6_sum_zero |
                    pair_4_7_sum_zero | pair_5_6_sum_zero | pair_5_7_sum_zero | pair_6_7_sum_zero;

endmodule