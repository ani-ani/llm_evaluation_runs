module palindrome_checker (
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    input [3:0] valid_count,
    output reg is_palindrome
);

always @(*) begin
    is_palindrome = 1'b0;
    case (valid_count)
        0: is_palindrome = 1'b1;
        1: is_palindrome = 1'b1;
        2: is_palindrome = (char_0 == char_1);
        3: is_palindrome = (char_0 == char_2);
        4: is_palindrome = (char_0 == char_3) && (char_1 == char_2);
        5: is_palindrome = (char_0 == char_4) && (char_1 == char_3);
        6: is_palindrome = (char_0 == char_5) && (char_1 == char_4) && (char_2 == char_3);
        7: is_palindrome = (char_0 == char_6) && (char_1 == char_5) && (char_2 == char_4);
        8: is_palindrome = (char_0 == char_7) && (char_1 == char_6) && (char_2 == char_5) && (char_3 == char_4);
        default: is_palindrome = 1'b0;
    endcase
end

endmodule