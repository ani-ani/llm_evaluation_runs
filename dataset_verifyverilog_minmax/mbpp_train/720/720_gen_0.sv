module add_dict_to_tuple(
    input reg [23:0] tuple_data,
    input reg [71:0] dict_data,
    output wire [127:0] result
);
    // Concatenate: zero padding, dictionary, tuple data
    assign result = {32'b0, dict_data[71:0], tuple_data[23:0]};
endmodule