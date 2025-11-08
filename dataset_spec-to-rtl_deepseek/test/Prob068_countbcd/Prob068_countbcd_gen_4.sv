module TopModule(
  input clk,
  input reset,
  output logic [2:0] ena,
  output logic [15:0] q
);
  logic [3:0] ones;
  logic [3:0] tens;
  logic [3:0] hundreds;
  logic [3:0] thousands;

  assign ena[0] = (ones == 4'd9);
  assign ena[1] = (tens == 4'd9) && ena[0];
  assign ena[2] = (hundreds == 4'd9) && ena[1];

  always_ff @(posedge clk) begin
    if (reset) begin
      ones <= 4'b0;
      tens <= 4'b0;
      hundreds <= 4'b0;
      thousands <= 4'b0;
    end else begin
      if (ones == 4'd9)
        ones <= 4'b0;
      else
        ones <= ones + 1;

      if (ena[0]) begin
        if (tens == 4'd9)
          tens <= 4'b0;
        else
          tens <= tens + 1;
      end

      if (ena[1]) begin
        if (hundreds == 4'd9)
          hundreds <= 4'b0;
        else
          hundreds <= hundreds + 1;
      end

      if (ena[2]) begin
        if (thousands == 4'd9)
          thousands <= 4'b0;
        else
          thousands <= thousands + 1;
      end
    end
  end

  assign q = {thousands, hundreds, tens, ones};
endmodule