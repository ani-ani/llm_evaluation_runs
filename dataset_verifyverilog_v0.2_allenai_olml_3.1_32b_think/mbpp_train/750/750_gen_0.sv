module add_tuple (
    input [3:0][7:0] list_in,
    input [1:0][7:0] tuple_in,
    output [5:0][7:0] result
);
    assign result = { list_in[0], list_in[1], list_in[2], list_in[3], tuple_in[0], tuple_in[1] };
endmodule