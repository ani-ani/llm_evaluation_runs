module extract_rear (
    input [31:0] str1,
    input [31:0] str2,
    input [31:0] str3,
    input [2:0] len1,
    input [2:0] len2,
    input [2:0] len3,
    output [7:0] rear1,
    output [7:0] rear2,
    output [7:0] rear3
);
assign rear1 = str1 >> (len1-1)*8 & 8'hFF;
assign rear2 = str2 >> (len2-1)*8 & 8'hFF;
assign rear3 = str3 >> (len3-1)*8 & 8'hFF;
endmodule