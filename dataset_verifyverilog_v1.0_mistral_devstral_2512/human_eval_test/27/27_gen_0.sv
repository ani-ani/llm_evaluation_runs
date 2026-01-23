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

    assign result_0 = ((char_0 >= 8'h41 && char_0 <= 8'h5A) || (char_0 >= 8'h61 && char_0 <= 8'h7A)) ? (char_0 ^ 8'h20) : char_0;
    assign result_1 = ((char_1 >= 8'h41 && char_1 <= 8'h5A) || (char_1 >= 8'h61 && char_1 <= 8'h7A)) ? (char_1 ^ 8'h20) : char_1;
    assign result_2 = ((char_2 >= 8'h41 && char_2 <= 8'h5A) || (char_2 >= 8'h61 && char_2 <= 8'h7A)) ? (char_2 ^ 8'h20) : char_2;
    assign result_3 = ((char_3 >= 8'h41 && char_3 <= 8'h5A) || (char_3 >= 8'h61 && char_3 <= 8'h7A)) ? (char_3 ^ 8'h20) : char_3;
    assign result_4 = ((char_4 >= 8'h41 && char_4 <= 8'h5A) || (char_4 >= 8'h61 && char_4 <= 8'h7A)) ? (char_4 ^ 8'h20) : char_4;
    assign result_5 = ((char_5 >= 8'h41 && char_5 <= 8'h5A) || (char_5 >= 8'h61 && char_5 <= 8'h7A)) ? (char_5 ^ 8'h20) : char_5;
    assign result_6 = ((char_6 >= 8'h41 && char_6 <= 8'h5A) || (char_6 >= 8'h61 && char_6 <= 8'h7A)) ? (char_6 ^ 8'h20) : char_6;
    assign result_7 = ((char_7 >= 8'h41 && char_7 <= 8'h5A) || (char_7 >= 8'h61 && char_7 <= 8'h7A)) ? (char_7 ^ 8'h20) : char_7;

endmodule