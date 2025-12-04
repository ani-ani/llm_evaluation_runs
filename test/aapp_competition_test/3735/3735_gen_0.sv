module max_digit_sum(
  input [15:0] n,
  output [6:0] max_sum
);

  // Determine L based on ranges
  wire [2:0] L;
  assign L = (n < 16'd10)    ? 3'd1 :
             (n < 16'd100)   ? 3'd2 :
             (n < 16'd1000)  ? 3'd3 :
             (n < 16'd10000) ? 3'd4 :
                                3'd5;

  // Precompute a = 10^(L-1) - 1
  // L=1 -> 0, L=2 -> 9, L=3 -> 99, L=4 -> 999, L=5 -> 9999
  reg [15:0] a;
  always @* begin
    case (L)
      3'd1: a = 16'd0;
      3'd2: a = 16'd9;
      3'd3: a = 16'd99;
      3'd4: a = 16'd999;
      default: a = 16'd9999;
    endcase
  end

  // b = n - a
  wire [15:0] b = n - a;

  // Digit sum function using combinational arithmetic
  function automatic [6:0] digit_sum(input [15:0] x);
    reg [15:0] tmp;
    reg [3:0] d0, d1, d2, d3, d4;
    begin
      tmp = x;
      // Extract digits with /10 and %10
      d0 = tmp % 10; tmp = tmp / 10;
      d1 = tmp % 10; tmp = tmp / 10;
      d2 = tmp % 10; tmp = tmp / 10;
      d3 = tmp % 10; tmp = tmp / 10;
      d4 = tmp % 10;
      digit_sum = d0 + d1 + d2 + d3 + d4;
    end
  endfunction

  wire [6:0] sum_a = digit_sum(a);
  wire [6:0] sum_b = digit_sum(b);

  assign max_sum = sum_a + sum_b;

endmodule