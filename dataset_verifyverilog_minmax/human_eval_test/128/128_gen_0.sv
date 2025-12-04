module prod_signs (
  input [2:0] array_length,
  input signed [7:0] arr [0:7],
  output logic signed [11:0] result,
  output logic valid
);

  always @(*) begin
    if (array_length == 3'd0) begin
      valid  = 1'b0;
      result = 12'bx; // don't-care
    end else begin
      valid  = 1'b1;
      // Count negative elements and detect zero among valid elements
      // Also compute sum of absolute values (unsigned magnitude sum)
      int i;
      int neg_count;
      bit any_zero;
      int sum_abs;
      sum_abs = 0;
      neg_count = 0;
      any_zero = 0;
      for (i = 0; i < 8; i = i + 1) begin
        if (i < array_length) begin
          if (arr[i] == 0)      any_zero = 1;
          else if (arr[i] < 0)  neg_count = neg_count + 1;
          sum_abs = sum_abs + (arr[i] < 0 ? -arr[i] : arr[i]);
        end
      end
      // Determine product sign (0 takes precedence)
      int product_sign;
      if (any_zero)       product_sign = 0;
      else if (neg_count[0]) product_sign = -1; // odd number of negatives
      else                product_sign = 1;  // even number of negatives
      result = $signed(product_sign) * $signed(sum_abs);
    end
  end

endmodule