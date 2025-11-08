module TopModule(
  input clk,
  input reset,
  output logic [2:0] ena,
  output logic [15:0] q
);
  
  reg [3:0] ones;
  reg [3:0] tens;
  reg [3:0] hundreds;
  reg [3:0] thousands;
  
  always_comb begin
    ena[0] = (ones == 4'd9);
    ena[1] = (tens == 4'd9) & ena[0];
    ena[2] = (hundreds == 4'd9) & ena[1];
    q = {thousands, hundreds, tens, ones};
  end
  
  always_ff @(posedge clk) begin
    if (reset) begin
      ones <= 4'd0;
      tens <= 4'd0;
      hundreds <= 4'd0;
      thousands <= 4'd0;
    end
    else begin
      ones <= (ones == 4'd9) ? 4'd0 : ones + 4'd1;
      tens <= ena[0] ? ((tens == 4'd9) ? 4'd0 : tens + 4'd1) : tens;
      hundreds <= ena[1] ? ((hundreds == 4'd9) ? 4'd0 : hundreds + 4'd1) : hundreds;
      thousands <= ena[2] ? ((thousands == 4'd9) ? 4'd0 : thousands + 4'd1) : thousands;
    end
  end
  
endmodule