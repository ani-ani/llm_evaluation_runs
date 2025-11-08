module TopModule(output [31:0] out, input [31:0] in);
  assign out = {in[7:0], in[15:8], in[23:16], in[31:24]};
endmodule