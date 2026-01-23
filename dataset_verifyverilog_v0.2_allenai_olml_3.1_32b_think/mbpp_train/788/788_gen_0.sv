module new_tuple (
    input [7:0][7:0] list_data,
    input [2:0] list_length,
    input [7:0] append_str,
    output reg [8:0][7:0] result_tuple,
    output reg [2:0] result_length
);
assign result_length = list_length + 1;
assign result_tuple[0][7:0] = (0 < list_length) ? list_data[0][7:0] : (0 == list_length) ? append_str : 8'b0;
assign result_tuple[1][7:0] = (1 < list_length) ? list_data[1][7:0] : (1 == list_length) ? append_str : 8'b0;
assign result_tuple[2][7:0] = (2 < list_length) ? list_data[2][7:0] : (2 == list_length) ? append_str : 8'b0;
assign result_tuple[3][7:0] = (3 < list_length) ? list_data[3][7:0] : (3 == list_length) ? append_str : 8'b0;
assign result_tuple[4][7:0] = (4 < list_length) ? list_data[4][7:0] : (4 == list_length) ? append_str : 8'b0;
assign result_tuple[5][7:0] = (5 < list_length) ? list_data[5][7:0] : (5 == list_length) ? append_str : 8'b0;
assign result_tuple[6][7:0] = (6 < list_length) ? list_data[6][7:0] : (6 == list_length) ? append_str : 8'b0;
assign result_tuple[7][7:0] = (7 < list_length) ? list_data[7][7:0] : (7 == list_length) ? append_str : 8'b0;
assign result_tuple[8][7:0] = (8 < list_length) ? list_data[8][7:0] : (8 == list_length) ? append_str : 8'b0;
endmodule