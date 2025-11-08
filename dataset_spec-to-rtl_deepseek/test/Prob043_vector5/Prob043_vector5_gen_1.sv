module TopModule(input reg a, b, c, d, e, output reg [24:0] out);
  logic [4:0] in_bits = {a, b, c, d, e};
  always_comb begin
    for (int i=0; i<5; i++) begin
      for (int j=0; j<5; j++) begin
        out[24 - (i*5 + j)] = ~in_bits[i] ^ in_bits[j];
      end
    end
  end
endmodule