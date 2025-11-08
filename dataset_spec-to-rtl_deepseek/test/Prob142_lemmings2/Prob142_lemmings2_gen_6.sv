module TopModule (
  input  clk,
  input  areset,
  input  bump_left,
  input  bump_right,
  input  ground,
  output walk_left,
  output walk_right,
  output aaah
);

  typedef enum logic [1:0] {
    WL,
    WR,
    FL,
    FR
  } state_t;

  state_t state, next_state;

  always_ff @(posedge clk, posedge areset) begin
    if (areset)
      state <= WL;
    else
      state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      WL: next_state = (!ground) ? FL : (bump_left ? WR : WL);
      WR: next_state = (!ground) ? FR : (bump_right ? WL : WR);
      FL: next_state = (ground) ? WL : FL;
      FR: next_state = (ground) ? WR : FR;
      default: next_state = WL;
    endcase
  end

  assign walk_left = (state == WL);
  assign walk_right = (state == WR);
  assign aaah = ((state == FL) || (state == FR));

endmodule