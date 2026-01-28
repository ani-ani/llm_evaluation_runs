module max_length_list(
    // Input: 2D array, 5 sublists max, each 8 elements max
    input [7:0] arr_0_0, arr_0_1, arr_0_2, arr_0_3, arr_0_4, arr_0_5, arr_0_6, arr_0_7,
    input [7:0] arr_1_0, arr_1_1, arr_1_2, arr_1_3, arr_1_4, arr_1_5, arr_1_6, arr_1_7,
    input [7:0] arr_2_0, arr_2_1, arr_2_2, arr_2_3, arr_2_4, arr_2_5, arr_2_6, arr_2_7,
    input [7:0] arr_3_0, arr_3_1, arr_3_2, arr_3_3, arr_3_4, arr_3_5, arr_3_6, arr_3_7,
    input [7:0] arr_4_0, arr_4_1, arr_4_2, arr_4_3, arr_4_4, arr_4_5, arr_4_6, arr_4_7,
    input [2:0] len_0, len_1, len_2, len_3, len_4,  // Actual lengths (1-8)
    input [2:0] num_lists,  // Number of sublists (1-5)
    
    // Output: maximum length and index of longest list
    output reg [2:0] max_length,
    output reg [2:0] max_index,
    
    // The longest list itself (8 elements, padded with zeros if shorter)
    output reg [7:0] max_list_0,
    output reg [7:0] max_list_1,
    output reg [7:0] max_list_2,
    output reg [7:0] max_list_3,
    output reg [7:0] max_list_4,
    output reg [7:0] max_list_5,
    output reg [7:0] max_list_6,
    output reg [7:0] max_list_7
);

    // Internal arrays for easier processing
    reg [7:0] sublists [0:4][0:7];
    reg [2:0] lengths [0:4];
    
    // Combinational logic block
    always @(*) begin
        // Initialize local arrays
        sublists[0][0] = arr_0_0; sublists[0][1] = arr_0_1; sublists[0][2] = arr_0_2; sublists[0][3] = arr_0_3;
        sublists[0][4] = arr_0_4; sublists[0][5] = arr_0_5; sublists[0][6] = arr_0_6; sublists[0][7] = arr_0_7;
        sublists[1][0] = arr_1_0; sublists[1][1] = arr_1_1; sublists[1][2] = arr_1_2; sublists[1][3] = arr_1_3;
        sublists[1][4] = arr_1_4; sublists[1][5] = arr_1_5; sublists[1][6] = arr_1_6; sublists[1][7] = arr_1_7;
        sublists[2][0] = arr_2_0; sublists[2][1] = arr_2_1; sublists[2][2] = arr_2_2; sublists[2][3] = arr_2_3;
        sublists[2][4] = arr_2_4; sublists[2][5] = arr_2_5; sublists[2][6] = arr_2_6; sublists[2][7] = arr_2_7;
        sublists[3][0] = arr_3_0; sublists[3][1] = arr_3_1; sublists[3][2] = arr_3_2; sublists[3][3] = arr_3_3;
        sublists[3][4] = arr_3_4; sublists[3][5] = arr_3_5; sublists[3][6] = arr_3_6; sublists[3][7] = arr_3_7;
        sublists[4][0] = arr_4_0; sublists[4][1] = arr_4_1; sublists[4][2] = arr_4_2; sublists[4][3] = arr_4_3;
        sublists[4][4] = arr_4_4; sublists[4][5] = arr_4_5; sublists[4][6] = arr_4_6; sublists[4][7] = arr_4_7;
        
        lengths[0] = len_0;
        lengths[1] = len_1;
        lengths[2] = len_2;
        lengths[3] = len_3;
        lengths[4] = len_4;
        
        // Find maximum length using comparison chain
        max_length = lengths[0];
        max_index = 3'd0;
        
        if (num_lists > 3'd1 && lengths[1] > max_length) begin
            max_length = lengths[1];
            max_index = 3'd1;
        end
        if (num_lists > 3'd2 && lengths[2] > max_length) begin
            max_length = lengths[2];
            max_index = 3'd2;
        end
        if (num_lists > 3'd3 && lengths[3] > max_length) begin
            max_length = lengths[3];
            max_index = 3'd3;
        end
        if (num_lists > 3'd4 && lengths[4] > max_length) begin
            max_length = lengths[4];
            max_index = 3'd4;
        end
        
        // Copy the selected list to output
        max_list_0 = sublists[max_index][0];
        max_list_1 = sublists[max_index][1];
        max_list_2 = sublists[max_index][2];
        max_list_3 = sublists[max_index][3];
        max_list_4 = sublists[max_index][4];
        max_list_5 = sublists[max_index][5];
        max_list_6 = sublists[max_index][6];
        max_list_7 = sublists[max_index][7];
    end

endmodule