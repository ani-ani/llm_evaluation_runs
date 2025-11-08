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

  localparam WALK_LEFT = 2'b00;
  localparam WALK_RIGHT = 2'b01;
  localparam FALL_LEFT = 2'b10;
  localparam FALL_RIGHT = 2'b11;

  reg [1:0] state;

  always @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= WALK_LEFT;
    end else begin
      case (state)
        WALK_LEFT:
          if (!ground) begin
            state <= FALL_LEFT;
          end else if (bump_left || bump_right) begin
            state <= WALK_RIGHT;
          end else begin
            state <= WALK_LEFT;
          end
        WALK_RIGHT:
          if (!ground) begin
            state <= FALL_RIGHT;
          end else if (bump_left || bump_right) begin
            state <= WALK_LEFT;
          end else begin
            state <= WALK_RIGHT;
          end
        FALL_LEFT:
          if (ground) begin
            state <= WALK_LEFT;
          end else begin
            state <= FALL_LEFT;
          end
        FALL_RIGHT:
          if (ground) begin
            state <= WALK_RIGHT;
          end else begin
            state <= FALL_RIGHT;
          end
      endcase
    end
  end

  assign walk_left = (state == WALK_LEFT);
  assign walk_right = (state == WALK_RIGHT);
  assign aaah = (state == FALL_LEFT || state == FALL_RIGHT);

endmodule