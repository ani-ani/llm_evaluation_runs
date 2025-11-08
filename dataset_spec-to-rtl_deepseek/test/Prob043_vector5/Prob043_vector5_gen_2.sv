module TopModule(input a, b, c, d, e, output [24:0] out);
  wire [4:0] sig = {a, b, c, d, e};
  genvar i, j;
  generate
    for (i = 0; i < 5; i++) begin : gen_i
      for (j = 0; j < 5; j++) begin : gen_j
        assign out[24 - (5*i + j)] = ~sig[i] ^ sig[j];
      end
    end
  endgenerate
endmodule