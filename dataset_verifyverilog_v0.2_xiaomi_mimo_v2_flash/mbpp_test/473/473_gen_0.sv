module tuple_intersection (
    input  [7:0] in1_0, in1_1,
    input  [7:0] in1_2, in1_3,
    input  [7:0] in1_4, in1_5,
    input  [7:0] in1_6, in1_7,
    input  [7:0] in2_0, in2_1,
    input  [7:0] in2_2, in2_3,
    input  [7:0] in2_4, in2_5,
    input  [7:0] in2_6, in2_7,
    output reg [3:0] match_mask
);

    // Internal signals to store sorted tuples
    // list1_min[i] and list1_max[i] for tuple i of list 1
    reg [7:0] list1_min [0:3];
    reg [7:0] list1_max [0:3];
    // list2_min[j] and list2_max[j] for tuple j of list 2
    reg [7:0] list2_min [0:3];
    reg [7:0] list2_max [0:3];

    // Step 1: Sort Tuples
    // Tuple 0 of List 1
    always @(*) begin
        if (in1_0 < in1_1) begin
            list1_min[0] = in1_0;
            list1_max[0] = in1_1;
        end else begin
            list1_min[0] = in1_1;
            list1_max[0] = in1_0;
        end
    end

    // Tuple 1 of List 1
    always @(*) begin
        if (in1_2 < in1_3) begin
            list1_min[1] = in1_2;
            list1_max[1] = in1_3;
        end else begin
            list1_min[1] = in1_3;
            list1_max[1] = in1_2;
        end
    end

    // Tuple 2 of List 1
    always @(*) begin
        if (in1_4 < in1_5) begin
            list1_min[2] = in1_4;
            list1_max[2] = in1_5;
        end else begin
            list1_min[2] = in1_5;
            list1_max[2] = in1_4;
        end
    end

    // Tuple 3 of List 1
    always @(*) begin
        if (in1_6 < in1_7) begin
            list1_min[3] = in1_6;
            list1_max[3] = in1_7;
        end else begin
            list1_min[3] = in1_7;
            list1_max[3] = in1_6;
        end
    end

    // Tuple 0 of List 2
    always @(*) begin
        if (in2_0 < in2_1) begin
            list2_min[0] = in2_0;
            list2_max[0] = in2_1;
        end else begin
            list2_min[0] = in2_1;
            list2_max[0] = in2_0;
        end
    end

    // Tuple 1 of List 2
    always @(*) begin
        if (in2_2 < in2_3) begin
            list2_min[1] = in2_2;
            list2_max[1] = in2_3;
        end else begin
            list2_min[1] = in2_3;
            list2_max[1] = in2_2;
        end
    end

    // Tuple 2 of List 2
    always @(*) begin
        if (in2_4 < in2_5) begin
            list2_min[2] = in2_4;
            list2_max[2] = in2_5;
        end else begin
            list2_min[2] = in2_5;
            list2_max[2] = in2_4;
        end
    end

    // Tuple 3 of List 2
    always @(*) begin
        if (in2_6 < in2_7) begin
            list2_min[3] = in2_6;
            list2_max[3] = in2_7;
        end else begin
            list2_min[3] = in2_7;
            list2_max[3] = in2_6;
        end
    end

    // Step 2 & 3: Parallel Matching and Aggregation
    always @(*) begin
        // Match for List1 Tuple 0
        match_mask[0] = 
            ((list1_min[0] == list2_min[0]) && (list1_max[0] == list2_max[0])) ||
            ((list1_min[0] == list2_min[1]) && (list1_max[0] == list2_max[1])) ||
            ((list1_min[0] == list2_min[2]) && (list1_max[0] == list2_max[2])) ||
            ((list1_min[0] == list2_min[3]) && (list1_max[0] == list2_max[3]));

        // Match for List1 Tuple 1
        match_mask[1] = 
            ((list1_min[1] == list2_min[0]) && (list1_max[1] == list2_max[0])) ||
            ((list1_min[1] == list2_min[1]) && (list1_max[1] == list2_max[1])) ||
            ((list1_min[1] == list2_min[2]) && (list1_max[1] == list2_max[2])) ||
            ((list1_min[1] == list2_min[3]) && (list1_max[1] == list2_max[3]));

        // Match for List1 Tuple 2
        match_mask[2] = 
            ((list1_min[2] == list2_min[0]) && (list1_max[2] == list2_max[0])) ||
            ((list1_min[2] == list2_min[1]) && (list1_max[2] == list2_max[1])) ||
            ((list1_min[2] == list2_min[2]) && (list1_max[2] == list2_max[2])) ||
            ((list1_min[2] == list2_min[3]) && (list1_max[2] == list2_max[3]));

        // Match for List1 Tuple 3
        match_mask[3] = 
            ((list1_min[3] == list2_min[0]) && (list1_max[3] == list2_max[0])) ||
            ((list1_min[3] == list2_min[1]) && (list1_max[3] == list2_max[1])) ||
            ((list1_min[3] == list2_min[2]) && (list1_max[3] == list2_max[2])) ||
            ((list1_min[3] == list2_min[3]) && (list1_max[3] == list2_max[3]));
    end

endmodule