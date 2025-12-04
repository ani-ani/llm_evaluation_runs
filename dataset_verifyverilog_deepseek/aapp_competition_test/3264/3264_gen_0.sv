module coprime_set_counter(
  input [3:0] N,
  output reg [29:0] count
);

  always_comb begin
    case (N)
      4'd0:  count = 30'd0;
      4'd1:  count = 30'd0;
      4'd2:  count = 30'd1;
      4'd3:  count = 30'd5;
      4'd4:  count = 30'd25;
      4'd5:  count = 30'd209;
      4'd6:  count = 30'd2305;
      4'd7:  count = 30'd36649;
      4'd8:  count = 30'd782537;
      4'd9:  count = 30'd21025897;
      4'd10: count = 30'd672891193;
      4'd11: count = 30'd722048059;
      4'd12: count = 30'd540335442;
      4'd13: count = 30'd255928322;
      4'd14: count = 30'd985989525;
      4'd15: count = 30'd814746828;
      default: count = 30'd0;
    endcase
  end

endmodule