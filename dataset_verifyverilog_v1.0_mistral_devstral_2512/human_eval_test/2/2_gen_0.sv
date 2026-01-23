module truncate_number(
    input [31:0] number,
    output [31:0] result
);
    assign result = {16'b0, number[15:0]};
endmodule