module div7_digit_rearranger(
  input [31:0] digits_in,
  output reg [31:0] rearranged_out
);

  integer i, j, k;
  reg [3:0] arbitrary_digits [0:3];
  reg [3:0] temp_digit;
  integer remaining_num;
  integer rem;
  integer current_remainder;
  integer desired_mod;
  reg [15:0] selected_perm;

  // Extract 4 arbitrary digits (not 1,6,8,9) and sort in descending order
  k = 0;
  for (i = 0; i < 8; i++) begin
    reg [3:0] digit;
    case (i)
      0: digit = digits_in[31:28];
      1: digit = digits_in[27:24];
      2: digit = digits_in[23:20];
      3: digit = digits_in[19:16];
      4: digit = digits_in[15:12];
      5: digit = digits_in[11:8];
      6: digit = digits_in[7:4];
      7: digit = digits_in[3:0];
    endcase

    if ((digit != 4'd1) && (digit != 4'd6) && (digit != 4'd8) && (digit != 4'd9)) begin
      if (k < 4) begin
        arbitrary_digits[k] = digit;
        k = k + 1;
      end
    end
  end

  // Sort arbitrary digits in descending order (bubble sort)
  for (i = 0; i < 4; i++) begin
    for (j = i + 1; j < 4; j++) begin
      if (arbitrary_digits[i] < arbitrary_digits[j]) begin
        temp_digit = arbitrary_digits[i];
        arbitrary_digits[i] = arbitrary_digits[j];
        arbitrary_digits[j] = temp_digit;
      end
    end
  end

  // Form 4-digit number from sorted digits
  remaining_num = arbitrary_digits[0] * 1000 + 
                  arbitrary_digits[1] * 100 + 
                  arbitrary_digits[2] * 10 + 
                  arbitrary_digits[3];

  // Compute remainder: (remaining_num * 10000) % 7 = (remaining_num % 7) * 4 % 7
  rem = remaining_num % 7;
  current_remainder = (rem * 4) % 7;

  // Calculate desired permutation: (7 - current_remainder) % 7
  if (current_remainder == 0)
    desired_mod = 0;
  else
    desired_mod = 7 - current_remainder;

  // Select permutation from precomputed map
  case (desired_mod)
    0: selected_perm = 16'b0001_1000_0110_1001; // 1869
    1: selected_perm = 16'b0001_1001_0110_1000; // 1968
    2: selected_perm = 16'b0001_0110_1000_1001; // 1689
    3: selected_perm = 16'b0110_0001_1001_1000; // 6198
    4: selected_perm = 16'b0001_0110_1001_1000; // 1698
    5: selected_perm = 16'b1001_1000_0110_0001; // 9861
    6: selected_perm = 16'b0001_1000_1001_0110; // 1896
  endcase

  // Form output: remaining digits + selected permutation
  rearranged_out = {
    arbitrary_digits[0],
    arbitrary_digits[1],
    arbitrary_digits[2],
    arbitrary_digits[3],
    selected_perm
  };

endmodule