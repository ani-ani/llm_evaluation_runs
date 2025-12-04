module binomial_sum_product(input [2:0] n, output reg [7:0] result);
  always_comb begin
    case (n)
      3'd1: result = 8'd1;
      3'd2: result = 8'd4;
      3'd3: result = 8'd15;
      3'd4: result = 8'd56;
      3'd5: result = 8'd210;
      default: result = 8'd0;
    endcase
  end
endmodule