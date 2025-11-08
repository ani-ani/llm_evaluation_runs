module TopModule(
  input clk,
  input areset,
  input bump_left,
  input bump_right,
  input ground,
  output walk_left,
  output walk_right,
  output aaah
);

  // State encoding
  typedef enum logic [1:0] {
    WALK_LEFT  = 2'b00,
    WALK_RIGHT = 2'b01,
    FALL_LEFT  = 2'b10,
    FALL_RIGHT = 2'b11
  } state_t;

  state_t current_state, next_state;

  // State register with asynchronous reset
  always_ff @(posedge clk or posedge areset) begin
    if (areset)
      current_state <= WALK_LEFT;
    else
      current_state <= next_state;
  end

  // Next state logic
  always_comb begin
    next_state = current_state;
    
    case (current_state)
      WALK_LEFT: begin
        if (!ground)
          next_state = FALL_LEFT;
        else if (bump_left)
          next_state = WALK_RIGHT;
        else if (bump_right)
          next_state = WALK_LEFT;
      end
      
      WALK_RIGHT: begin
        if (!ground)
          next_state = FALL_RIGHT;
        else if (bump_right)
          next_state = WALK_LEFT;
        else if (bump_left)
          next_state = WALK_RIGHT;
      end
      
      FALL_LEFT: begin
        if (ground)
          next_state = WALK_LEFT;
        else
          next_state = FALL_LEFT;
      end
      
      FALL_RIGHT: begin
        if (ground)
          next_state = WALK_RIGHT;
        else
          next_state = FALL_RIGHT;
      end
    endcase
  end

  // Output logic (Moore machine - outputs depend only on current state)
  assign walk_left = (current_state == WALK_LEFT);
  assign walk_right = (current_state == WALK_RIGHT);
  assign aaah = (current_state == FALL_LEFT) || (current_state == FALL_RIGHT);

endmodule