module TopModule(
  input [2:0] y,
  input w,
  output Y1
);

  reg y1_next;

  always @(*) begin
    case(y)
      3'b000: y1_next = 1'b0;  // State A: next is B (001) if w=0, A (000) if w=1
      3'b001: y1_next = w;      // State B: next is C (010) if w=0, D (011) if w=1
      3'b010: y1_next = w;      // State C: next is E (100) if w=0, D (011) if w=1
      3'b011: y1_next = 1'b0;   // State D: next is F (101) if w=0, A (000) if w=1
      3'b100: y1_next = 1'b0;   // State E: next is E (100) if w=0, D (011) if w=1
      3'b101: y1_next = 1'b1;   // State F: next is C (010) if w=0, D (011) if w=1
      default: y1_next = 1'b0;
    endcase
  end

  assign Y1 = y1_next;

endmodule