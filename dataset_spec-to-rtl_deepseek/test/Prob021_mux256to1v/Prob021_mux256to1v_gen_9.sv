module TopModule(input [1023:0] in, input [7:0] sel, output reg [3:0] out);
  always_comb begin
    out = in[sel*4 +: 4];
  end
endmodule