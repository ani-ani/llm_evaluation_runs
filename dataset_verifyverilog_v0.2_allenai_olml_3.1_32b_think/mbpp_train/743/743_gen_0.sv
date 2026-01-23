module rotate_right(input [2:0] rotate_amount, input [7:0] data_in [0:7], output [7:0] data_out [0:7]);
case(rotate_amount)
3'b000:
   data_out[0] = data_in[0];
   data_out[1] = data_in[1];
   data_out[2] = data_in[2];
   data_out[3] = data_in[3];
   data_out[4] = data_in[4];
   data_out[5] = data_in[5];
   data_out[6] = data_in[6];
   data_out[7] = data_in[7];
3'b001:
   data_out[0] = data_in[7];
   data_out[1] = data_in[0];
   data_out[2] = data_in[1];
   data_out[3] = data_in[2];
   data_out[4] = data_in[3];
   data_out[5] = data_in[4];
   data_out[6] = data_in[5];
   data_out[7] = data_in[6];
3'b010:
   data_out[0] = data_in[6];
   data_out[1] = data_in[7];
   data_out[2] = data_in[0];
   data_out[3] = data_in[1];
   data_out[4] = data_in[2];
   data_out[5] = data_in[3];
   data_out[6] = data_in[4];
   data_out[7] = data_in[5];
3'b011:
   data_out[0] = data_in[5];
   data_out[1] = data_in[6];
   data_out[2] = data_in[7];
   data_out[3] = data_in[0];
   data_out[4] = data_in[1];
   data_out[5] = data_in[2];
   data_out[6] = data_in[3];
   data_out[7] = data_in[4];
3'b100:
   data_out[0] = data_in[4];
   data_out[1] = data_in[5];
   data_out[2] = data_in[6];
   data_out[3] = data_in[7];
   data_out[4] = data_in[0];
   data_out[5] = data_in[1];
   data_out[6] = data_in[2];
   data_out[7] = data_in[3];
3'b101:
   data_out[0] = data_in[3];
   data_out[1] = data_in[4];
   data_out[2] = data_in[5];
   data_out[3] = data_in[6];
   data_out[4] = data_in[7];
   data_out[5] = data_in[0];
   data_out[6] = data_in[1];
   data_out[7] = data_in[2];
3'b110:
   data_out[0] = data_in[2];
   data_out[1] = data_in[3];
   data_out[2] = data_in[4];
   data_out[3] = data_in[5];
   data_out[4] = data_in[6];
   data_out[5] = data_in[7];
   data_out[6] = data_in[0];
   data_out[7] = data_in[1];
3'b111:
   data_out[0] = data_in[1];
   data_out[1] = data_in[2];
   data_out[2] = data_in[3];
   data_out[3] = data_in[4];
   data_out[4] = data_in[5];
   data_out[5] = data_in[6];
   data_out[6] = data_in[7];
   data_out[7] = data_in[0];
endcase
endmodule