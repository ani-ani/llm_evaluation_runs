module replace_char(input [7:0][7:0] str_in, input [7:0] ch, input [7:0] newch, output [7:0][7:0] str_out);
assign str_out[0] = (str_in[0] == ch) ? newch : str_in[0];
assign str_out[1] = (str_in[1] == ch) ? newch : str_in[1];
assign str_out[2] = (str_in[2] == ch) ? newch : str_in[2];
assign str_out[3] = (str_in[3] == ch) ? newch : str_in[3];
assign str_out[4] = (str_in[4] == ch) ? newch : str_in[4];
assign str_out[5] = (str_in[5] == ch) ? newch : str_in[5];
assign str_out[6] = (str_in[6] == ch) ? newch : str_in[6];
assign str_out[7] = (str_in[7] == ch) ? newch : str_in[7];
endmodule