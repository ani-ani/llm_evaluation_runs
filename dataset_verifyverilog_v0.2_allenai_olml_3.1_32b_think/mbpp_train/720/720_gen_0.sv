module add_dict_to_tuple (
    input [7:0] tuple_data [0:2],
    input [2:0] tuple_len,
    input [7:0] dict_keys [0:2],
    input [7:0] dict_vals [0:2],
    input [2:0] dict_len,
    output reg [63:0] result
);
assign result = {tuple_data[0], tuple_data[1], tuple_data[2], dict_vals[0], dict_vals[1], dict_vals[2]};
endmodule