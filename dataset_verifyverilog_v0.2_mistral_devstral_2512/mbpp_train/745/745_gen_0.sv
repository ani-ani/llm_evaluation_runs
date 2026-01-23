module divisible_by_digits(
  input [3:0] start_num,
  input [3:0] end_num,
  output [15:0] valid_mask
);

  // Function to check if a number is divisible by all its non-zero digits
  function automatic [15:0] check_valid_numbers;
    input [3:0] start;
    input [3:0] end;
    integer i, j, digit, remainder, temp;
    reg [15:0] mask;
    reg [3:0] digits [0:15];
    reg [3:0] num_digits [0:15];

    // Initialize digit arrays for numbers 0-15
    // digits[N] contains the digits of N, num_digits[N] is the count
    // For single-digit numbers (0-9), digits[N][0] = N, num_digits[N] = 1
    // For two-digit numbers (10-15), digits[N][0] = 1, digits[N][1] = N-10, num_digits[N] = 2
    for (i = 0; i <= 15; i = i + 1) begin
      if (i < 10) begin
        digits[i][0] = i;
        num_digits[i] = 1;
      end else begin
        digits[i][0] = 1;
        digits[i][1] = i - 10;
        num_digits[i] = 2;
      end
    end

    // Check each number from 0 to 15
    for (i = 0; i <= 15; i = i + 1) begin
      reg valid = 1'b1;
      reg has_zero = 1'b0;

      // Check if the number is within the specified range
      if (i < start || i > end) begin
        valid = 1'b0;
      end

      // Check each digit of the number
      for (j = 0; j < num_digits[i]; j = j + 1) begin
        digit = digits[i][j];

        // If digit is 0, the number is invalid
        if (digit == 0) begin
          has_zero = 1'b1;
        end

        // Check divisibility by non-zero digits
        if (digit != 0 && !has_zero) begin
          temp = i;
          remainder = temp;
          // Repeated subtraction to find remainder
          while (remainder >= digit) begin
            remainder = remainder - digit;
          end

          // If remainder is not zero, the number is invalid
          if (remainder != 0) begin
            valid = 1'b0;
          end
        end
      end

      // Set the bit in the mask if the number is valid
      mask[i] = valid && !has_zero;
    end

    check_valid_numbers = mask;
  endfunction

  // Assign the output mask
  assign valid_mask = check_valid_numbers(start_num, end_num);

endmodule