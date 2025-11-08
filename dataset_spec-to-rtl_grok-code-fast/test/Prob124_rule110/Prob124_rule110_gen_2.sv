module TopModule (
  input clk,
  input load,
  input [511:0] data,
  output [511:0] q
);

  reg [511:0] q_reg;
  wire [511:0] next_q;

  assign q = q_reg;

  always_comb begin
    for (int i = 0; i < 512; i++) begin
      logic left_bit = (i > 0) ? q_reg[i-1] : 1'b0;
      logic center_bit = q_reg[i];
      logic right_bit = (i < 511) ? q_reg[i+1] : 1'b0;
      next_q[i] = !((left_bit == 1'b0 && center_bit == 1'b0 && right_bit == 1'b0) ||
                     (left_bit == 1'b1 && center_bit == 1'b0 && right_bit == 1'b0) ||
                     (left_bit == 1'b1 && center_bit == 1'b1 && right_bit == 1'b1));
    end
  end

  always_ff @(posedge clk) begin
    if (load)
      q_reg <= data;
    else
      q_reg <= next_q;
  end

endmodule