module max_sum_list(
    input  signed [3:0][2:0][7:0] lists,
    output signed [2:0][7:0]      max_list,
    output signed [8:0]           max_sum
);

    // Internal wires for sums of each list
    wire signed [8:0] sum0;
    wire signed [8:0] sum1;
    wire signed [8:0] sum2;
    wire signed [8:0] sum3;

    // Compute sums in parallel
    assign sum0 = $signed(lists[0][0]) + $signed(lists[0][1]) + $signed(lists[0][2]);
    assign sum1 = $signed(lists[1][0]) + $signed(lists[1][1]) + $signed(lists[1][2]);
    assign sum2 = $signed(lists[2][0]) + $signed(lists[2][1]) + $signed(lists[2][2]);
    assign sum3 = $signed(lists[3][0]) + $signed(lists[3][1]) + $signed(lists[3][2]);

    // Determine maximum sum and corresponding index
    wire signed [8:0] max01_sum;
    wire        [1:0] max01_idx;
    wire signed [8:0] max23_sum;
    wire        [1:0] max23_idx;
    wire signed [8:0] final_max_sum;
    wire        [1:0] final_idx;

    // Compare list 0 and 1
    assign {max01_sum, max01_idx} = (sum0 >= sum1) ? {sum0, 2'd0} : {sum1, 2'd1};

    // Compare list 2 and 3
    assign {max23_sum, max23_idx} = (sum2 >= sum3) ? {sum2, 2'd2} : {sum3, 2'd3};

    // Final compare between winners of previous stages
    assign {final_max_sum, final_idx} = (max01_sum >= max23_sum) ? {max01_sum, max01_idx}
                                                                     : {max23_sum, max23_idx};

    // Output max_sum
    assign max_sum = final_max_sum;

    // Select corresponding max_list
    assign max_list = lists[final_idx];

endmodule