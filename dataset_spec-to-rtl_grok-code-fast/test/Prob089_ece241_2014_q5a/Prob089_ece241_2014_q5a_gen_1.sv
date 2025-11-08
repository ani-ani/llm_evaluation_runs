module TopModule(input clk, input areset, input x, output reg z);
  reg state;
  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= 1'b0;
      z <= 1'b0;
    end else begin
      if (state == 0) begin
        z <= x;
        state <= x;
      end else begin
        z <= ~x;
        state <= 1'b1;
      end
    end
  end
endmodule