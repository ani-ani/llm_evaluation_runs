module string_encrypt(
  input [127:0] data_in,
  input [3:0] length,
  output [127:0] data_out
);
  genvar i;
  generate
    for (i=0; i<16; i=i+1) begin : encrypt_loop
      assign data_out[127-8*i -:8] = (i < length) ? (data_in[127-8*i -:8] + 4) : data_in[127-8*i -:8];
    end
  endgenerate
endmodule