module tuple_size_calculator (
     input [31:0] tuple_data,
     output [7:0] byte_size
);
     assign byte_size = 8'd4;
endmodule