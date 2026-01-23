module max_sum_list (
    input logic [2:0][3:0] list_0,
    input logic [2:0][3:0] list_1,
    input logic [2:0][3:0] list_2,
    input logic [2:0][3:0] list_3,
    output logic [2:0][3:0] max_list
);

    // Calculate sums of each list
    // Sum range: -24 to 21, needs 6 bits signed
    logic signed [5:0] sum_0;
    logic signed [5:0] sum_1;
    logic signed [5:0] sum_2;
    logic signed [5:0] sum_3;

    assign sum_0 = $signed(list_0[0]) + $signed(list_0[1]) + $signed(list_0[2]);
    assign sum_1 = $signed(list_1[0]) + $signed(list_1[1]) + $signed(list_1[2]);
    assign sum_2 = $signed(list_2[0]) + $signed(list_2[1]) + $signed(list_2[2]);
    assign sum_3 = $signed(list_3[0]) + $signed(list_3[1]) + $signed(list_3[2]);

    // Compare sums and select the maximum list
    always_comb begin
        // Default to list_0, then compare against others
        if (sum_1 > sum_0 && sum_1 >= sum_2 && sum_1 >= sum_3)
            max_list = list_1;
        else if (sum_2 > sum_0 && sum_2 >= sum_1 && sum_2 >= sum_3)
            max_list = list_2;
        else if (sum_3 > sum_0 && sum_3 >= sum_1 && sum_3 >= sum_2)
            max_list = list_3;
        else
            max_list = list_0;
    end

endmodule