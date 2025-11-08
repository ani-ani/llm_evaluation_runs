module TopModule(
  input clk,
  input resetn,
  input x,
  input y,
  output f,
  output g
);
  typedef enum {A, F, M0, M1, M2, SET_G, CHECK1, CHECK2, G_PERM, NO_G} state_t;
  state_t state, next_state;

  always @(posedge clk) begin
    if (!resetn) begin
      state <= A;
    end else begin
      state <= next_state;
    end
  end

  always @(*) begin
    case (state)
      A: next_state = F;
      F: next_state = M0;
      M0: next_state = (x == 1) ? M1 : M0;
      M1: next_state = (x == 0) ? M2 : M0;
      M2: next_state = (x == 1) ? SET_G : M0;
      SET_G: next_state = CHECK1;
      CHECK1: next_state = (y == 1) ? G_PERM : CHECK2;
      CHECK2: next_state = (y == 1) ? G_PERM : NO_G;
      G_PERM: next_state = G_PERM;
      NO_G: next_state = NO_G;
      default: next_state = A;
    endcase
  end

  assign f = (state == F) ? 1'b1 : 1'b0;
  assign g = (state inside {SET_G, CHECK1, CHECK2, G_PERM}) ? 1'b1 : 1'b0;
endmodule