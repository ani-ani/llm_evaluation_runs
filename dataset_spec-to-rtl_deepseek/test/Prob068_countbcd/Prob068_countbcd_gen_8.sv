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
  
  logic ones_rollover;
  logic tens_rollover;
  logic hundreds_rollover;
  
  always_ff @(posedge clk) begin
    if (reset) begin
      ones <= 4'b0;
      tens <= 4'b0;
      hundreds <= 4'b0;
      thousands <= 4'b0;
    end else begin
      // Ones digit
      if (ones == 4'd9) begin
        ones <= 4'b0;
      end else begin
        ones <= ones + 4'b1;
      end
      
      // Tens digit
      if (ones_rollover) begin
        if (tens == 4'd9) begin
          tens <= 4'b0;
        end else begin
          tens <= tens + 4'b1;
        end
      end
      
      // Hundreds digit
      if (tens_rollover) begin
        if (hundreds == 4'd9) begin
          hundreds <= 4'b0;
        end else begin
          hundreds <= hundreds + 4'b1;
        end
      end
      
      // Thousands digit
      if (hundreds_rollover) begin
        if (thousands == 4'd9) begin
          thousands <= 4'b0;
        end else begin
          thousands <= thousands + 4'b1;
        end
      end
    end
  end
  
  // Rollover logic
  assign ones_rollover = (ones == 4'd9);
  assign tens_rollover = (tens == 4'd9) & ones_rollover;
  assign hundreds_rollover = (hundreds == 4'd9) & tens_rollover;
  
  // Output assignments
  assign ena = {hundreds_rollover, tens_rollover, ones_rollover};
  assign q = {thousands, hundreds, tens, ones};
  
endmodule