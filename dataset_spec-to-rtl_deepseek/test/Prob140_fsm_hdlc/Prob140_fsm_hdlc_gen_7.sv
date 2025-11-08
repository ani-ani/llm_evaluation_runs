module TopModule(
  input clk,
  input reset,
  input in,
  output disc,
  output flag,
  output err
);

  parameter S0 = 0;
  parameter S1 = 1;
  parameter S2 = 2;
  parameter S3 = 3;
  parameter S4 = 4;
  parameter S5 = 5;
  parameter S6 = 6;
  parameter S7 = 7;

  reg [2:0] counter;
  reg disc_r;
  reg flag_r;
  reg err_r;

  assign disc = disc_r;
  assign flag = flag_r;
  assign err = err_r;

  always @(posedge clk) begin
    if (reset) begin
      counter <= S0;
      disc_r <= 0;
      flag_r <= 0;
      err_r <= 0;
    end else begin
      case (counter)
        S0: counter <= in ? S1 : S0;
        S1: counter <= in ? S2 : S0;
        S2: counter <= in ? S3 : S0;
        S3: counter <= in ? S4 : S0;
        S4: counter <= in ? S5 : S0;
        S5: counter <= in ? S6 : S0;
        S6: counter <= in ? S7 : S0;
        S7: counter <= in ? S7 : S0;
      endcase
      disc_r <= (counter == S5 && in == 0);
      flag_r <= (counter == S6 && in == 0);
      err_r <= (counter == S6 && in == 1);
    end
  end

endmodule