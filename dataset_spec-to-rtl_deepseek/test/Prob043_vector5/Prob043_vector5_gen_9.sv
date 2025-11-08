module TopModule (input a, b, c, d, e, output [24:0] out);
  logic [0:4] inputs;
  assign inputs = {a, b, c, d, e};
  always_comb begin
    for (int k = 0; k < 25; k++) begin
      int i = k / 5;
      int j = k % 5;
      out[24 - k] = ~inputs[i] ^ inputs[j];
    end
  end
endmodule