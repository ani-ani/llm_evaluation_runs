module TopModule(input clk, input reset, input in, output out);
  typedef enum logic [1:0] {A = 2'b00, B = 2'b01, C = 2'b10, D = 2'b11} state_t;
  state_t state_reg, next_state;

  always_ff @(posedge clk) begin
    if (reset) state_reg <= A;
    else       state_reg <= next_state;
  end

  always_comb begin
    case (state_reg)
      A: next_state = in ? B : A;
      B: next_state = in ? B : C;
      C: next_state = in ? D : A;
      D: next_state = in ? B : C;
      default: next_state = A;
    endcase
  end

  assign out = (state_reg == D);
endmodule