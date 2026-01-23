module palindrome_checker(
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    input [2:0] valid_count,
    output reg is_palindrome
);

    always @(*) begin
        case (valid_count)
            3'd0, 3'd1: begin
                // Length 0 or 1 is always a palindrome
                is_palindrome = 1'b1;
            end
            3'd2: begin
                // Compare (0, 1)
                is_palindrome = (char_0 == char_1);
            end
            3'd3: begin
                // Compare (0, 2), ignore 1
                is_palindrome = (char_0 == char_2);
            end
            3'd4: begin
                // Compare (0, 3), (1, 2)
                is_palindrome = (char_0 == char_3) && (char_1 == char_2);
            end
            3'd5: begin
                // Compare (0, 4), (1, 3), ignore 2
                is_palindrome = (char_0 == char_4) && (char_1 == char_3);
            end
            3'd6: begin
                // Compare (0, 5), (1, 4), (2, 3)
                is_palindrome = (char_0 == char_5) && (char_1 == char_4) && (char_2 == char_3);
            end
            3'd7: begin
                // Compare (0, 6), (1, 5), (2, 4), ignore 3
                is_palindrome = (char_0 == char_6) && (char_1 == char_5) && (char_2 == char_4);
            end
            3'd8: begin
                // Compare (0, 7), (1, 6), (2, 5), (3, 4)
                is_palindrome = (char_0 == char_7) && (char_1 == char_6) && (char_2 == char_5) && (char_3 == char_4);
            end
            default: begin
                // Should not occur, default to 1 (safe) or 0 depending on strictness. 
                // Based on requirements, 0-8 are valid. Defaulting to 1 for safety if undefined state occurs.
                is_palindrome = 1'b1;
            end
        endcase
    end

endmodule