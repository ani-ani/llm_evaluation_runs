module min_jumps(
  input  [7:0] a,
  input  [7:0] b,
  input  [7:0] d,
  output [15:0] jumps
);

  // Tie-step operation
  wire [7:0] min_ab  = (a < b) ? a : b;
  wire [7:0] max_ab  = (a < b) ? b : a;
  wire [7:0] a_tie   = min_ab;
  wire [7:0] b_tie   = max_ab;

  // Conditions
  wire d_is_zero     = (d == 8'd0);
  wire d_eq_a        = (d == a_tie);
  wire d_lt_b        = (d <  b_tie);
  wire d_ge_b        = (d >= b_tie);

  // Q8.8 constants
  localparam [15:0] ONE_JUMP  = 16'h0100; // 1.0 in Q8.8
  localparam [15:0] TWO_JUMP  = 16'h0200; // 2.0 in Q8.8

  // For d >= b: jumps = ((d + b - 1) * 256) / b
  // Use b_tie as divisor per spec
  wire [8:0]  d_plus_b_minus_1 = {1'b0, d} + {1'b0, b_tie} - 9'd1; // up to 9 bits
  wire [16:0] scaled_num       = {d_plus_b_minus_1, 8'b0};        // *256, up to 17 bits

  // Combinational integer division (truncated) by b_tie (8-bit, assumed non-zero when used)
  reg [16:0] quotient;
  integer i;
  always @* begin
    if (b_tie == 8'd0) begin
      // Degenerate case: avoid divide-by-zero; return 0
      quotient = 17'd0;
    end else begin
      // Unsigned restoring division: quotient = scaled_num / b_tie
      reg [16:0] rem;
      reg [16:0] q;
      rem = 17'd0;
      q   = 17'd0;
      for (i = 16; i >= 0; i = i - 1) begin
        rem = {rem[15:0], scaled_num[i]};
        if (rem >= b_tie) begin
          rem = rem - b_tie;
          q[i] = 1'b1;
        end
      end
      quotient = q;
    end
  end

  wire [15:0] jumps_ge_b = quotient[15:0];

  // Priority-based selection according to spec
  // 1) d == 0 -> 0
  // 2) d == a -> 1.0
  // 3) d < b and d != a and d != 0 -> 2.0
  // 4) d >= b -> computed formula
  assign jumps = d_is_zero               ? 16'd0      :
                 d_eq_a                  ? ONE_JUMP   :
                 (d_lt_b && !d_is_zero && !d_eq_a) ? TWO_JUMP :
                 (d_ge_b ? jumps_ge_b : 16'd0);

endmodule