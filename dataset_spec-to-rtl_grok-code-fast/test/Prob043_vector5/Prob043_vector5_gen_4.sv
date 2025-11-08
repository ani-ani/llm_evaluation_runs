module TopModule(
  input a,
  input b,
  input c,
  input d,
  input e,
  output [24:0] out
);
  wire [4:0] in = {a, b, c, d, e};
  generate
    for (genvar i = 0; i < 5; i++) begin
      for (genvar j = 0; j < 5; j++) begin
        assign out[24 - (i * 5 + j)] = ~(in[i] ^ in[j]);
      end
    end
  endgenerate
endmodule