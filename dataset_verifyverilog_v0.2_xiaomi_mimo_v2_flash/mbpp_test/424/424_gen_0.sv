module extract_rear(
    input [7:0] str1,
    input [7:0] str2,
    input [7:0] str3,
    input [2:0] len1,
    input [2:0] len2,
    input [2:0] len3,
    output [7:0] rear1,
    output [7:0] rear2,
    output [7:0] rear3
);

    // Helper function to extract the last character from a string
    // String is stored in big-endian: MSB is first character
    // Length is 1-8
    function [7:0] get_last;
        input [7:0] str;
        input [2:0] len;
        begin
            // We need to index (len-1)
            // Since str[7:0] is the last character (8th pos)
            // and str[63:56] is the first character (1st pos)
            // Index i (0-based) corresponds to bits [63-i*8 : 56-i*8]
            // We want index = len - 1
            // So we shift right by (len-1) * 8, then take MSB byte
            
            // Since len is 1-8, len-1 is 0-7
            // We can use a case statement for synthesis efficiency
            case (len)
                3'd1: get_last = str[7:0];
                3'd2: get_last = str[15:8];
                3'd3: get_last = str[23:16];
                3'd4: get_last = str[31:24];
                3'd5: get_last = str[39:32];
                3'd6: get_last = str[47:40];
                3'd7: get_last = str[55:48];
                3'd0: get_last = 8'h00; // Should not happen per spec (length 1-8)
                default: get_last = 8'h00;
            endcase
        end
    endfunction

    assign rear1 = get_last(str1, len1);
    assign rear2 = get_last(str2, len2);
    assign rear3 = get_last(str3, len3);

endmodule
