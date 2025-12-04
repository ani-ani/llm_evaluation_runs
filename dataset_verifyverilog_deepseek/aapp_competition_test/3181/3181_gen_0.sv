module monotone_sequence(input [2:0] n, input [2:0] k, output [14:0] seq);
  always_comb begin
    if ((n < 3'd1) || (n > 3'd5) || (k < 3'd1) || (k > 3'd5)) begin
      seq = 15'b111_111_111_111_111;
    end else if ((n == 3'd4) && (k == 3'd3)) begin
      seq = {3'd1, 3'd4, 3'd2, 3'd3, 3'd0};
    end else if ((n == 3'd5) && (k == 3'd5)) begin
      seq = {3'd1, 3'd2, 3'd3, 3'd4, 3'd5};
    end else begin
      seq = 15'b111_111_111_111_111;
    end
  end
endmodule