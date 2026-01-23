module tuple_to_int (
    input [3:0] digit_0,
    input [3:0] digit_1,
    input [3:0] digit_2,
    input [3:0] digit_3,
    input [3:0] digit_4,
    input [3:0] digit_5,
    input [3:0] digit_6,
    input [3:0] digit_7,
    output [31:0] result
);

    wire [31:0] term0;
    wire [31:0] term1;
    wire [31:0] term2;
    wire [31:0] term3;
    wire [31:0] term4;
    wire [31:0] term5;
    wire [31:0] term6;
    wire [31:0] term7;

    // Calculate each term: digit * 10^position
    // 10^0 = 1
    assign term0 = {28'b0, digit_0};
    // 10^1 = 10
    assign term1 = {28'b0, digit_1} * 10;
    // 10^2 = 100
    assign term2 = {28'b0, digit_2} * 100;
    // 10^3 = 1000
    assign term3 = {28'b0, digit_3} * 1000;
    // 10^4 = 10000
    assign term4 = {28'b0, digit_4} * 10000;
    // 10^5 = 100000
    assign term5 = {28'b0, digit_5} * 100000;
    // 10^6 = 1000000
    assign term6 = {28'b0, digit_6} * 1000000;
    // 10^7 = 10000000
    assign term7 = {28'b0, digit_7} * 10000000;

    // Sum all terms
    assign result = term0 + term1 + term2 + term3 + term4 + term5 + term6 + term7;

endmodule}