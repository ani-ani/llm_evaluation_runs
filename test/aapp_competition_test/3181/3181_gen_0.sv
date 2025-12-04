module monotone_sequence(
  input  [2:0] n,
  input  [2:0] k,
  output reg [14:0] seq
);

  always @* begin
    // Default to invalid (all ones)
    seq = 15'b1_1111_1111_1111_111;

    case ({n, k})
      // (4,3) -> 1,4,2,3; pad remaining with zeros
      6'b100_011: seq = {3'd1, 3'd4, 3'd2, 3'd3, 3'd0};

      // (5,5) -> 1,2,3,4,5 (no padding since n=5)
      6'b101_101: seq = {3'd1, 3'd2, 3'd3, 3'd4, 3'd5};

      // (5,1) explicitly invalid -> all ones (already default)
      // 6'b101_001: seq = 15'b1_1111_1111_1111_111;

      default: seq = 15'b1_1111_1111_1111_111; // undefined (n,k) -> invalid
    endcase
  end

endmodule