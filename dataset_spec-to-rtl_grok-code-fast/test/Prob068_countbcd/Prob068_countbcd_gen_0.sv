module TopModule(
  input clk,
  input reset,
  output reg [2:0] ena,
  output reg [15:0] q
);
  reg [3:0] units, tens, hundreds, thousands;

  always @(posedge clk) begin
    if (reset) begin
      units <= 4'd0;
      tens <= 4'd0;
      hundreds <= 4'd0;
      thousands <= 4'd0;
      q <= 16'd0;
      ena <= 3'd0;
    end else begin
      // Calculate new units and tens carry
      reg [3:0] new_units = units + 1;
      reg tens_carry = (new_units == 4'd10) ? 1 : 0;
      if (tens_carry) new_units = 4'd0;
      units <= new_units;

      // Update tens, but first see if tens needs update only from tens_carry
      reg [3:0] new_tens = tens + tens_carry;
      reg hundreds_carry = (new_tens == 4'd10) ? 1 : 0;
      if (hundreds_carry) new_tens = 4'd0;
      tens <= new_tens;

      // Update hundreds
      reg [3:0] new_hundreds = hundreds + hundreds_carry;
      reg thousands_carry = (new_hundreds == 4'd10) ? 1 : 0;
      if (thousands_carry) new_hundreds = 4'd0;
      hundreds <= new_hundreds;

      // Update thousands
      reg [3:0] new_thousands = thousands + thousands_carry;
      if (new_thousands == 4'd10) new_thousands = 4'd0;
      thousands <= new_thousands;

      // Set enables
      ena[0] <= tens_carry;
      ena[1] <= hundreds_carry;
      ena[2] <= thousands_carry;

      // Assign q
      q <= {thousands, hundreds, tens, units};
    end
  end
endmodule