module string_to_lower (
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    output [7:0] lower_char_0,
    output [7:0] lower_char_1,
    output [7:0] lower_char_2,
    output [7:0] lower_char_3,
    output [7:0] lower_char_4,
    output [7:0] lower_char_5,
    output [7:0] lower_char_6,
    output [7:0] lower_char_7
);

    // Function to convert a single character to lowercase
    function automatic [7:0] to_lower;
        input [7:0] char;
        begin
            if ((char >= 8'h41) && (char <= 8'h5A)) begin
                to_lower = char + 8'h20;
            end else begin
                to_lower = char;
            end
        end
    endfunction

    // Apply conversion to each character independently
    assign lower_char_0 = to_lower(char_0);
    assign lower_char_1 = to_lower(char_1);
    assign lower_char_2 = to_lower(char_2);
    assign lower_char_3 = to_lower(char_3);
    assign lower_char_4 = to_lower(char_4);
    assign lower_char_5 = to_lower(char_5);
    assign lower_char_6 = to_lower(char_6);
    assign lower_char_7 = to_lower(char_7);

endmodule