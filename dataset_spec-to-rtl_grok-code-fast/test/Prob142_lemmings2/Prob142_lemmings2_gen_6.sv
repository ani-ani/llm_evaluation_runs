module TopModule(
  input logic clk,
  input logic areset,
  input logic bump_left,
  input logic bump_right,
  input logic ground,
  output logic walk_left,
  output logic walk_right,
  output logic aaah
);

  typedef enum logic[1:0] {WALK_L, WALK_R, FALL_L, FALL_R} state_t;
  state_t current_state, next_state;

  // State register
  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      current_state <= WALK_L;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always_comb begin
    next_state = current_state;
    case (current_state)
      WALK_L: begin
        if (!ground) next_state = FALL_L;
        else if (bump_left) next_state = WALK_R;
      end
      WALK_R: begin
        if (!ground) next_state = FALL_R;
        else if (bump_right) next_state = WALK_L;
      end
      FALL_L: begin
        if (ground) next_state = WALK_L;
      end
      FALL_R: begin
        if (ground) next_state = WALK_R;
      end
    endcase
  end

  // Outputs
  assign walk_left = (current_state == WALK_L);
  assign walk_right = (current_state == WALK_R);
  assign aaah = (current_state == FALL_L || current_state == FALL_R);

endmodule