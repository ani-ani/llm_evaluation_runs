module catalan_lookup(input [3:0] n, output reg [14:0] catalan);
  always_comb begin
    case (n)
      4'd0: catalan = 15'd1;
      4'd1: catalan = 15'd1;
      4'd2: catalan = 15'd2;
      4'd3: catalan = 15'd5;
      4'd4: catalan = 15'd14;
      4'd5: catalan = 15'd42;
      4'd6: catalan = 15'd132;
      4'd7: catalan = 15'd429;
      4'd8: catalan = 15'd1430;
      4'd9: catalan = 15'd4862;
      4'd10: catalan = 15'd16796;
      default: catalan = 15'd0;
    endcase
  end
endmodule