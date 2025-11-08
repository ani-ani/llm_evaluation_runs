module TopModule(
  input clk,
  input reset,
  output reg [2:0] ena,
  output reg [15:0] q
);

  reg [3:0] thousands;
  reg [3:0] hundreds;
  reg [3:0] tens;
  reg [3:0] ones;

  assign q = {thousands, hundreds, tens, ones};

  always @(posedge clk) begin
    if (reset) begin
      thousands <= 4'd0;
      hundreds <= 4'd0;
      tens <= 4'd0;
      ones <= 4'd0;
      ena <= 3'b000;
    end else begin
      ena <= 3'b000;
      if (ones == 4'd9) begin
        ones <= 4'd0;
        if (tens == 4'd9) begin
          tens <= 4'd0;
          ena[0] <= 1'b1;
          if (hundreds == 4'd9) begin
            hundreds <= 4'd0;
            ena[1] <= 1'b1;
            if (thousands == 4'd9) begin
              thousands <= 4'd0;
            end else begin
              thousands <= thousands + 1;
            end
            ena[2] <= 1'b1;
          end else begin
            hundreds <= hundreds + 1;
            ena[1] <= 1'b1;
          end
        end else begin
          tens <= tens + 1;
          ena[0] <= 1'b1;
        end
      end else begin
        ones <= ones + 1;
      end
    end
  end
endmodule