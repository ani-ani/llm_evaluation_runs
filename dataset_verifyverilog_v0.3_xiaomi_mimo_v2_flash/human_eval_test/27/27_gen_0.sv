module flip_case(
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    output [7:0] result_0,
    output [7:0] result_1,
    output [7:0] result_2,
    output [7:0] result_3,
    output [7:0] result_4,
    output [7:0] result_5,
    output [7:0] result_6,
    output [7:0] result_7
);

    // Character 0 processing
    wire is_upper_0 = (char_0 >= 8'h41) && (char_0 <= 8'h5A);
    wire is_lower_0 = (char_0 >= 8'h61) && (char_0 <= 8'h7A);
    assign result_0 = (is_upper_0 || is_lower_0) ? (char_0 ^ 8'h20) : char_0;

    // Character 1 processing
    wire is_upper_1 = (char_1 >= 8'h41) && (char_1 <= 8'h5A);
    wire is_lower_1 = (char_1 >= 8'h61) && (char_1 <= 8'h7A);
    assign result_1 = (is_upper_1 || is_lower_1) ? (char_1 ^ 8'h20) : char_1;

    // Character 2 processing
    wire is_upper_2 = (char_2 >= 8'h41) && (char_2 <= 8'h5A);
    wire is_lower_2 = (char_2 >= 8'h61) && (char_2 <= 8'h7A);
    assign result_2 = (is_upper_2 || is_lower_2) ? (char_2 ^ 8'h20) : char_2;

    // Character 3 processing
    wire is_upper_3 = (char_3 >= 8'h41) && (char_3 <= 8'h5A);
    wire is_lower_3 = (char_3 >= 8'h61) && (char_3 <= 8'h7A);
    assign result_3 = (is_upper_3 || is_lower_3) ? (char_3 ^ 8'h20) : char_3;

    // Character 4 processing
    wire is_upper_4 = (char_4 >= 8'h41) && (char_4 <= 8'h5A);
    wire is_lower_4 = (char_4 >= 8'h61) && (char_4 <= 8'h7A);
    assign result_4 = (is_upper_4 || is_lower_4) ? (char_4 ^ 8'h20) : char_4;

    // Character 5 processing
    wire is_upper_5 = (char_5 >= 8'h41) && (char_5 <= 8'h5A);
    wire is_lower_5 = (char_5 >= 8'h61) && (char_5 <= 8'h7A);
    assign result_5 = (is_upper_5 || is_lower_5) ? (char_5 ^ 8'h20) : char_5;

    // Character 6 processing
    wire is_upper_6 = (char_6 >= 8'h41) && (char_6 <= 8'h5A);
    wire is_lower_6 = (char_6 >= 8'h61) && (char_6 <= 8'h7A);
    assign result_6 = (is_upper_6 || is_lower_6) ? (char_6 ^ 8'h20) : char_6;

    // Character 7 processing
    wire is_upper_7 = (char_7 >= 8'h41) && (char_7 <= 8'h5A);
    wire is_lower_7 = (char_7 >= 8'h61) && (char_7 <= 8'h7A);
    assign result_7 = (is_upper_7 || is_lower_7) ? (char_7 ^ 8'h20) : char_7;

endmodule