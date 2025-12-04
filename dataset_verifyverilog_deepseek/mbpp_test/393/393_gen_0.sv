module max_length_finder (
    input [124:0] flattened_lists,
    input [14:0] list_lengths,
    output reg [2:0] max_length,
    output reg [24:0] max_list,
    output reg [2:0] list_index
);

// Extract lengths
wire [2:0] len0 = list_lengths[2:0];
wire [2:0] len1 = list_lengths[5:3];
wire [2:0] len2 = list_lengths[8:6];
wire [2:0] len3 = list_lengths[11:9];
wire [2:0] len4 = list_lengths[14:12];

// Extract sublists
wire [24:0] list0 = flattened_lists[24:0];
wire [24:0] list1 = flattened_lists[49:25];
wire [24:0] list2 = flattened_lists[74:50];
wire [24:0] list3 = flattened_lists[99:75];
wire [24:0] list4 = flattened_lists[124:100];

always_comb begin
    // Initialize with list0
    max_length = len0;
    max_list = list0;
    list_index = 3'd0;

    // Compare with list1
    if (len1 > max_length) begin
        max_length = len1;
        max_list = list1;
        list_index = 3'd1;
    end

    // Compare with list2
    if (len2 > max_length) begin
        max_length = len2;
        max_list = list2;
        list_index = 3'd2;
    end

    // Compare with list3
    if (len3 > max_length) begin
        max_length = len3;
        max_list = list3;
        list_index = 3'd3;
    end

    // Compare with list4
    if (len4 > max_length) begin
        max_length = len4;
        max_list = list4;
        list_index = 3'd4;
    end
end

endmodule