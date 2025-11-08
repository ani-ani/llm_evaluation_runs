module TopModule(
  input clk,
  input reset,
  output [4:0] q
);

  reg [4:0] q_reg;
  wire feedback = q_reg[4] ^ q_reg[2];
  wire [4:0] next_q;

  assign next_q[0] = q_reg[1];
  assign next_q[1] = q_reg[2];
  assign next_q[2] = q_reg[3] ^ feedback;
  assign next_q[3] = q_reg[4];
  assign next_q[4] = feedback;

  always @(posedge clk) begin
    if (reset)
      q_reg <= 5'b00001;
    else
      q_reg <= next_q;
  end

  assign q = q_reg;
endmodule