module TopModule (
  input clk,
  input areset,
  input bump_left,
  input bump_right,
  input ground,
  output reg walk_left,
  output reg walk_right,
  output reg aaah
);
  typedef enum logic [1:0] {LEFT, RIGHT, FALL_LEFT, FALL_RIGHT} state_t;
  state_t state, next_state;
  
  always_comb begin
    next_state = state;
    case (state)
      LEFT: begin
        if (!ground) next_state = FALL_LEFT;
        else if (bump_left || bump_right) next_state = RIGHT;
      end
      RIGHT: begin
        if (!ground) next_state = FALL_RIGHT;
        else if (bump_left || bump_right) next_state = LEFT;
      end
      FALL_LEFT: begin
        if (ground) next_state = LEFT;
      end
      FALL_RIGHT: begin
        if (ground) next_state = RIGHT;
      end
    endcase
  end
  
  always_ff @(posedge clk or posedge areset) begin
    if (areset) state <= LEFT;
    else state <= next_state;
  end
  
  always_comb begin
    walk_left = 0;
    walk_right = 0;
    aaah = 0;
    case (state)
      LEFT: walk_left = 1;
      RIGHT: walk_right = 1;
      FALL_LEFT: aaah = 1;
      FALL_RIGHT: aaah = 1;
    endcase
  end
endmodule