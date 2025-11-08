module TopModule(
  input clk,
  input reset,
  output logic [2:0] ena,
  output logic [15:0] q
);
  logic [3:0] ones, tens, hundreds, thousands;
  
  assign q = {thousands, hundreds, tens, ones};
  
  assign ena[0] = (ones == 4'd9);
  assign ena[1] = (ena[0] & (tens == 4'd9));
  assign ena[2] = (ena[1] & (hundreds == 4'd9));
  
  always_ff @(posedge clk) begin
    if (reset) begin
      ones <= 4'b0;
      tens <= 4'b0;
      hundreds <= 4'b0;
      thousands <= 4'b0;
    end else begin
      // Ones digit
      ones <= (ones == 4'd9) ? 4'd0 : ones + 1;
      
      // Tens digit (enabled by ones overflow)
      if (ena[0]) tens <= (tens == 4'd9) ? 4'd0 : tens + 1;
      
      // Hundreds digit (enabled by tens overflow)
      if (ena[1]) hundreds <= (hundreds == 4'd9) ? 4'd0 : hundreds + 1;
      
      // Thousands digit (enabled by hundreds overflow)
      if (ena[2]) thousands <= (thousands == 4'd9) ? 4'd0 : thousands + 1;
    end
  end
endmodule