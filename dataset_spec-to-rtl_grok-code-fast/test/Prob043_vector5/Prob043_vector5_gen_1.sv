module TopModule (
  input a,
  input b,
  input c,
  input d,
  input e,
  output [24:0] out
);
  wire [0:4] ins;
  assign ins[0] = a;
  assign ins[1] = b;
  assign ins[2] = c;
  assign ins[3] = d;
  assign ins[4] = e;
  
  generate
    genvar xx, yy;
    for (xx = 0; xx < 5; xx = xx + 1) begin : xx_gen
      for (yy = 0; yy < 5; yy = yy + 1) begin : yy_gen
        assign out[24 - (5*xx + yy)] = ~(ins[xx] ^ ins[yy]);
      end
    end
  endgenerate
  
endmodule