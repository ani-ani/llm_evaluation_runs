module last_fact_digit(input [4:0] n, output reg [3:0] last_digit);
  always_comb begin
    case(n)
      5'd0: last_digit = 4'd1;
      5'd1: last_digit = 4'd1;
      5'd2: last_digit = 4'd2;
      5'd3: last_digit = 4'd6;
      5'd4: last_digit = 4'd4;
      default: last_digit = 4'd0;
    endcase
  end
endmodule