module max_length_finder(
    input [3:0][2:0] lengths,
    input [3:0][7:0][7:0] lists,
    output [2:0] max_length,
    output [7:0][7:0] max_list,
    output valid
);

    wire [1:0] max_index;
    wire [2:0] len_0 = lengths[0];
    wire [2:0] len_1 = lengths[1];
    wire [2:0] len_2 = lengths[2];
    wire [2:0] len_3 = lengths[3];

    // Priority encoder for max index
    assign max_index = (len_0 >= len_1 && len_0 >= len_2 && len_0 >= len_3) ? 2'd0 :
                      (len_1 >= len_0 && len_1 >= len_2 && len_1 >= len_3) ? 2'd1 :
                      (len_2 >= len_0 && len_2 >= len_1 && len_2 >= len_3) ? 2'd2 :
                      2'd3;

    // Select max list
    assign max_list = (max_index == 2'd0) ? lists[0] :
                     (max_index == 2'd1) ? lists[1] :
                     (max_index == 2'd2) ? lists[2] :
                     lists[3];

    // Output max length
    assign max_length = (max_index == 2'd0) ? len_0 :
                       (max_index == 2'd1) ? len_1 :
                       (max_index == 2'd2) ? len_2 :
                       len_3;

    // Valid signal
    assign valid = (len_0 > 0) || (len_1 > 0) || (len_2 > 0) || (len_3 > 0);

endmodule