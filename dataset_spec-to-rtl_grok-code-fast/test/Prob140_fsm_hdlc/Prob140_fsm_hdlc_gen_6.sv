module TopModule(
  input clk,
  input reset,
  input in,
  output disc,
  output flag,
  output err
);
  reg [7:0] history;
  reg disc_reg, flag_reg, err_reg;
  reg disc_prev, flag_prev, err_prev;
  always_ff @(posedge clk)
    if (reset) begin
      history <= 8'h00;
      disc_prev <= 1'b0;
      flag_prev <= 1'b0;
      err_prev <= 1'b0;
      disc_reg <= 1'b0;
      flag_reg <= 1'b0;
      err_reg <= 1'b0;
    end
    else begin
      history <= {in, history[7:1]};
      disc_prev <= (history[6:0] == 7'b0111110);
      flag_prev <= (history == 8'b01111110);
      err_prev <= (history == 8'b01111111);
      disc_reg <= disc_prev;
      flag_reg <= flag_prev;
      err_reg <= err_prev;
    end
  assign disc = disc_reg;
  assign flag = flag_reg;
  assign err = err_reg;
endmodule