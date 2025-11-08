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
    WALK_LEFT  = 2'b00,
    WALK_RIGHT = 2'b01,
    FALL_LEFT  = 2'b10,
    FALL_RIGHT = 2'b11
  } state_t;

  state_t current_state, next_state;

  assign walk_left = (current_state == WALK_LEFT);
  assign walk_right = (current_state == WALK_RIGHT);
  assign aaah = (current_state inside {FALL_LEFT, FALL_RIGHT});

  always_comb begin
    next_state = current_state;
    if (ground == 1'b0) begin
      next_state = (current_state inside {WALK_LEFT, FALL_LEFT}) ? FALL_LEFT : FALL_RIGHT;
    end else begin
      if (current_state inside {FALL_LEFT, FALL_RIGHT}) begin
        next_state = (current_state == FALL_LEFT) ? WALK_LEFT : WALK_RIGHT;
      end else begin
        // WALK: apply bumps
        case ({bump_right, bump_left})
          2'b00: next_state = current_state;
          2'b01: next_state = WALK_RIGHT;
          2'b10: next_state = WALK_LEFT;
          2'b11: next_state = (current_state == WALK_LEFT) ? WALK_RIGHT : WALK_LEFT;
        endcase
      end
    end
  end

  always @(posedge clk or posedge areset) begin
    if (areset) begin
      current_state <= WALK_LEFT;
    end else begin
      current_state <= next_state;
    end
  end

endmodule