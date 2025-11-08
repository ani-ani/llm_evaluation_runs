module TopModule(input clk, input areset, input x, output logic z);
  reg state_A, state_B;

  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      state_A <= 1'b1;
      state_B <= 1'b0;
    end
    else begin
      state_A <= (state_A & ~x) | (state_B & 1'b0);
      state_B <= (state_A & x) | (state_B & 1'b1);
    end
  end

  always_comb begin
    z = (state_A & x) | (state_B & ~x);
  end
endmodule