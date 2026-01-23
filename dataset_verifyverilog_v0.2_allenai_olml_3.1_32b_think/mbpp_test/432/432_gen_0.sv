module trapezium_median(
    input [31:0] base1,
    input [31:0] base2,
    output [31:0] median
);
wire [31:0] sum;
assign sum = base1 + base2;
assign median = sum >> 1;
endmodule