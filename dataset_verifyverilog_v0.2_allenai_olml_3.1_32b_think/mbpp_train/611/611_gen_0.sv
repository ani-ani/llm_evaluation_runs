module max_of_nth (
    input [1:0] column_index,
    input [2:0][2:0][7:0] matrix,
    output [7:0] max_value
);
wire [7:0] a, b, c;
assign a = matrix[0][column_index];
assign b = matrix[1][column_index];
assign c = matrix[2][column_index];
wire [7:0] max_ab;
assign max_ab = (a > b) ? a : b;
assign max_value = (max_ab > c) ? max_ab : c;
endmodule