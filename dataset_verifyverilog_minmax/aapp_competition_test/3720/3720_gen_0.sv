module powers_game(
  input reg [7:0] n,
  output logic winner
);

  logic [4:0] arr [0:29];
  assign arr = '{0,1,2,1,4,3,2,1,5,6,2,1,8,7,5,9,8,7,3,4,7,4,2,1,10,9,3,6,11,12};

  integer p, s, i, j;
  logic [4:0] ans;
  logic [31:0] pow;

  // Compute the highest power of 2 <= n
  p = 0;
  while ((1<<p) <= n) 
      p = p+1;
  p = p-1;

  ans = arr[p];
  s = p;

  // Loop i from 3 to 15, but break when i*i>n
  for (i=3; i<=15; i++) begin
      if (i*i > n) 
          break;
      // Skip perfect powers: 4,8,9
      if (i==4 || i==8 || i==9) 
          continue;

      pow = 1;
      for (j=0; j<7; j++) begin
          if (pow * i > n) 
              break;
          pow = pow * i;
      end
      // j is the exponent
      ans = ans ^ arr[j];
      s = s + j;
  end

  // Last part
  ans = ans ^ ((n - s) % 2);

  // Assign winner
  assign winner = (ans != 0) ? 1'b1 : 1'b0;

endmodule