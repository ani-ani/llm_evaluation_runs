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

  reg [1:0] state;
  parameter LEFT = 2'b00,
            RIGHT = 2'b01,
            FALL_LEFT = 2'b10,
            FALL_RIGHT = 2'b11;

  always @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= LEFT;
    end else begin
      case (state)
        LEFT: begin
          if (ground == 0) state <= FALL_LEFT;
          else if (bump_left || bump_right) state <= RIGHT;
          else state <= LEFT;
        end
        RIGHT: begin
          if (ground == 0) state <= FALL_RIGHT;
          else if (bump_left || bump_right) state <= LEFT;
          else state <= RIGHT;
        end
        FALL_LEFT: begin
          if (ground == 1) state <= LEFT;
          else state <= FALL_LEFT;
        end
        FALL_RIGHT: begin
          if (ground == 1) state <= RIGHT;
          else state <= FALL_RIGHT;
        end
        default: state <= LEFT;
      endcase
    end
  end

  assign walk_left = (state == LEFT);
  assign walk_right = (state == RIGHT);
  assign aaah = (state == FALL_LEFT || state == FALL_RIGHT);

endmodule