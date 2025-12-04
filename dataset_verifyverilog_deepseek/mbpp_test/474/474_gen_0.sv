module char_replacer(input [127:0] str_in, input [7:0] ch, input [7:0] newch, output [127:0] str_out);
  genvar i;
  generate
    for (i=0; i<16; i=i+1) begin : replace_loop
      assign str_out[i*8 +:8] = (str_in[i*8 +:8] == ch) ? newch : str_in[i*8 +:8];
    end
  endgenerate
endmodule