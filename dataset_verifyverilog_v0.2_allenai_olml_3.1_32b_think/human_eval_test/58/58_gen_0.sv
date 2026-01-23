module common_elements (
    input [7:0] list1 [0:7],
    input [7:0] list2 [0:7],
    output reg [7:0] result [0:7],
    output reg [3:0] count
);

    // Match computation for each element in list1
    wire [7:0] match [0:7];
    assign match[0] = (list1[0] == list2[0]) | (list1[0] == list2[1]) | (list1[0] == list2[2]) | (list1[0] == list2[3]) | (list1[0] == list2[4]) | (list1[0] == list2[5]) | (list1[0] == list2[6]) | (list1[0] == list2[7]);
    assign match[1] = (list1[1] == list2[0]) | (list1[1] == list2[1]) | (list1[1] == list2[2]) | (list1[1] == list2[3]) | (list1[1] == list2[4]) | (list1[1] == list2[5]) | (list1[1] == list2[6]) | (list1[1] == list2[7]);
    assign match[2] = (list1[2] == list2[0]) | (list1[2] == list2[1]) | (list1[2] == list2[2]) | (list1[2] == list2[3]) | (list1[2] == list2[4]) | (list1[2] == list2[5]) | (list1[2] == list2[6]) | (list1[2] == list2[7]);
    assign match[3] = (list1[3] == list2[0]) | (list1[3] == list2[1]) | (list1[3] == list2[2]) | (list1[3] == list2[3]) | (list1[3] == list2[4]) | (list1[3] == list2[5]) | (list1[3] == list2[6]) | (list1[3] == list2[7]);
    assign match[4] = (list1[4] == list2[0]) | (list1[4] == list2[1]) | (list1[4] == list2[2]) | (list1[4] == list2[3]) | (list1[4] == list2[4]) | (list1[4] == list2[5]) | (list1[4] == list2[6]) | (list1[4] == list2[7]);
    assign match[5] = (list1[5] == list2[0]) | (list1[5] == list2[1]) | (list1[5] == list2[2]) | (list1[5] == list2[3]) | (list1[5] == list2[4]) | (list1[5] == list2[5]) | (list1[5] == list2[6]) | (list1[5] == list2[7]);
    assign match[6] = (list1[6] == list2[0]) | (list1[6] == list2[1]) | (list1[6] == list2[2]) | (list1[6] == list2[3]) | (list1[6] == list2[4]) | (list1[6] == list2[5]) | (list1[6] == list2[6]) | (list1[6] == list2[7]);
    assign match[7] = (list1[7] == list2[0]) | (list1[7] == list2[1]) | (list1[7] == list2[2]) | (list1[7] == list2[3]) | (list1[7] == list2[4]) | (list1[7] == list2[5]) | (list1[7] == list2[6]) | (list1[7] == list2[7]);

    // Unique element detection
    wire [7:0] unique [0:7];
    assign unique[0] = match[0];
    assign unique[1] = match[1] & ! (match[0] & (list1[0] == list1[1]));
    assign unique[2] = match[2] & ! ( (match[0] & (list1[0] == list1[2])) | (match[1] & (list1[1] == list1[2])) );
    assign unique[3] = match[3] & ! ( (match[0] & (list1[0] == list1[3])) | (match[1] & (list1[1] == list1[3])) | (match[2] & (list1[2] == list1[3])) );
    assign unique[4] = match[4] & ! ( (match[0] & (list1[0] == list1[4])) | (match[1] & (list1[1] == list1[4])) | (match[2] & (list1[2] == list1[4])) | (match[3] & (list1[3] == list1[4])) );
    assign unique[5] = match[5] & ! ( (match[0] & (list1[0] == list1[5])) | (match[1] & (list1[1] == list1[5])) | (match[2] & (list1[2] == list1[5])) | (match[3] & (list1[3] == list1[5])) | (match[4] & (list1[4] == list1[5])) );
    assign unique[6] = match[6] & ! ( (match[0] & (list1[0] == list1[6])) | (match[1] & (list1[1] == list1[6])) | (match[2] & (list1[2] == list1[6])) | (match[3] & (list1[3] == list1[6])) | (match[4] & (list1[4] == list1[6])) | (match[5] & (list1[5] == list1[6])) );
    assign unique[7] = match[7] & ! ( (match[0] & (list1[0] == list1[7])) | (match[1] & (list1[1] == list1[7])) | (match[2] & (list1[2] == list1[7])) | (match[3] & (list1[3] == list1[7])) | (match[4] & (list1[4] == list1[7])) | (match[5] & (list1[5] == list1[7])) | (match[6] & (list1[6] == list1[7])) );

    // Cumulative unique count
    wire [3:0] cnt_unique [0:7];
    assign cnt_unique[0] = unique[0] ? 1 : 0;
    assign cnt_unique[1] = cnt_unique[0] + (unique[1] ? 1 : 0);
    assign cnt_unique[2] = cnt_unique[1] + (unique[2] ? 1 : 0);
    assign cnt_unique[3] = cnt_unique[2] + (unique[3] ? 1 : 0);
    assign cnt_unique[4] = cnt_unique[3] + (unique[4] ? 1 : 0);
    assign cnt_unique[5] = cnt_unique[4] + (unique[5] ? 1 : 0);
    assign cnt_unique[6] = cnt_unique[5] + (unique[6] ? 1 : 0);
    assign cnt_unique[7] = cnt_unique[6] + (unique[7] ? 1 : 0);

    // Temporary storage for unique elements
    wire [7:0] temp [0:7];
    assign temp[0] = (cnt_unique[0] == 1) ? list1[0] : (cnt_unique[1] == 1) ? list1[1] : (cnt_unique[2] == 1) ? list1[2] : (cnt_unique[3] == 1) ? list1[3] : (cnt_unique[4] == 1) ? list1[4] : (cnt_unique[5] == 1) ? list1[5] : (cnt_unique[6] == 1) ? list1[6] : (cnt_unique[7] == 1) ? list1[7] : 8'b0;
    assign temp[1] = (cnt_unique[0] == 2) ? list1[0] : (cnt_unique[1] == 2) ? list1[1] : (cnt_unique[2] == 2) ? list1[2] : (cnt_unique[3] == 2) ? list1[3] : (cnt_unique[4] == 2) ? list1[4] : (cnt_unique[5] == 2) ? list1[5] : (cnt_unique[6] == 2) ? list1[6] : (cnt_unique[7] == 2) ? list1[7] : 8'b0;
    assign temp[2] = (cnt_unique[0] == 3) ? list1[0] : (cnt_unique[1] == 3) ? list1[1] : (cnt_unique[2] == 3) ? list1[2] : (cnt_unique[3] == 3) ? list1[3] : (cnt_unique[4] == 3) ? list1[4] : (cnt_unique[5] == 3) ? list1[5] : (cnt_unique[6] == 3) ? list1[6] : (cnt_unique[7] == 3) ? list1[7] : 8'b0;
    assign temp[3] = (cnt_unique[0] == 4) ? list1[0] : (cnt_unique[1] == 4) ? list1[1] : (cnt_unique[2] == 4) ? list1[2] : (cnt_unique[3] == 4) ? list1[3] : (cnt_unique[4] == 4) ? list1[4] : (cnt_unique[5] == 4) ? list1[5] : (cnt_unique[6] == 4) ? list1[6] : (cnt_unique[7] == 4) ? list1[7] : 8'b0;
    assign temp[4] = (cnt_unique[0] == 5) ? list1[0] : (cnt_unique[1] == 5) ? list1[1] : (cnt_unique[2] == 5) ? list1[2] : (cnt_unique[3] == 5) ? list1[3] : (cnt_unique[4] == 5) ? list1[4] : (cnt_unique[5] == 5) ? list1[5] : (cnt_unique[6] == 5) ? list1[6] : (cnt_unique[7] == 5) ? list1[7] : 8'b0;
    assign temp[5] = (cnt_unique[0] == 6) ? list1[0] : (cnt_unique[1] == 6) ? list1[1] : (cnt_unique[2] == 6) ? list1[2] : (cnt_unique[3] == 6) ? list1[3] : (cnt_unique[4] == 6) ? list1[4] : (cnt_unique[5] == 6) ? list1[5] : (cnt_unique[6] == 6) ? list1[6] : (cnt_unique[7] == 6) ? list1[7] : 8'b0;
    assign temp[6] = (cnt_unique[0] == 7) ? list1[0] : (cnt_unique[1] == 7) ? list1[1] : (cnt_unique[2] == 7) ? list1[2] : (cnt_unique[3] == 7) ? list1[3] : (cnt_unique[4] == 7) ? list1[4] : (cnt_unique[5] == 7) ? list1[5] : (cnt_unique[6] == 7) ? list1[6] : (cnt_unique[7] == 7) ? list1[7] : 8'b0;
    assign temp[7] = (cnt_unique[0] == 8) ? list1[0] : (cnt_unique[1] == 8) ? list1[1] : (cnt_unique[2] == 8) ? list1[2] : (cnt_unique[3] == 8) ? list1[3] : (cnt_unique[4] == 8) ? list1[4] : (cnt_unique[5] == 8) ? list1[5] : (cnt_unique[6] == 8) ? list1[6] : (cnt_unique[7] == 8) ? list1[7] : 8'b0;

    // Output assignment
    assign count = cnt_unique[7];
    assign result = {temp[0], temp[1], temp[2], temp[3], temp[4], temp[5], temp[6], temp[7]};
endmodule