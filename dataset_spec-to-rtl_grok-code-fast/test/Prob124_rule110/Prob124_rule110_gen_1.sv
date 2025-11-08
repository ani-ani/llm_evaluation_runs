module TopModule(
  input clk,
  input load,
  input [511:0] data,
  output [511:0] q
);

  logic [511:0] next_q;
  logic [511:0] q_reg;

  assign q = q_reg;

  always_comb begin
    for(int i = 0; i < 512; i++) begin
      logic left = (i == 0) ? 1'b0 : q_reg[i-1];
      logic center = q_reg[i];
      logic right = (i == 511) ? 1'b0 : q_reg[i+1];
      case({left, center, right})
        3'b000: next_q[i] = 1'b0;
        3'b001: next_q[i] = 1'b1;
        3'b010: next_q[i] = 1'b1;
        3'b011: next_q[i] = 1'b1;
        3'b100: next_q[i] = 1'b0;
        3'b101: next_q[i] = 1'b1;
        3'b110: next_q[i] = 1'b1;
        3'b111: next_q[i] = 1'b0;
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if(load)
      q_reg <= data;
    else
      q_reg <= next_q;
  end

endmodule