module TopModule(
  output [1:0] pos,
  input [3:0] in
);

  assign pos = in[3] ? 2'b11 :
               in[2] ? 2'b10 :
               in[1] ? 2'b01 :
               2'b00;
endmodule