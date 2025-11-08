module TopModule(input a,b,c,d,e, output [24:0] out);
  logic [4:0] sigs;
  assign sigs = {a,b,c,d,e};
  genvar i, j;
  generate
    for (i=0; i<5; i=i+1) begin : gen_i
      for (j=0; j<5; j=j+1) begin : gen_j
        assign out[24 - (5*i + j)] = sigs[i] ~^ sigs[j];
      end
    end
  endgenerate
endmodule