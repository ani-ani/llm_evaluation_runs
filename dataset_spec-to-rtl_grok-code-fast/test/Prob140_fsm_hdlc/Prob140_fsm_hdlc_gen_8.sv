module TopModule(
  input clk,
  input reset,
  input in,
  output reg disc,
  output reg flag,
  output reg err
);

  reg [2:0] cnt;
  reg disc_reg;
  reg flag_reg;
  reg err_reg;

  always @(posedge clk) begin
    if (reset) begin
      cnt <= 0;
      disc_reg <= 0;
      flag_reg <= 0;
      err_reg <= 0;
      disc <= 0;
      flag <= 0;
      err <= 0;
    end else begin
      disc_reg <= (cnt == 5 && in == 0);
      flag_reg <= (cnt == 6 && in == 0);
      err_reg <= (cnt >= 7);
      disc <= disc_reg;
      flag <= flag_reg;
      err <= err_reg;
      cnt <= (in == 0) ? 0 : (cnt == 7 ? 7 : cnt + 1);
    end
  end
endmodule