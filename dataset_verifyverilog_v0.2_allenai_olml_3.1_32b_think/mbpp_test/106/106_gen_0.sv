module list_append(input [7:0] list_data [0:7], input [2:0] list_len, input [7:0] tuple_data [0:7], input [2:0] tuple_len, output [7:0] result [0:7], output [2:0] result_len);
assign result_len = (tuple_len + list_len) > 8 ? 8 : tuple_len + list_len;
generate
for (int i=0; i<8; i++) begin result[i] = (i < tuple_len) ? tuple_data[i] : (i < tuple_len + list_len) ? list_data[i - tuple_len] : 8'd0; end
endgenerate
endmodule