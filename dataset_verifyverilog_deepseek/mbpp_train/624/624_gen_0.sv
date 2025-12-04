module string_to_upper (
  input [63:0] str_in,
  output [63:0] str_out
);

  genvar i;
  generate
    for (i=0; i<8; i=i+1) begin : byte_loop
      assign str_out[i*8 +:8] = (str_in[i*8 +:8] >= 8'h61 && str_in[i*8 +:8] <= 8'h7A) ? 
                                str_in[i*8 +:8] - 8'd32 : 
                                str_in[i*8 +:8];
    end
  endgenerate
endmodule