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
    S_LEFT,
    S_RIGHT,
    S_FALLING_LEFT,
    S_FALLING_RIGHT
  } state_t;
  
  state_t state, next_state;
  
  always_ff @(posedge clk or posedge areset) begin
    if (areset)
      state <= S_LEFT;
    else
      state <= next_state;
  end
  
  always_comb begin
    case (state)
      S_LEFT:        next_state = ground ? (bump_left ? S_RIGHT : S_LEFT) : S_FALLING_LEFT;
      S_RIGHT:       next_state = ground ? (bump_right ? S_LEFT : S_RIGHT) : S_FALLING_RIGHT;
      S_FALLING_LEFT:  next_state = ground ? S_LEFT : S_FALLING_LEFT;
      S_FALLING_RIGHT: next_state = ground ? S_RIGHT : S_FALLING_RIGHT;
      default:       next_state = S_LEFT;
    endcase
  end
  
  assign walk_left = (state == S_LEFT);
  assign walk_right = (state == S_RIGHT);
  assign aaah = (state == S_FALLING_LEFT || state == S_FALLING_RIGHT);
endmodule