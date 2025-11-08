module TopModule (
  input clk,
  input a,
  input b,
  output q,
  output reg state
);
  wire next_state = (state & (a != b)) | (~state & (a & b));

  always @(posedge clk) begin
    state <= next_state;
  end

  assign q = state ? (a == b) : (a != b);
endmodule