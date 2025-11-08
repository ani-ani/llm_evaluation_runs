module TopModule(
  input  clk,
  input  areset,
  input  train_valid,
  input  train_taken,
  output logic [1:0] state
);

  always_ff @(posedge clk, posedge areset) begin
    if (areset) begin
      state <= 2'b01;
    end else begin
      if (train_valid) begin
        if (train_taken) begin
          state <= (state == 2'b11) ? 2'b11 : state + 1;
        end else begin
          state <= (state == 2'b00) ? 2'b00 : state - 1;
        end
      end else begin
        state <= state;
      end
    end
  end
endmodule