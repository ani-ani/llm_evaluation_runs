module TopModule(input clk, input areset, input x, output logic z);
  logic [1:0] state_reg, state_next;
  localparam STATE_A = 2'b01;
  localparam STATE_B = 2'b10;

  always_ff @(posedge clk, posedge areset) begin
    if (areset) state_reg <= STATE_A;
    else state_reg <= state_next;
  end

  assign state_next[0] = state_reg[0] & ~x;
  assign state_next[1] = (state_reg[0] & x) | state_reg[1];
  assign z = (state_reg[0] & x) | (state_reg[1] & ~x);
endmodule