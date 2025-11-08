module TopModule(
    output [3:0] out,
    input [1023:0] in,
    input [7:0] sel
);
    assign out = in[{sel, 2'b00} +: 4];
endmodule