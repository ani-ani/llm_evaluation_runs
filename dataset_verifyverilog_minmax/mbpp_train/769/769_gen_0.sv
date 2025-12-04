module list_difference (
    input [3:0] list1 [0:3],
    input [3:0] list2 [0:3],
    input [3:0] valid1,
    input [3:0] valid2,
    output logic [3:0] result [0:7],
    output logic [3:0] size
);
    // Parallel comparators for each element
    wire include1_0, include1_1, include1_2, include1_3;
    wire include2_0, include2_1, include2_2, include2_3;
    assign include1_0 = valid1[0] & ~(((list1[0] == list2[0]) && valid2[0]) | ((list1[0] == list2[1]) && valid2[1]) | ((list1[0] == list2[2]) && valid2[2]) | ((list1[0] == list2[3]) && valid2[3]));
    assign include1_1 = valid1[1] & ~(((list1[1] == list2[0]) && valid2[0]) | ((list1[1] == list2[1]) && valid2[1]) | ((list1[1] == list2[2]) && valid2[2]) | ((list1[1] == list2[3]) && valid2[3]));
    assign include1_2 = valid1[2] & ~(((list1[2] == list2[0]) && valid2[0]) | ((list1[2] == list2[1]) && valid2[1]) | ((list1[2] == list2[2]) && valid2[2]) | ((list1[2] == list2[3]) && valid2[3]));
    assign include1_3 = valid1[3] & ~(((list1[3] == list2[0]) && valid2[0]) | ((list1[3] == list2[1]) && valid2[1]) | ((list1[3] == list2[2]) && valid2[2]) | ((list1[3] == list2[3]) && valid2[3]));
    assign include2_0 = valid2[0] & ~(((list2[0] == list1[0]) && valid1[0]) | ((list2[0] == list1[1]) && valid1[1]) | ((list2[0] == list1[2]) && valid1[2]) | ((list2[0] == list1[3]) && valid1[3]));
    assign include2_1 = valid2[1] & ~(((list2[1] == list1[0]) && valid1[0]) | ((list2[1] == list1[1]) && valid1[1]) | ((list2[1] == list1[2]) && valid1[2]) | ((list2[1] == list1[3]) && valid1[3]));
    assign include2_2 = valid2[2] & ~(((list2[2] == list1[0]) && valid1[0]) | ((list2[2] == list1[1]) && valid1[1]) | ((list2[2] == list1[2]) && valid1[2]) | ((list2[2] == list1[3]) && valid1[3]));
    assign include2_3 = valid2[3] & ~(((list2[3] == list1[0]) && valid1[0]) | ((list2[3] == list1[1]) && valid1[1]) | ((list2[3] == list1[2]) && valid1[2]) | ((list2[3] == list1[3]) && valid1[3]));
    // Count number of results
    wire [7:0] include_vec;
    assign include_vec = {include1_0, include1_1, include1_2, include1_3, include2_0, include2_1, include2_2, include2_3};
    assign size = $countones(include_vec);
    // Pack results: first list1 differences, then list2 differences
    always_comb begin
        for (int i = 0; i < 8; i++) result[i] = 4'b0;
        int idx = 0;
        if (include1_0) result[idx++] = list1[0];
        if (include1_1) result[idx++] = list1[1];
        if (include1_2) result[idx++] = list1[2];
        if (include1_3) result[idx++] = list1[3];
        if (include2_0) result[idx++] = list2[0];
        if (include2_1) result[idx++] = list2[1];
        if (include2_2) result[idx++] = list2[2];
        if (include2_3) result[idx++] = list2[3];
    end
endmodule