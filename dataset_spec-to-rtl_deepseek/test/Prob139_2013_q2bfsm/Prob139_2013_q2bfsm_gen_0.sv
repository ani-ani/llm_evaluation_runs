module TopModule(input clk, input resetn, input x, input y, output logic f, output logic g);
  typedef enum logic [3:0] {A, B, C, D, E, F, G, H, I} state_t;
  state_t current_state, next_state;

  always_ff @(posedge clk) begin
    if (!resetn) current_state <= A;
    else current_state <= next_state;
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      A: if (resetn) next_state = B;
      B: next_state = C;
      C: if (x) next_state = D; else next_state = C;
      D: if (!x) next_state = E; else next_state = C;
      E: if (x) next_state = F; else next_state = C;
      F: if (y) next_state = H; else next_state = G;
      G: if (y) next_state = H; else next_state = I;
      H: next_state = H;
      I: next_state = I;
      default: next_state = A;
    endcase
  end

  always_comb begin
    f = (current_state == B);
    g = (current_state == F || current_state == G || current_state == H);
  end
endmodule