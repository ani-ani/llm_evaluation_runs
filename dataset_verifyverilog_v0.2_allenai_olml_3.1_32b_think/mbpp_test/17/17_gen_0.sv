module square_perimeter(input [31:0] a, output [31:0] perimeter);
    assign perimeter = a << 2;
endmodule