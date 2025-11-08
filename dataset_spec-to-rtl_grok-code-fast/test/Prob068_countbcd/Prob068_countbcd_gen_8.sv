module TopModule(
  input clk,
  input reset,
  output reg [2:0] ena,
  output reg [15:0] q
);
  reg [3:0] ones;
  reg [3:0] tens;
  reg [3:0] hundreds;
  reg [3:0] thousands;

  assign q = {thousands, hundreds, tens, ones};

  always @(posedge clk) begin
    if (reset) begin
      ones <= 4'd0;
      tens <= 4'd0;
      hundreds <= 4'd0;
      thousands <= 4'd0;
      ena <= 3'b0;
    end else begin
      // Set enable signals based on current values (before increment)
      ena[0] <= (ones == 4'd9);
      ena[1] <= (ones == 4'd9) && (tens == 4'd9);
      ena[2] <= (ones == 4'd9) && (tens == 4'd9) && (hundreds == 4'd9);

      // Increment logic
      if (ones == 4'd9) begin
        ones <= 4'd0;
        if (tens == 4'd9) begin
          tens <= 4'd0;
          if (hundreds == 4'd9) begin
            hundreds <= 4'd0;
            thousands <= (thousands == 4'd9) ? 4'd0 : thousands + 1;
          end else begin
            hundreds <= hundreds + 1;
          end
        end else begin
          tens <= tens + 1;
        end
      end else begin
        ones <= ones + 1;
      end
    end
  end
endmodule