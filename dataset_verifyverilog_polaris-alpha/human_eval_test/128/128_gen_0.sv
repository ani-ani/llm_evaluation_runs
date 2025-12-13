module prod_signs(
  input  [2:0]           array_length,
  input  signed [7:0]    arr [0:7],
  output logic signed [11:0] result,
  output logic           valid
);

  // Internal signals
  logic any_zero;
  logic [3:0] neg_count;          // Up to 8 negatives
  logic signed [7:0] abs_val [0:7];
  logic [10:0] sum_abs;           // Max 8 * 127 = 1016 < 2^10, use 11 bits for safety
  logic product_sign_is_neg;      // 1 if product sign is negative, 0 if positive

  // Compute absolute values (two's complement safe for all 8-bit signed values)
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : gen_abs
      always @* begin
        if (arr[i][7] == 1'b1)
          abs_val[i] = -arr[i];
        else
          abs_val[i] = arr[i];
      end
    end
  endgenerate

  // Main combinational block
  always @* begin
    valid      = (array_length != 3'd0);
    any_zero   = 1'b0;
    neg_count  = 4'd0;
    sum_abs    = 11'd0;

    // Only process first array_length elements
    if (valid) begin
      for (int j = 0; j < 8; j = j + 1) begin
        if (j < array_length) begin
          // Zero detection
          if (arr[j] == 8'sd0)
            any_zero = 1'b1;

          // Count negatives
          if (arr[j][7] == 1'b1)
            neg_count = neg_count + 4'd1;

          // Accumulate absolute values
          sum_abs = sum_abs + abs_val[j];
        end
      end
    end

    // Determine product sign (only if no zero and valid)
    if (!valid) begin
      // array_length == 0: result is don't care; drive 0 to keep deterministic
      result = 12'sd0;
    end else if (any_zero) begin
      // Any zero -> product_sign = 0
      result = 12'sd0;
    end else begin
      // No zeros: sign is (-1)^(neg_count)
      product_sign_is_neg = neg_count[0]; // 1 if odd number of negatives

      if (product_sign_is_neg)
        result = -$signed({1'b0, sum_abs});
      else
        result =  $signed({1'b0, sum_abs});
    end
  end

endmodule