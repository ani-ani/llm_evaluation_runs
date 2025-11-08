module TopModule (
  input clk,
  input reset,
  output logic [2:0] ena,
  output logic [15:0] q
);
  logic [3:0] ones, tens, hundreds, thousands;

  assign q = {thousands, hundreds, tens, ones};
  assign ena[0] = (ones == 4'h9);
  assign ena[1] = (ones == 4'h9) && (tens == 4'h9);
  assign ena[2] = (ones == 4'h9) && (tens == 4'h9) && (hundreds == 4'h9);

  always_ff @(posedge clk) begin
    if (reset) begin
      ones <= 4'b0;
      tens <= 4'b0;
      hundreds <= 4'b0;
      thousands <= 4'b0;
    end else begin
      // Ones digit (always increments)
      if (ones == 4'h9)
        ones <= 4'b0;
      else
        ones <= ones + 4'b1;

      // Tens digit (increments when ones rolls)
      if (ena[0]) begin
        if (tens == 4'h9)
          tens <= 4'b0;
        else
          tens <= tens + 4'b1;
      end

      // Hundreds digit (increments when ones+tens roll)
      if (ena[1]) begin
        if (hundreds == 4'h9)
          hundreds <= 4'b0;
        else
          hundreds <= hundreds + 4'b1;
      end

      // Thousands digit (increments when all lower digits roll)
      if (ena[2]) begin
        if (thousands == 4'h9)
          thousands <= 4'b0;
        else
          thousands <= thousands + 4'b1;
      end
    end
  end
endmodule