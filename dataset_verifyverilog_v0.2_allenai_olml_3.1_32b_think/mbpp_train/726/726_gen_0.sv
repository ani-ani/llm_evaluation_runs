module pairwise_mult(
input [7:0] data_in [0:7], output [15:0] data_out [0:6]
);
assign data_out[0] = data_in[0] * data_in[1];
assign data_out[1] = data_in[1] * data_in[2];
assign data_out[2] = data_in[2] * data_in[3];
assign data_out[3] = data_in[3] * data_in[4];
assign data_out[4] = data_in[4] * data_in[5];
assign data_out[5] = data_in[5] * data_in[6];
assign data_out[6] = data_in[6] * data_in[7];
endmodule