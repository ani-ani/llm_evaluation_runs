module TopModule(input clk, reset, w, output z);
  typedef enum logic [2:0] {A=3'b000, B=3'b001, C=3'b010, D=3'b011, E=3'b100, F=3'b101} state_t;
  state_t state, next_state;

  always_ff @(posedge clk) begin
    if (reset)
      state <= A;
    else
      state <= next_state;
  end

  always_comb begin
    next_state = A;
    case (state)
      A: next_state = w ? B : A;
      B: next_state = w ? C : D;
      C: next_state = w ? E : D;
      D: next_state = w ? F : A;
      E: next_state = w ? E : D;
      F: next_state = w ? C : D;
      default: next_state = A;
    endcase
  end

  assign z = (state == E) || (state == F);
endmodule