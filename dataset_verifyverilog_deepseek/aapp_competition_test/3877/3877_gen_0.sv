module bit_range_count(
  input [15:0] n,
  input [4:0] l,
  input [4:0] r,
  output reg [4:0] count
);

  function integer floor_div(input integer x, y);
    if (y == 0)
      return 0;
    else begin
      integer quotient;
      integer remainder;
      quotient = x / y;
      remainder = x % y;
      if (x < 0 && remainder != 0) begin
        quotient = quotient - 1;
      end
      return quotient;
    end
  endfunction

  integer L;
  integer R;
  integer i;

  always_comb begin
    L = l - 1;
    R = r - 1;
    count = 0;
    for (i = 0; i < 16; i = i + 1) begin
      integer m = 1 << (i + 1);
      integer a = (1 << i) - 1;
      integer term1, term2, contrib;

      term1 = floor_div(R - a, m);
      term2 = floor_div(L - 1 - a, m);
      contrib = term1 - term2;

      if (contrib < 0) begin
        contrib = 0;
      end

      count = count + contrib * n[i];
    end
  end

endmodule