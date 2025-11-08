module TopModule(
    input reg [99:0] a,
    input reg [99:0] b,
    input reg sel,
    output [99:0] out
);
assign out = sel ? b : a;
endmodule