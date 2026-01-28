module max_length_list(
    input [7:0] arr_0_0, arr_0_1, arr_0_2, arr_0_3, arr_0_4, arr_0_5, arr_0_6, arr_0_7,
    input [7:0] arr_1_0, arr_1_1, arr_1_2, arr_1_3, arr_1_4, arr_1_5, arr_1_6, arr_1_7,
    input [7:0] arr_2_0, arr_2_1, arr_2_2, arr_2_3, arr_2_4, arr_2_5, arr_2_6, arr_2_7,
    input [7:0] arr_3_0, arr_3_1, arr_3_2, arr_3_3, arr_3_4, arr_3_5, arr_3_6, arr_3_7,
    input [7:0] arr_4_0, arr_4_1, arr_4_2, arr_4_3, arr_4_4, arr_4_5, arr_4_6, arr_4_7,
    input [2:0] len_0, len_1, len_2, len_3, len_4,
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

    reg [7:0] sublists_0_0, sublists_0_1, sublists_0_2, sublists_0_3, sublists_0_4, sublists_0_5, sublists_0_6, sublists_0_7;
    reg [7:0] sublists_1_0, sublists_1_1, sublists_1_2, sublists_1_3, sublists_1_4, sublists_1_5, sublists_1_6, sublists_1_7;
    reg [7:0] sublists_2_0, sublists_2_1, sublists_2_2, sublists_2_3, sublists_2_4, sublists_2_5, sublists_2_6, sublists_2_7;
    reg [7:0] sublists_3_0, sublists_3_1, sublists_3_2, sublists_3_3, sublists_3_4, sublists_3_5, sublists_3_6, sublists_3_7;
    reg [7:0] sublists_4_0, sublists_4_1, sublists_4_2, sublists_4_3, sublists_4_4, sublists_4_5, sublists_4_6, sublists_4_7;
    reg [2:0] lengths_0, lengths_1, lengths_2, lengths_3, lengths_4;

    always @(*) begin
        sublists_0_0 = arr_0_0; sublists_0_1 = arr_0_1; sublists_0_2 = arr_0_2; sublists_0_3 = arr_0_3;
        sublists_0_4 = arr_0_4; sublists_0_5 = arr_0_5; sublists_0_6 = arr_0_6; sublists_0_7 = arr_0_7;
        sublists_1_0 = arr_1_0; sublists_1_1 = arr_1_1; sublists_1_2 = arr_1_2; sublists_1_3 = arr_1_3;
        sublists_1_4 = arr_1_4; sublists_1_5 = arr_1_5; sublists_1_6 = arr_1_6; sublists_1_7 = arr_1_7;
        sublists_2_0 = arr_2_0; sublists_2_1 = arr_2_1; sublists_2_2 = arr_2_2; sublists_2_3 = arr_2_3;
        sublists_2_4 = arr_2_4; sublists_2_5 = arr_2_5; sublists_2_6 = arr_2_6; sublists_2_7 = arr_2_7;
        sublists_3_0 = arr_3_0; sublists_3_1 = arr_3_1; sublists_3_2 = arr_3_2; sublists_3_3 = arr_3_3;
        sublists_3_4 = arr_3_4; sublists_3_5 = arr_3_5; sublists_3_6 = arr_3_6; sublists_3_7 = arr_3_7;
        sublists_4_0 = arr_4_0; sublists_4_1 = arr_4_1; sublists_4_2 = arr_4_2; sublists_4_3 = arr_4_3;
        sublists_4_4 = arr_4_4; sublists_4_5 = arr_4_5; sublists_4_6 = arr_4_6; sublists_4_7 = arr_4_7;
        
        lengths_0 = len_0;
        lengths_1 = len_1;
        lengths_2 = len_2;
        lengths_3 = len_3;
        lengths_4 = len_4;
        
        max_length = lengths_0;
        max_index = 3'd0;
        
        if (num_lists > 3'd1 && lengths_1 > max_length) begin
            max_length = lengths_1;
            max_index = 3'd1;
        end
        if (num_lists > 3'd2 && lengths_2 > max_length) begin
            max_length = lengths_2;
            max_index = 3'd2;
        end
        if (num_lists > 3'd3 && lengths_3 > max_length) begin
            max_length = lengths_3;
            max_index = 3'd3;
        end
        if (num_lists > 3'd4 && lengths_4 > max_length) begin
            max_length = lengths_4;
            max_index = 3'd4;
        end
        
        case (max_index)
            3'd0: begin
                max_list_0 = sublists_0_0;
                max_list_1 = sublists_0_1;
                max_list_2 = sublists_0_2;
                max_list_3 = sublists_0_3;
                max_list_4 = sublists_0_4;
                max_list_5 = sublists_0_5;
                max_list_6 = sublists_0_6;
                max_list_7 = sublists_0_7;
            end
            3'd1: begin
                max_list_0 = sublists_1_0;
                max_list_1 = sublists_1_1;
                max_list_2 = sublists_1_2;
                max_list_3 = sublists_1_3;
                max_list_4 = sublists_1_4;
                max_list_5 = sublists_1_5;
                max_list_6 = sublists_1_6;
                max_list_7 = sublists_1_7;
            end
            3'd2: begin
                max_list_0 = sublists_2_0;
                max_list_1 = sublists_2_1;
                max_list_2 = sublists_2_2;
                max_list_3 = sublists_2_3;
                max_list_4 = sublists_2_4;
                max_list_5 = sublists_2_5;
                max_list_6 = sublists_2_6;
                max_list_7 = sublists_2_7;
            end
            3'd3: begin
                max_list_0 = sublists_3_0;
                max_list_1 = sublists_3_1;
                max_list_2 = sublists_3_2;
                max_list_3 = sublists_3_3;
                max_list_4 = sublists_3_4;
                max_list_5 = sublists_3_5;
                max_list_6 = sublists_3_6;
                max_list_7 = sublists_3_7;
            end
            3'd4: begin
                max_list_0 = sublists_4_0;
                max_list_1 = sublists_4_1;
                max_list_2 = sublists_4_2;
                max_list_3 = sublists_4_3;
                max_list_4 = sublists_4_4;
                max_list_5 = sublists_4_5;
                max_list_6 = sublists_4_6;
                max_list_7 = sublists_4_7;
            end
            default: begin
                max_list_0 = 8'd0;
                max_list_1 = 8'd0;
                max_list_2 = 8'd0;
                max_list_3 = 8'd0;
                max_list_4 = 8'd0;
                max_list_5 = 8'd0;
                max_list_6 = 8'd0;
                max_list_7 = 8'd0;
            end
        endcase
    end

endmodule