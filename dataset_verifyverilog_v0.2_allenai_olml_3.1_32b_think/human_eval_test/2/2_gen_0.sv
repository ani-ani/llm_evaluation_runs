module truncate_number (
    input [31:0] number_in,
    output [31:0] decimal_out
);
assign decimal_out = number_in & 32'h0000FFFF;
endmodule