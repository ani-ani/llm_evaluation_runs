module TopModule(input clk, input a, input b, output reg q, output reg state);
  always @(posedge clk)
    state <= (~state && (a == b)) || (state && (a != b));
  always @*
    q = a ^ b ^ state;
endmodule