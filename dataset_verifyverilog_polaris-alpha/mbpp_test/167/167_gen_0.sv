module next_power_of_two (
  input  [15:0] n,
  output [16:0] result
);

  // Detect if n is zero
  wire n_is_zero = (n == 16'd0);

  // Detect if n is power of two (n != 0) && ((n & (n-1)) == 0)
  wire [15:0] n_minus_1 = n - 16'd1;
  wire [15:0] n_and_n_minus_1 = n & n_minus_1;
  wire n_is_power_of_two = (~n_is_zero) & (n_and_n_minus_1 == 16'd0);

  // Priority encoder to find position of highest set bit (0-15)
  // If n is zero, position will default to 0 (doesn't matter, as handled separately)
  reg [4:0] highest_bit_pos;
  always @* begin
    casex (n)
      16'b1xxx_xxxx_xxxx_xxxx: highest_bit_pos = 5'd15;
      16'b01xx_xxxx_xxxx_xxxx: highest_bit_pos = 5'd14;
      16'b001x_xxxx_xxxx_xxxx: highest_bit_pos = 5'd13;
      16'b0001_xxxx_xxxx_xxxx: highest_bit_pos = 5'd12;
      16'b0000_1xxx_xxxx_xxxx: highest_bit_pos = 5'd11;
      16'b0000_01xx_xxxx_xxxx: highest_bit_pos = 5'd10;
      16'b0000_001x_xxxx_xxxx: highest_bit_pos = 5'd9;
      16'b0000_0001_xxxx_xxxx: highest_bit_pos = 5'd8;
      16'b0000_0000_1xxx_xxxx: highest_bit_pos = 5'd7;
      16'b0000_0000_01xx_xxxx: highest_bit_pos = 5'd6;
      16'b0000_0000_001x_xxxx: highest_bit_pos = 5'd5;
      16'b0000_0000_0001_xxxx: highest_bit_pos = 5'd4;
      16'b0000_0000_0000_1xxx: highest_bit_pos = 5'd3;
      16'b0000_0000_0000_01xx: highest_bit_pos = 5'd2;
      16'b0000_0000_0000_001x: highest_bit_pos = 5'd1;
      16'b0000_0000_0000_0001: highest_bit_pos = 5'd0;
      default:                  highest_bit_pos = 5'd0;
    endcase
  end

  // Compute next power-of-two candidate = 1 << (highest_bit_pos + 1)
  wire [4:0] shift_amt = highest_bit_pos + 5'd1;
  wire [16:0] next_pow_candidate = 17'd1 << shift_amt;

  // Final result selection
  assign result = (n_is_zero)         ? 17'd1 :
                  (n_is_power_of_two) ? {1'b0, n} :
                                       next_pow_candidate;

endmodule