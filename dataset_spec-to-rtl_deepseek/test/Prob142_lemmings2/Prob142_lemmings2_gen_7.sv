module TopModule(input clk, input areset, input bump_left, input bump_right, input ground, output walk_left, output walk_right, output aaah);
  parameter LEFT = 2'b00, RIGHT = 2'b01, FALLING_LEFT = 2'b10, FALLING_RIGHT = 2'b11;
  reg [1:0] state, next_state;
  always @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= LEFT;
    end else begin
      state <= next_state;
    end
  end
  always @(*) begin
    case (state)
      LEFT:   next_state = (!ground) ? FALLING_LEFT : (bump_left ? RIGHT : LEFT);
      RIGHT:  next_state = (!ground) ? FALLING_RIGHT : (bump_right ? LEFT : RIGHT);
      FALLING_LEFT:  next_state = (ground) ? LEFT : FALLING_LEFT;
      FALLING_RIGHT: next_state = (ground) ? RIGHT : FALLING_RIGHT;
      default: next_state = LEFT;
    endcase
  end
  assign walk_left = (state == LEFT);
  assign walk_right = (state == RIGHT);
  assign aaah = (state == FALLING_LEFT) || (state == FALLING_RIGHT);
endmodule