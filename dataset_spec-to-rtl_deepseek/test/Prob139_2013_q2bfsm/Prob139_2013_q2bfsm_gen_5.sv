module TopModule(input clk, resetn, x, y, output f, g);
  typedef enum logic [2:0] {A, B, C, D0, D1, D_done1, D_done0} state_t;
  state_t state, next_state;
  reg [2:0] x_hist;

  always_ff @(posedge clk) begin
    if (!resetn) state <= A;
    else state <= next_state;
  end

  always_ff @(posedge clk) begin
    if (state == C) x_hist <= {x_hist[1:0], x};
    else x_hist <= 3'b0;
  end

  always_comb begin
    next_state = state;
    case (state)
      A: if (resetn) next_state = B;
      B: next_state = C;
      C: if (x_hist == 3'b101) next_state = D0;
      D0: next_state = y ? D_done1 : D1;
      D1: next_state = y ? D_done1 : D_done0;
      D_done1, D_done0: next_state = state;
      default: next_state = A;
    endcase
  end

  assign f = (state == B);
  assign g = (state == D0 || state == D1 || state == D_done1);
endmodule