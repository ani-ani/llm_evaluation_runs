module TopModule(input [2:0] y, input w, output Y1);
  logic next_y1;
  always_comb begin
    case(y)
      3'b000: next_y1 = 1'b0; // A
      3'b001: next_y1 = 1'b1; // B
      3'b010: next_y1 = w; // C
      3'b011: next_y1 = 1'b0; // D
      3'b100: next_y1 = w; // E
      3'b101: next_y1 = 1'b1; // F
      default: next_y1 = 1'b0; // invalid
    endcase
  end
  assign Y1 = next_y1;
endmodule