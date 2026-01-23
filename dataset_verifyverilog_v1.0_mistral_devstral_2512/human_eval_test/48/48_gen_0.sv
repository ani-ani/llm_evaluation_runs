module palindrome_check(
    input [7:0] str_0,
    input [7:0] str_1,
    input [7:0] str_2,
    input [7:0] str_3,
    input [7:0] str_4,
    input [7:0] str_5,
    input [7:0] str_6,
    input [7:0] str_7,
    input [3:0] length,
    output reg is_palindrome
);

    always @(*) begin
        is_palindrome = 1'b0;
        case (length)
            4'd0: is_palindrome = 1'b1;
            4'd1: is_palindrome = 1'b1;
            4'd2: is_palindrome = (str_0 == str_1);
            4'd3: is_palindrome = (str_0 == str_2);
            4'd4: is_palindrome = (str_0 == str_3) && (str_1 == str_2);
            4'd5: is_palindrome = (str_0 == str_4) && (str_1 == str_3);
            4'd6: is_palindrome = (str_0 == str_5) && (str_1 == str_4) && (str_2 == str_3);
            4'd7: is_palindrome = (str_0 == str_6) && (str_1 == str_5) && (str_2 == str_4);
            4'd8: is_palindrome = (str_0 == str_7) && (str_1 == str_6) && (str_2 == str_5) && (str_3 == str_4);
            default: is_palindrome = 1'b0;
        endcase
    end
endmodule