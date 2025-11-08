module TopModule (
  input clk,
  input areset,
  input bump_left,
  input bump_right,
  input ground,
  output walk_left,
  output walk_right,
  output aaah
);
  typedef enum logic [1:0] { WALK_LEFT, WALK_RIGHT, FALL_LEFT, FALL_RIGHT } state_t;
  state_t state, next_state;

  always_ff @(posedge clk or posedge areset) begin
    if (areset) state <= WALK_LEFT;
    else state <= next_state;
  end

  always_comb begin
    case (state)
      WALK_LEFT: next_state = (!ground) ? FALL_LEFT : (bump_left ? WALK_RIGHT : WALK_LEFT);
      WALK_RIGHT: next_state = (!ground) ? FALL_RIGHT : (bump_right ? WALK_LEFT : WALK_RIGHT);
      FALL_LEFT: next_state = ground ? WALK_LEFT : FALL_LEFT;
      FALL_RIGHT: next_state = ground ? WALK_RIGHT : FALL_RIGHT;
      default: next_state = state;
    endcase
  end

  assign walk_left = (state == WALK_LEFT);
  assign walk_right = (state == WALK_RIGHT);
  assign aaah = (state == FALL_LEFT || state == FALL_RIGHT);
endmodule