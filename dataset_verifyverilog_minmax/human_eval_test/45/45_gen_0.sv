module triangle_area (
  input  reg [15:0] a,   // Q8.8 fixed-point
  input  reg [15:8] h,   // Q8.8 fixed-point
  output wire [15:0] area // Q8.8 fixed-point
);
  // Compute area = (a * h) / 2 using Q8.8 arithmetic.
  // Multiply: Q8.8 * Q8.8 -> Q16.16 (32 bits)
  // Divide by 2: >> 1 -> Q15.15 (31 bits), then round and convert to Q8.8.

  // Rounded Q15.15 -> Q8.8 result (16-bit), saturating on overflow.
  logic [15:0] area_q8_8;

  always_comb begin
    // Product in Q16.16
    logic [31:0] product;
    product = $unsigned(a) * $unsigned(h);

    // Rounded Q15.15 (rounding nearest, ties to even)
    logic [15:0] rounded_q8_8;
    logic [15:0] pre_round;

    // If positive (or zero)
    if (product[31] == 1'b0) begin
      // Round half-up: add 0.5 = 2^6
      pre_round = (product[30:15] + ((product[14] & (|product[13:0])) ? 1 : 0));
      // Apply tie-to-even by clearing bit 0 when exactly 0.5
      if ((product[14] == 1'b1) && (product[13:0] == 14'b0)) begin
        pre_round = product[30:15];
      end
      // Clamp to 16 bits on overflow (all ones if overflow)
      rounded_q8_8 = pre_round;
    end else begin
      // If negative: (x - 0.5) >> 1 -> effectively round toward -inf
      pre_round = (product[30:15] - 1) + ((~product[14]) & (|product[13:0]) ? 1 : 0);
      // Clamp to 16 bits on overflow (all ones if overflow)
      rounded_q8_8 = pre_round;
    end

    // Saturate to positive 16-bit max if overflow occurred (sign bit set)
    area_q8_8 = rounded_q8_8[15] ? 16'h7FFF : rounded_q8_8;
  end

  assign area = area_q8_8;
endmodule