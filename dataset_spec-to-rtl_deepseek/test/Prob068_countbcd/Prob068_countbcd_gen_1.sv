module TopModule (
  input clk,
  input reset,
  output logic [2:0] ena,
  output logic [15:0] q
);
  logic [3:0] ones_reg, tens_reg, hundreds_reg, thousands_reg;

  assign ena[0] = (ones_reg == 4'd9);
  assign ena[1] = (tens_reg == 4'd9) & ena[0];
  assign ena[2] = (hundreds_reg == 4'd9) & ena[1];

  assign q = {thousands_reg, hundreds_reg, tens_reg, ones_reg};

  always_ff @(posedge clk) begin
    if (reset) begin
      ones_reg <= 4'b0;
      tens_reg <= 4'b0;
      hundreds_reg <= 4'b0;
      thousands_reg <= 4'b0;
    end else begin
      // Ones digit - always increment
      if (ones_reg == 4'd9) begin
        ones_reg <= 4'b0;
      end else begin
        ones_reg <= ones_reg + 1'b1;
      end

      // Tens digit - increment when ones rolls
      if (ena[0]) begin
        if (tens_reg == 4'd9) begin
          tens_reg <= 4'b0;
        end else begin
          tens_reg <= tens_reg + 1'b1;
        end
      end

      // Hundreds digit - increment when tens rolls
      if (ena[1]) begin
        if (hundreds_reg == 4'd9) begin
          hundreds_reg <= 4'b0;
        end else begin
          hundreds_reg <= hundreds_reg + 1'b1;
        end
      end

      // Thousands digit - increment when hundreds rolls
      if (ena[2]) begin
        if (thousands_reg == 4'd9) begin
          thousands_reg <= 4'b0;
        end else begin
          thousands_reg <= thousands_reg + 1'b1;
        end
      end
    end
  end
endmodule