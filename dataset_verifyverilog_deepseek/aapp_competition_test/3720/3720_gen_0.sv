module powers_game(
  input [7:0] n,
  output winner
);
  localparam bit [4:0] arr [0:29] = '{0,1,2,1,4,3,2,1,5,6,2,1,8,7,5,9,8,7,3,4,7,4,2,1,10,9,3,6,11,12};
  
  function automatic integer log2(input [7:0] n);
    integer i;
    begin
      log2 = 0;
      for (i=7; i>=0; i=i-1) begin
        if (n[i]) begin
          log2 = i;
          break;
        end
      end
    end
  endfunction
  
  function automatic bit is_perfect_power(input integer i);
    begin
      is_perfect_power = (i ==4 || i ==8 || i ==9);
    end
  endfunction
  
  function automatic integer highest_power(input integer base, input [7:0] n);
    integer p, pow;
    begin
      p = 0;
      pow = 1;
      while (pow <= n / base) begin
        pow = pow * base;
        p = p + 1;
      end
      highest_power = p;
    end
  endfunction
  
  function automatic integer sqrt_n(input [7:0] n);
    integer i;
    begin
      sqrt_n = 0;
      for (i=1; i<=15; i=i+1) begin
        if (i*i <= n) sqrt_n = i;
        else break;
      end
    end
  endfunction
  
  logic [4:0] ans;
  integer s, sqrt_val, i, p;
  
  always_comb begin
    integer log2n = log2(n);
    ans = arr[log2n];
    s = log2n;
    sqrt_val = sqrt_n(n);
    for (i=3; i <= sqrt_val; i=i+1) begin
      if (!is_perfect_power(i)) begin
        p = highest_power(i, n);
        ans = ans ^ arr[p];
        s = s + p;
      end
    end
    ans = ans ^ ((n - s) & 1);
    winner = (ans != 0) ? 1'b1 : 1'b0;
  end
endmodule