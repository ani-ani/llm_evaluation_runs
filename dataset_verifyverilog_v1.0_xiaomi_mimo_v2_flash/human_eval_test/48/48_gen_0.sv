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

    // Internal comparison results
    reg cmp_0_7, cmp_1_6, cmp_2_5, cmp_3_4;
    reg cmp_0_6, cmp_1_5, cmp_2_4;
    reg cmp_0_5, cmp_1_4, cmp_2_3;
    reg cmp_0_4, cmp_1_3;
    reg cmp_0_3, cmp_1_2;
    reg cmp_0_2;
    reg cmp_0_1;

    // Combinational logic for comparisons
    always @(*) begin
        // Initialize all comparison results to 1
        cmp_0_7 = 1'b1;
        cmp_1_6 = 1'b1;
        cmp_2_5 = 1'b1;
        cmp_3_4 = 1'b1;
        cmp_0_6 = 1'b1;
        cmp_1_5 = 1'b1;
        cmp_2_4 = 1'b1;
        cmp_0_5 = 1'b1;
        cmp_1_4 = 1'b1;
        cmp_2_3 = 1'b1;
        cmp_0_4 = 1'b1;
        cmp_1_3 = 1'b1;
        cmp_0_3 = 1'b1;
        cmp_1_2 = 1'b1;
        cmp_0_2 = 1'b1;
        cmp_0_1 = 1'b1;

        // Perform comparisons based on length
        case (length)
            4'd0: is_palindrome = 1'b1;  // Empty string
            4'd1: is_palindrome = 1'b1;  // Single character
            4'd2: begin
                cmp_0_1 = (str_0 == str_1);
                is_palindrome = cmp_0_1;
            end
            4'd3: begin
                cmp_0_2 = (str_0 == str_2);
                is_palindrome = cmp_0_2;  // str_1 is middle, doesn't need comparison
            end
            4'd4: begin
                cmp_0_3 = (str_0 == str_3);
                cmp_1_2 = (str_1 == str_2);
                is_palindrome = cmp_0_3 && cmp_1_2;
            end
            4'd5: begin
                cmp_0_4 = (str_0 == str_4);
                cmp_1_3 = (str_1 == str_3);
                is_palindrome = cmp_0_4 && cmp_1_3;  // str_2 is middle
            end
            4'd6: begin
                cmp_0_5 = (str_0 == str_5);
                cmp_1_4 = (str_1 == str_4);
                cmp_2_3 = (str_2 == str_3);
                is_palindrome = cmp_0_5 && cmp_1_4 && cmp_2_3;
            end
            4'd7: begin
                cmp_0_6 = (str_0 == str_6);
                cmp_1_5 = (str_1 == str_5);
                cmp_2_4 = (str_2 == str_4);
                is_palindrome = cmp_0_6 && cmp_1_5 && cmp_2_4;  // str_3 is middle
            end
            4'd8: begin
                cmp_0_7 = (str_0 == str_7);
                cmp_1_6 = (str_1 == str_6);
                cmp_2_5 = (str_2 == str_5);
                cmp_3_4 = (str_3 == str_4);
                is_palindrome = cmp_0_7 && cmp_1_6 && cmp_2_5 && cmp_3_4;
            end
            default: is_palindrome = 1'b0;  // Invalid length
        endcase
    end

endmodule