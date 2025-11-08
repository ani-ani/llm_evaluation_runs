module TopModule(
  input  clk,
  input  areset,
  input  bump_left,
  input  bump_right,
  input  ground,
  output walk_left,
  output walk_right,
  output aaah
);

  localparam LEFT = 0, RIGHT = 1, FALL_LEFT = 2, FALL_RIGHT = 3;
  reg [1:0] state;

  always @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= LEFT;
    end else begin
      case (state)
        LEFT: begin
          if (ground) begin
            state <= bump_left ? RIGHT : LEFT;
          end else begin
            state <= FALL_LEFT;
          end
        end
        RIGHT: begin
          if (ground) begin
            state <= bump_right ? LEFT : RIGHT;
          end else begin
            state <= FALL_RIGHT;
          end
        end
        FALL_LEFT: begin
          state <= ground ? LEFT : FALL_LEFT;
        end
        FALL_RIGHT: begin
          state <= ground ? RIGHT : FALL_RIGHT;
        end
        default: ;  // optional, but good practice
      endcase
    end
  end

  assign walk_left = (state == LEFT);
  assign walk_right = (state == RIGHT);
  assign aaah = (state == FALL_LEFT || state == FALL_RIGHT);

endmodule