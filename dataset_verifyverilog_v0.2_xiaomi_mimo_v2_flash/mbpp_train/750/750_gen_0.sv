module add_tuple(
    input [3:0][7:0] list_in,
    input [1:0][7:0] tuple_in,
    output [5:0][7:0] result
);

    assign result = {list_in, tuple_in};

endmodule