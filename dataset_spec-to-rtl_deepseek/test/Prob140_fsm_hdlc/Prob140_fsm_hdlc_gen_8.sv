module TopModule(
  input clk,
  input reset,
  input in,
  output reg disc,
  output reg flag,
  output reg err
);
  reg [2:0] cnt;
  reg disc_latch;
  reg flag_latch;
  reg err_latch;

  always @(posedge clk) begin
    if (reset) begin
      cnt <= 0;
      disc <= 0;
      flag <= 0;
      err <= 0;
      disc_latch <= 0;
      flag_latch <= 0;
      err_latch <= 0;
    end else begin
      disc <= disc_latch;
      flag <= flag_latch;
      err <= err_latch;
      disc_latch <= 0;
      flag_latch <= 0;
      err_latch <= 0;
      if (cnt == 5 && in == 0) disc_latch <= 1;
      if (cnt == 6 && in == 0) flag_latch <= 1;
      if (cnt >= 6 && in == 1) err_latch <= 1;
      if (in == 0) begin
        cnt <= 0;
      end else if (cnt < 7) begin
        cnt <= cnt + 1;
      end
    end
  end
endmodule