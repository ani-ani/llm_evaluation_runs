module license_scheduling (
  input [2:0] n,
  input [5:0] s1,
  input [5:0] s2,
  input [7:0][5:0] t,
  output reg [2:0] max_customers
);

  reg [8:0][64:0][64:0] dp;
  integer i, t1, t2;
  reg [2:0] max_i;

  always @* begin
    // Initialize dp array
    for (i = 0; i <= 8; i = i + 1) begin
      for (t1 = 0; t1 <= 64; t1 = t1 + 1) begin
        for (t2 = 0; t2 <= 64; t2 = t2 + 1) begin
          dp[i][t1][t2] = 0;
        end
      end
    end
    dp[0][0][0] = 1;

    // Dynamic programming computation
    for (i = 1; i <= n; i = i + 1) begin
      for (t1 = 0; t1 <= s1; t1 = t1 + 1) begin
        for (t2 = 0; t2 <= s2; t2 = t2 + 1) begin
          // Option 1: Assign to counter 1
          if (t1 >= t[i-1] && dp[i-1][t1 - t[i-1]][t2]) begin
            dp[i][t1][t2] = 1;
          end
          // Option 2: Assign to counter 2
          else if (t2 >= t[i-1] && dp[i-1][t1][t2 - t[i-1]]) begin
            dp[i][t1][t2] = 1;
          end
          // Option 3: Customer leaves (carry forward previous state)
          else if (dp[i-1][t1][t2]) begin
            dp[i][t1][t2] = 1;
          end
        end
      end
    end

    // Find maximum number of customers served
    max_i = 0;
    for (i = n; i >= 1; i = i - 1) begin
      for (t1 = 0; t1 <= s1; t1 = t1 + 1) begin
        for (t2 = 0; t2 <= s2; t2 = t2 + 1) begin
          if (dp[i][t1][t2]) begin
            max_i = i;
          end
        end
      end
    end

    max_customers = max_i;
  end

endmodule