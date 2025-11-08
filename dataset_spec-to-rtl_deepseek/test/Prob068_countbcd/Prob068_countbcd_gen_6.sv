module TopModule(input clk, input reset, output [2:0] ena, output [15:0] q);
  reg [3:0] ones;
  reg [3:0] tens;
  reg [3:0] hundreds;
  reg [3:0] thousands;
  
  assign q = {thousands, hundreds, tens, ones};
  
  assign ena[0] = (ones == 4'd9);
  assign ena[1] = (ena[0] & (tens == 4'd9));
  assign ena[2] = (ena[1] & (hundreds == 4'd9));
  
  always @(posedge clk) begin
    if (reset) begin
      ones <= 4'b0;
      tens <= 4'b0;
      hundreds <= 4'b0;
      thousands <= 4'b0;
    end else begin
      // Handle ones digit
      if (ones == 4'd9) ones <= 4'b0;
      else ones <= ones + 1'b1;
      
      // Handle tens digit
      if (ena[0]) begin
        if (tens == 4'd9) tens <= 4'b0;
        else tens <= tens + 1'b1;
      end
      
      // Handle hundreds digit
      if (ena[1]) begin
        if (hundreds == 4'd9) hundreds <= 4'b0;
        else hundreds <= hundreds + 1'b1;
      end
      
      // Handle thousands digit
      if (ena[2]) begin
        if (thousands == 4'd9) thousands <= 4'b0;
        else thousands <= thousands + 1'b1;
      end
    end
  end
endmodule