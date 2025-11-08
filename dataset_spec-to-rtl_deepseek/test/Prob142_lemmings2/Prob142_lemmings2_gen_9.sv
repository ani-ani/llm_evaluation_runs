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
  
  typedef enum logic [1:0] { LEFT, RIGHT, FALLING } state_t;
  state_t state, next_state, prev_dir;
  
  always_ff @(posedge clk, posedge areset) begin
    if (areset) begin
      state <= LEFT;
      prev_dir <= LEFT;
    end else begin
      state <= next_state;
      if (state != FALLING && next_state == FALLING) prev_dir <= state;
    end
  end
  
  always_comb begin
    case (state)
      LEFT: 
        if (!ground) next_state = FALLING;
        else next_state = bump_left ? RIGHT : LEFT;
      RIGHT: 
        if (!ground) next_state = FALLING;
        else next_state = bump_right ? LEFT : RIGHT;
      FALLING: 
        next_state = ground ? prev_dir : FALLING;
      default: 
        next_state = LEFT;
    endcase
  end
  
  assign walk_left = (state == LEFT);
  assign walk_right = (state == RIGHT);
  assign aaah = (state == FALLING);
  
endmodule