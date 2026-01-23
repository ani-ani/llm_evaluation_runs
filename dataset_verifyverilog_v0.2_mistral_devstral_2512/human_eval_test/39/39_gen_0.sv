module prime_fib(
  input [3:0] n,
  output [31:0] result
);

  always_comb begin
    case (n)
      4'd1: result = 32'h00000002; // 2
      4'd2: result = 32'h00000003; // 3
      4'd3: result = 32'h00000005; // 5
      4'd4: result = 32'h0000000D; // 13
      4'd5: result = 32'h00000059; // 89
      4'd6: result = 32'h000000E9; // 233
      4'd7: result = 32'h0000063D; // 1597
      4'd8: result = 32'h00006FF1; // 28657
      default: result = 32'h00000000; // 0
    endcase
  end

endmodule