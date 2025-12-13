module max_triple_lcm(
  input  [7:0]  n,
  output [23:0] max_lcm
);

  // Function: combinational GCD using Euclidean algorithm
  function automatic [7:0] gcd8(
    input [7:0] a_in,
    input [7:0] b_in
  );
    reg [7:0] a, b, t;
    begin
      a = a_in;
      b = b_in;
      // Iterative Euclidean algorithm (combinational)
      while (b != 0) begin
        t = a % b;
        a = b;
        b = t;
      end
      gcd8 = a;
    end
  endfunction

  // Function: LCM of two 8-bit numbers, result up to 16 bits
  function automatic [15:0] lcm2(
    input [7:0] x,
    input [7:0] y
  );
    reg [7:0] g;
    reg [15:0] prod;
    begin
      if (x == 0 || y == 0) begin
        lcm2 = 16'd0;
      end else begin
        g = gcd8(x, y);
        // (x / g) * y fits in 16 bits for x,y <= 255
        prod = (x / g) * y;
        lcm2 = prod;
      end
    end
  endfunction

  // Function: LCM of three numbers using lcm2
  function automatic [23:0] lcm3(
    input [7:0] a,
    input [7:0] b,
    input [7:0] c
  );
    reg [15:0] l_ab;
    reg [7:0]  g;
    reg [23:0] result;
    begin
      // First LCM of a and b
      l_ab = lcm2(a, b);
      if (l_ab == 0 || c == 0) begin
        result = 24'd0;
      end else begin
        g = gcd8(l_ab[15:0], c);
        // (l_ab / g) * c fits in 24 bits for given constraints
        result = (l_ab / g) * c;
      end
      lcm3 = result;
    end
  endfunction

  // Compute search bounds: from max(1, n-7) to n
  wire [7:0] low_raw   = n - 8'd7;
  wire [7:0] low_bound = (n > 8'd7) ? low_raw : 8'd1;

  // Combinational search for maximum LCM among all triplets (i >= j >= k)
  reg [23:0] max_lcm_r;
  integer i, j, k;

  always @* begin
    max_lcm_r = 24'd0;

    for (i = n; i >= low_bound; i = i - 1) begin
      for (j = i; j >= low_bound; j = j - 1) begin
        for (k = j; k >= low_bound; k = k - 1) begin
          if (k >= 1) begin
            reg [23:0] cur_lcm;
            cur_lcm = lcm3(i[7:0], j[7:0], k[7:0]);
            if (cur_lcm > max_lcm_r)
              max_lcm_r = cur_lcm;
          end
        end
      end
    end
  end

  assign max_lcm = max_lcm_r;

endmodule