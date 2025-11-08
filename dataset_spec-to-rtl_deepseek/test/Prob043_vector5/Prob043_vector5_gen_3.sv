module TopModule(input a, b, c, d, e, output [24:0] out);
  wire [4:0] inputs = {a, b, c, d, e};
  generate
    for (genvar i = 0; i < 5; i++) begin : g_i
      for (genvar j = 0; j < 5; j++) begin : g_j
        assign out[24 - (i*5 + j)] = ~inputs[i] ^ inputs[j];
      end
    end
  endgenerate
endmodule