module triplet_counter(input reg [3:0] n, output reg [5:0] count);
  always_comb begin
    case (n)
      4'd1: count = 6'd0;
      4'd2: count = 6'd0;
      4'd3: count = 6'd0;
      4'd4: count = 6'd1;
      4'd5: count = 6'd1;
      4'd6: count = 6'd4;
      4'd7: count = 6'd10;
      4'd8: count = 6'd11;
      default: count = 6'd0;
    endcase
  end
endmodule