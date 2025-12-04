module max_length_finder(
    input  [24:0] flattened_lists, // 5 elements * 5 lists, each element 1 bit (per problem statement)
    input  [14:0] list_lengths,    // 3 bits * 5 lists
    output reg [2:0] max_length,   // max length (0-5)
    output reg [4:0] max_list,     // elements of longest list (5 elements * 1 bit)
    output reg [2:0] list_index    // index of longest list (0-4)
);

    // Extract 3-bit lengths for each of the 5 sublists
    wire [2:0] len0 = list_lengths[2:0];
    wire [2:0] len1 = list_lengths[5:3];
    wire [2:0] len2 = list_lengths[8:6];
    wire [2:0] len3 = list_lengths[11:9];
    wire [2:0] len4 = list_lengths[14:12];

    // Extract 5-bit sublists from flattened_lists
    // flattened_lists = {list4[4:0], list3[4:0], list2[4:0], list1[4:0], list0[4:0]}
    wire [4:0] list0 = flattened_lists[4:0];
    wire [4:0] list1 = flattened_lists[9:5];
    wire [4:0] list2 = flattened_lists[14:10];
    wire [4:0] list3 = flattened_lists[19:15];
    wire [4:0] list4 = flattened_lists[24:20];

    always @* begin
        // Default: choose list0
        max_length = len0;
        list_index = 3'd0;
        max_list   = list0;

        // Compare with list1
        if (len1 > max_length) begin
            max_length = len1;
            list_index = 3'd1;
            max_list   = list1;
        end

        // Compare with list2
        if (len2 > max_length) begin
            max_length = len2;
            list_index = 3'd2;
            max_list   = list2;
        end

        // Compare with list3
        if (len3 > max_length) begin
            max_length = len3;
            list_index = 3'd3;
            max_list   = list3;
        end

        // Compare with list4
        if (len4 > max_length) begin
            max_length = len4;
            list_index = 3'd4;
            max_list   = list4;
        end
    end

endmodule