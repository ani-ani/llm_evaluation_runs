module elementwise_div (
  input [3:0] num1_array,
  input [3:0] num2_array,
  output [3:0] quotient_array,
  output [3:0] remainder_array
);

  // Process each element in parallel
  genvar i;
  generate
    for (i = 0; i < 4; i = i + 1) begin : element_loop
      wire [3:0] num1 = num1_array[i];
      wire [3:0] num2 = num2_array[i];
      wire [3:0] quotient;
      wire [3:0] remainder;

      // Handle division by zero (saturation behavior)
      assign quotient = (num2 == 0) ? 4'b1111 : num1 / num2;
      assign remainder = (num2 == 0) ? 4'b0000 : num1 % num2;

      // Assign to output arrays
      assign quotient_array[i] = quotient;
      assign remainder_array[i] = remainder;
    end
  endgenerate

endmodule