module binary_sequence_count(
  input  [3:0] n,
  output [7:0] count
);

  // For n in [1..4], sum_{r=0}^{n} (C(n,r))^2 = C(2n, n)
  // Implement combinational mapping for 1 <= n <= 4, default 0 otherwise.

  reg [7:0] count_reg;
  assign count = count_reg;

  always @(*) begin
    case (n)
      4'd1: count_reg = 8'd2;   // C(2,1)
      4'd2: count_reg = 8'd6;   // C(4,2)
      4'd3: count_reg = 8'd20;  // C(6,3)
      4'd4: count_reg = 8'd70;  // C(8,4)
      default: count_reg = 8'd0;
    endcase
  end

endmodule