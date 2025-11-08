module TopModule(
  input [254:0] in,
  output [7:0] out
);
always_comb begin
  out = 0;
  for(int i = 0; i < 255; i++) begin
    out += in[i];
  end
end
endmodule