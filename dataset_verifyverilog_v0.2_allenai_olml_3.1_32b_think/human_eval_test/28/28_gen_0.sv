module concatenate (
    input [4:0][7:0] strings,
    input [2:0] count,
    output reg [39:0] result,
    output reg [2:0] length
);
assign length = count;
assign result = { (count >=1 ? strings[0] : 8'b0), (count >=2 ? strings[1] : 8'b0), (count >=3 ? strings[2] : 8'b0), (count >=4 ? strings[3] : 8'b0), (count >=5 ? strings[4] : 8'b0) };
endmodule