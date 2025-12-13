module array_swap_first_last(
  input  [3:0]  size,
  input  [63:0] array_in,
  output [63:0] array_out
);

  wire [2:0] last_index;
  assign last_index = size[2:0] - 3'd1;

  assign array_out[7:0]   = (size == 4'd0 || size == 4'd1) ? array_in[7:0]   : array_in[{last_index, 3'b000} +: 8];
  assign array_out[15:8]  = (size <= 4'd2 || last_index == 3'd1) ? array_in[15:8]  : array_in[15:8];
  assign array_out[23:16] = (size <= 4'd3 || last_index == 3'd2) ? array_in[23:16] : array_in[23:16];
  assign array_out[31:24] = (size <= 4'd4 || last_index == 3'd3) ? array_in[31:24] : array_in[31:24];
  assign array_out[39:32] = (size <= 4'd5 || last_index == 3'd4) ? array_in[39:32] : array_in[39:32];
  assign array_out[47:40] = (size <= 4'd6 || last_index == 3'd5) ? array_in[47:40] : array_in[47:40];
  assign array_out[55:48] = (size <= 4'd7 || last_index == 3'd6) ? array_in[55:48] : array_in[55:48];
  assign array_out[63:56] = (size <= 4'd8 && last_index == 3'd7 && size != 4'd0 && size != 4'd1) ? array_in[7:0] : array_in[63:56];

endmodule