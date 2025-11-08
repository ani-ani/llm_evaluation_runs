module TopModule(
    input reg [99:0] in,
    output [99:0] out
);
    assign out = {<<{in}};
endmodule