module TopModule(
  input a,
  input b,
  input c,
  input d,
  input e,
  output [24:0] out
);
  logic [4:0] vars;
  assign vars = {e, d, c, b, a};
  genvar i, j;
  generate
    for (i = 0; i < 5; i = i + 1) begin
      for (j = 0; j < 5; j = j + 1) begin
        assign out[((4 - i) * 5) + (4 - j)] = (vars[i] == vars[j]);
      end
    end
  endgenerate
endmodule