module TopModule (input clk, input reset, output logic [2:0] ena, output logic [15:0] q);
  logic [3:0] ones, tens, hundreds, thousands;

  always_ff @(posedge clk) begin
    if (reset) begin
      ones <= 4'b0;
      tens <= 4'b0;
      hundreds <= 4'b0;
      thousands <= 4'b0;
    end else begin
      ones <= ones + 1;
      if (ones == 4'd9) begin
        ones <= 4'b0;
        tens <= tens + 1;
        if (tens == 4'd9) begin
          tens <= 4'b0;
          hundreds <= hundreds + 1;
          if (hundreds == 4'd9) begin
            hundreds <= 4'b0;
            thousands <= thousands + 1;
            if (thousands == 4'd9) begin
              thousands <= 4'b0;
            end
          end
        end
      end
    end
  end

  assign ena[0] = (ones == 4'd9);
  assign ena[1] = (tens == 4'd9) & (ones == 4'd9);
  assign ena[2] = (hundreds == 4'd9) & (tens == 4'd9) & (ones == 4'd9);
  assign q = {thousands, hundreds, tens, ones};
endmodule