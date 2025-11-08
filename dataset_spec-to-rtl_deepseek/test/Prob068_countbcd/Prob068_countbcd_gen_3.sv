module TopModule(
  input clk,
  input reset,
  output [2:0] ena,
  output [15:0] q
);
  reg [3:0] ones, tens, hundreds, thousands;
  wire ena_ones = 1'b1;
  wire ena_tens = (ones == 4'd9) & ena_ones;
  wire ena_hundreds = (tens == 4'd9) & ena_tens;
  wire ena_thousands = (hundreds == 4'd9) & ena_hundreds;

  always @(posedge clk) begin
    if (reset) ones <= 4'b0;
    else if (ena_ones) ones <= (ones == 4'd9) ? 4'b0 : ones + 1;
  end

  always @(posedge clk) begin
    if (reset) tens <= 4'b0;
    else if (ena_tens) tens <= (tens == 4'd9) ? 4'b0 : tens + 1;
  end

  always @(posedge clk) begin
    if (reset) hundreds <= 4'b0;
    else if (ena_hundreds) hundreds <= (hundreds == 4'd9) ? 4'b0 : hundreds + 1;
  end

  always @(posedge clk) begin
    if (reset) thousands <= 4'b0;
    else if (ena_thousands) thousands <= (thousands == 4'd9) ? 4'b0 : thousands + 1;
  end

  assign q = {thousands, hundreds, tens, ones};
  assign ena = {ena_thousands, ena_hundreds, ena_tens};
endmodule