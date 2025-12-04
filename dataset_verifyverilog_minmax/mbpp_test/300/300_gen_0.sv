module binary_sequence_count(
  input logic [3:0] n,
  output logic [7:0] count
);
  // Compute sum_{r=0}^{n} C(n, r)^2 for 1 <= n <= 4 using parallel hardware ops.
  // For n outside [1,4], output 0.
  always_comb begin
    case (n)
      4'd1: count = 2;  // C(1,0)^2 + C(1,1)^2 = 1 + 1
      4'd2: count = 6;  // 1^2 + 2^2 + 1^2 = 6
      4'd3: count = 20; // 1^2 + 3^2 + 3^2 + 1^2 = 20
      4'd4: count = 70; // 1^2 + 6^2 + 6^2 + 4^2 + 1^2 = 70
      default: count = 8'd0;
    endcase
  end
endmodule