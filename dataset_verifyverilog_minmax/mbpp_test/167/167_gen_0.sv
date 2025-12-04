module next_power_of_two (
    input reg [15:0] n,
    output wire [16:0] result
);

  // Internal signals
  reg n_is_zero;
  reg n_is_pow2;
  reg [3:0] msb_pos;
  reg [16:0] result_reg;

  // Compute the conditions and the result in a single always_comb block
  always_comb begin
    // Check if n is zero
    n_is_zero = (n == 16'd0);

    // Check if n is a power of two (n != 0 and n & (n-1) == 0)
    n_is_pow2 = (n != 16'd0) && ((n & (n - 16'd1)) == 16'd0);

    // Find the position of the most significant set bit in n (0 to 15)
    // If no bit is set, set msb_pos to 4'hF (to indicate zero)
    msb_pos = 4'hF;
    for (int i = 15; i >= 0; i--) begin
      if (n[i]) begin
        msb_pos = i;
      end
    end

    // Compute the result
    if (n_is_zero) begin
      result_reg = 17'd1;
    end else if (n_is_pow2) begin
      // When n is a power of two, the result is n (zero-extended to 17 bits)
      result_reg = {1'b0, n};
    end else begin
      // Otherwise, the result is 1 shifted left by (msb_pos+1)
      result_reg = 1 << (msb_pos + 1);
    end
  end

  // Assign the result to the output
  assign result = result_reg;

endmodule