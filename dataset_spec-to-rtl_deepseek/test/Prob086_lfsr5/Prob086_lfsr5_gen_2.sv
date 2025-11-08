module TopModule (
  input clk,
  input reset,
  output reg [4:0] q
);
  always @(posedge clk or posedge reset)
    if (reset)
      q <= 5'b00001;
    else
      q <= {q[0] ^ q[2] ^ q[4], q[4:1]};
endmodule