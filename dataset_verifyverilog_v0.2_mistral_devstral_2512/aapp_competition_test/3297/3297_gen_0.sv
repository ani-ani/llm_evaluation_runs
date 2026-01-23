module cryptarithm_solver (
  input [3:0] enable,
  output [3:0] digit_A,
  output [3:0] digit_B,
  output [3:0] digit_C,
  output valid
);

  reg [3:0] digit_A_reg = 4'b1111;
  reg [3:0] digit_B_reg = 4'b1111;
  reg [3:0] digit_C_reg = 4'b1111;
  reg valid_reg = 1'b0;

  always @* begin
    if (!enable) begin
      digit_A_reg = 4'b1111;
      digit_B_reg = 4'b1111;
      digit_C_reg = 4'b1111;
      valid_reg = 1'b0;
    end else begin
      digit_A_reg = 4'b1010; // Default to 10 (impossible)
      digit_B_reg = 4'b1010;
      digit_C_reg = 4'b1010;
      valid_reg = 1'b0;

      for (int a = 1; a <= 9; a = a + 1) begin
        for (int b = 1; b <= 9; b = b + 1) begin
          if (a == b) continue;
          for (int c = 0; c <= 9; c = c + 1) begin
            if (a == c || b == c) continue;
            if (a + b == c) begin
              digit_A_reg = a;
              digit_B_reg = b;
              digit_C_reg = c;
              valid_reg = 1'b1;
              break;
            end
          end
        end
      end
    end
  end

  assign digit_A = digit_A_reg;
  assign digit_B = digit_B_reg;
  assign digit_C = digit_C_reg;
  assign valid = valid_reg;

endmodule