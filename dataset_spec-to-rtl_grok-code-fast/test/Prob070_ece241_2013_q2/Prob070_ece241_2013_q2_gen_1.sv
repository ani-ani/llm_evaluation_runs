module TopModule(input a, b, c, d, output out_sop, out_pos);
  assign out_sop = (~a & ~b & c & ~d) | (~a & b & c & d) | (a & b & c & d);
  assign out_pos = c;
endmodule