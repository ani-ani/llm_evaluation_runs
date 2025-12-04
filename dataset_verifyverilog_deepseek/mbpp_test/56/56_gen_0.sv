module rev_checker(input reg [7:0] num, output check);
  logic [7:0] units_digit, tens_digit, hundreds_digit;
  logic [9:0] reversed_num;
  logic [10:0] doubled_reversed;
  logic [8:0] num_plus_1;

  assign units_digit = num % 8'd10;
  assign tens_digit = (num / 8'd10) % 8'd10;
  assign hundreds_digit = num / 8'd100;

  assign reversed_num = (hundreds_digit != 8'd0) ? 
                        (units_digit * 8'd100 + tens_digit * 8'd10 + hundreds_digit) :
                        (tens_digit != 8'd0) ? (units_digit * 8'd10 + tens_digit) :
                        units_digit;

  assign doubled_reversed = reversed_num * 2;
  assign num_plus_1 = num + 1'b1;
  assign check = (doubled_reversed == num_plus_1);
endmodule