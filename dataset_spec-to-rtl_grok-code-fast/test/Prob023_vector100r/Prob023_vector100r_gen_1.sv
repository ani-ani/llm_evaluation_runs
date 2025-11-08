module TopModule(
    input [99:0] in,
    output [99:0] out
);
    assign out = {<<1{in}};
endmodule