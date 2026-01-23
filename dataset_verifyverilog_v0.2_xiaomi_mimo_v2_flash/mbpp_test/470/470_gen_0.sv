module pairwise_add (
    input [7:0] in0,
    input [7:0] in1,
    input [7:0] in2,
    input [7:0] in3,
    input [7:0] in4,
    output [7:0] out0,
    output [7:0] out1,
    output [7:0] out2,
    output [7:0] out3
);

    assign out0 = in0 + in1;
    assign out1 = in1 + in2;
    assign out2 = in2 + in3;
    assign out3 = in3 + in4;

endmodule