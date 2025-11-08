module TopModule(
  input clk,
  input areset,
  input x,
  output z
);

  typedef enum logic {INVERT, ADD} state_t;
  state_t state;
  logic z_reg;

  assign z = z_reg;

  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= INVERT;
      z_reg <= ~x;
    end else begin
      z_reg <= (state == INVERT) ? ~x : (~x ^ 1'b1);
      state <= (state == INVERT && x == 1'b1) ? ADD : state;
    end
  end
endmodule