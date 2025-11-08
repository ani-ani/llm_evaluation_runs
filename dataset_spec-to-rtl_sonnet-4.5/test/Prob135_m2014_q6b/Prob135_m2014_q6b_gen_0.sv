module TopModule(
  input [2:0] y,
  input w,
  output Y1
);

  reg y1_next;

  always @(*) begin
    case(y)
      3'b000: y1_next = 1'b0;  // A -> B (w=0) or A (w=1)
      3'b001: y1_next = w;      // B -> C (w=0) or D (w=1)
      3'b010: y1_next = w;      // C -> E (w=0) or D (w=1)
      3'b011: y1_next = w;      // D -> F (w=0) or A (w=1)
      3'b100: y1_next = w;      // E -> E (w=0) or D (w=1)
      3'b101: y1_next = ~w;     // F -> C (w=0) or D (w=1)
      default: y1_next = 1'b0;
    endcase
  end

  assign Y1 = y1_next;

endmodule