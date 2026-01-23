module parabola_directrix (
    input [15:0] a,
    input [15:0] b,
    input [15:0] c,
    output [31:0] directrix
);

    wire [31:0] b_squared;
    wire [31:0] b_squared_plus_1;
    wire [31:0] temp;

    assign b_squared = b * b;
    assign b_squared_plus_1 = b_squared + 1;
    assign temp = b_squared_plus_1 * (a << 2);
    assign directrix = c - temp;

endmodule