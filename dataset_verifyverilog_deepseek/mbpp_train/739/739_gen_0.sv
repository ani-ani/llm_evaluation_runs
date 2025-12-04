module triangular_index (
  input [2:0] n_digits,
  output reg [8:0] index
);
  always_comb begin
    case (n_digits)
      3'd1: index = 9'd2;
      3'd2: index = 9'd4;
      3'd3: index = 9'd14;
      3'd4: index = 9'd45;
      3'd5: index = 9'd142;
      3'd6: index = 9'd447;
      default: index = 9'd0;
    endcase
  end
endmodule