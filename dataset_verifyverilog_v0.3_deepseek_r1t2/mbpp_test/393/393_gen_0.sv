module max_length_list(
    input [7:0] arr_0_0,
    input [7:0] arr_0_1,
    input [7:0] arr_0_2,
    input [7:0] arr_0_3,
    input [7:0] arr_0_4,
    input [7:0] arr_0_5,
    input [7:0] arr_0_6,
    input [7:0] arr_0_7,
    input [7:0] arr_1_0,
    input [7:0] arr_1_1,
    input [7:0] arr_1_2,
    input [7:0] arr_1_3,
    input [7:0] arr_1_4,
    input [7:0] arr_1_5,
    input [7:0] arr_1_6,
    input [7:0] arr_1_7,
    input [7:0] arr_2_0,
    input [7:0] arr_2_1,
    input [7:0] arr_2_2,
    input [7:0] arr_2_3,
    input [7:0] arr_2_4,
    input [7:0] arr_2_5,
    input [7:0] arr_2_6,
    input [7:0] arr_2_7,
    input [7:0] arr_3_0,
    input [7:0] arr_3_1,
    input [7:0] arr_3_2,
    input [7:0] arr_3_3,
    input [7:0] arr_3_4,
    input [7:0] arr_3_5,
    input [7:0] arr_3_6,
    input [7:0] arr_3_7,
    input [7:0] arr_4_0,
    input [7:0] arr_4_1,
    input [7:0] arr_4_2,
    input [7:0] arr_4_3,
    input [7:0] arr_4_4,
    input [7:0] arr_4_5,
    input [7:0] arr_4_6,
    input [7:0] arr_4_7,
    input [2:0] len_0,
    input [2:0] len_1,
    input [2:0] len_2,
    input [2:0] len_3,
    input [2:0] len_4,
    input [2:0] num_lists,
    output reg [2:0] max_length,
    output reg [2:0] max_index,
    output reg [7:0] max_list_0,
    output reg [7:0] max_list_1,
    output reg [7:0] max_list_2,
    output reg [7:0] max_list_3,
    output reg [7:0] max_list_4,
    output reg [7:0] max_list_5,
    output reg [7:0] max_list_6,
    output reg [7:0] max_list_7
);

    reg [7:0] sublists [0:4][0:7];
    reg [2:0] lengths [0:4];

    always @(*) begin
        // Initialize internal arrays
        // Sublist 0
        sublists[0][0] = arr_0_0;
        sublists[0][1] = arr_0_1;
        sublists[0][2] = arr_0_2;
        sublists[0][3] = arr_0_3;
        sublists[0][4] = arr_0_4;
        sublists[0][5] = arr_0_5;
        sublists[0][6] = arr_0_6;
        sublists[0][7] = arr_0_7;
        
        // Sublist 1
        sublists[1][0] = arr_1_0;
        sublists[1][1] = arr_1_1;
        sublists[1][2] = arr_1_2;
        sublists[1][3] = arr_1_3;
        sublists[1][4] = arr_1_4;
        sublists[1][5] = arr_1_5;
        sublists[1][6] = arr_1_6;
        sublists[1][7] = arr_1_7;
        
        // Sublist 2
        sublists[2][0] = arr_2_0;
        sublists[2][1] = arr_2_1;
        sublists[2][2] = arr_2_2;
        sublists[2][3] = arr_2_3;
        sublists[2][4] = arr_2_4;
        sublists[2][5] = arr_2_5;
        sublists[2][6] = arr_2_6;
        sublists[2][7] = arr_2_7;
        
        // Sublist 3
        sublists[3][0] = arr_3_0;
        sublists[3][1] = arr_3_1;
        sublists[3][2] = arr_3_2;
        sublists[3][3] = arr_3_3;
        sublists[3][4] = arr_3_4;
        sublists[3][5] = arr_3_5;
        sublists[3][6] = arr_3_6;
        sublists[3][7] = arr_3_7;
        
        // Sublist 4
        sublists[4][0] = arr_4_0;
        sublists[4][1] = arr_4_1;
        sublists[4][2] = arr_4_2;
        sublists[4][3] = arr_4_3;
        sublists[4][4] = arr_4_4;
        sublists[4][5] = arr_4_5;
        sublists[4][6] = arr_4_6;
        sublists[4][7] = arr_4_7;
        
        // Length arrays
        lengths[0] = len_0;
        lengths[1] = len_1;
        lengths[2] = len_2;
        lengths[3] = len_3;
        lengths[4] = len_4;
        
        // Find maximum length
        max_length = 3'd0;
        max_index = 3'd0;
        
        if (num_lists > 3'd0 && lengths[0] > max_length) begin
            max_length = lengths[0];
            max_index = 3'd0;
        end
        
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
        
        // Output the longest list
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