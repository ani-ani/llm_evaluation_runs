module TopModule(
  input clk,
  input areset,
  input bump_left,
  input bump_right,
  input ground,
  output reg walk_left,
  output reg walk_right,
  output reg aaah
);

  // State encoding
  typedef enum reg [1:0] {
    WALK_LEFT = 2'b00,
    WALK_RIGHT = 2'b01,
    FALL_LEFT = 2'b10,
    FALL_RIGHT = 2'b11
  } state_t;

  state_t current_state, next_state;

  // State register with asynchronous reset
  always @(posedge clk or posedge areset) begin
    if (areset)
      current_state <= WALK_LEFT;
    else
      current_state <= next_state;
  end

  // Next state logic
  always @(*) begin
    case (current_state)
      WALK_LEFT: begin
        if (!ground)
          next_state = FALL_LEFT;
        else if (bump_left)
          next_state = WALK_RIGHT;
        else if (bump_right)
          next_state = WALK_LEFT;
        else
          next_state = WALK_LEFT;
      end

      WALK_RIGHT: begin
        if (!ground)
          next_state = FALL_RIGHT;
        else if (bump_right)
          next_state = WALK_LEFT;
        else if (bump_left)
          next_state = WALK_RIGHT;
        else
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

      default: next_state = WALK_LEFT;
    endcase
  end

  // Output logic (Moore machine - outputs depend only on current state)
  always @(*) begin
    walk_left = 1'b0;
    walk_right = 1'b0;
    aaah = 1'b0;

    case (current_state)
      WALK_LEFT: begin
        walk_left = 1'b1;
        walk_right = 1'b0;
        aaah = 1'b0;
      end

      WALK_RIGHT: begin
        walk_left = 1'b0;
        walk_right = 1'b1;
        aaah = 1'b0;
      end

      FALL_LEFT: begin
        walk_left = 1'b0;
        walk_right = 1'b0;
        aaah = 1'b1;
      end

      FALL_RIGHT: begin
        walk_left = 1'b0;
        walk_right = 1'b0;
        aaah = 1'b1;
      end
    endcase
  end

endmodule