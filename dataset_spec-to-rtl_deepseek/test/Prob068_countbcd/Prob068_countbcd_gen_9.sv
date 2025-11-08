module TopModule(input clk, input reset, output logic [2:0] ena, output logic [15:0] q);
  logic [3:0] ones_reg, tens_reg, hundreds_reg, thousands_reg;
  
  // Ones digit counter
  always_ff @(posedge clk) begin
    if (reset) ones_reg <= 4'd0;
    else ones_reg <= (ones_reg == 4'd9) ? 4'd0 : ones_reg + 4'd1;
  end
  
  // Tens digit counter
  always_ff @(posedge clk) begin
    if (reset) tens_reg <= 4'd0;
    else if (ena[0]) tens_reg <= (tens_reg == 4'd9) ? 4'd0 : tens_reg + 4'd1;
  end
  
  // Hundreds digit counter
  always_ff @(posedge clk) begin
    if (reset) hundreds_reg <= 4'd0;
    else if (ena[1]) hundreds_reg <= (hundreds_reg == 4'd9) ? 4'd0 : hundreds_reg + 4'd1;
  end
  
  // Thousands digit counter
  always_ff @(posedge clk) begin
    if (reset) thousands_reg <= 4'd0;
    else if (ena[2]) thousands_reg <= (thousands_reg == 4'd9) ? 4'd0 : thousands_reg + 4'd1;
  end
  
  // Enable logic
  assign ena[0] = (ones_reg == 4'd9);
  assign ena[1] = (tens_reg == 4'd9) & ena[0];
  assign ena[2] = (hundreds_reg == 4'd9) & ena[1];
  
  // Output concatenation
  assign q = {thousands_reg, hundreds_reg, tens_reg, ones_reg};
endmodule