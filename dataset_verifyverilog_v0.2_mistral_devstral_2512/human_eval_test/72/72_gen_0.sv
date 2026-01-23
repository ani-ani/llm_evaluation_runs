module will_it_fly (
  input [7:0] w,
  input [2:0] q_len,
  input [7:0] q [0:7],
  output result
);

  wire [11:0] sum;
  wire is_palindrome;

  // Calculate sum of elements
  assign sum = (q_len >= 1) ? q[0] : 0 +
               (q_len >= 2) ? q[1] : 0 +
               (q_len >= 3) ? q[2] : 0 +
               (q_len >= 4) ? q[3] : 0 +
               (q_len >= 5) ? q[4] : 0 +
               (q_len >= 6) ? q[5] : 0 +
               (q_len >= 7) ? q[6] : 0 +
               (q_len >= 8) ? q[7] : 0;

  // Check palindrome
  assign is_palindrome = (q_len <= 1) ? 1'b1 :
                         (q_len == 2) ? (q[0] == q[1]) :
                         (q_len == 3) ? (q[0] == q[2]) :
                         (q_len == 4) ? (q[0] == q[3] && q[1] == q[2]) :
                         (q_len == 5) ? (q[0] == q[4] && q[1] == q[3]) :
                         (q_len == 6) ? (q[0] == q[5] && q[1] == q[4] && q[2] == q[3]) :
                         (q_len == 7) ? (q[0] == q[6] && q[1] == q[5] && q[2] == q[4]) :
                         (q_len == 8) ? (q[0] == q[7] && q[1] == q[6] && q[2] == q[5] && q[3] == q[4]) :
                         1'b0;

  // Final result
  assign result = is_palindrome && (sum <= w);

endmodule