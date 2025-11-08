module TopModule(
  input clk,
  input areset,
  input bump_left,
  input bump_right,
  input ground,
  output walk_left,
  output walk_right,
  output aaah
};

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
        WALK_LEFT: begin
          if (ground == 0) begin
            state <= FALL_LEFT;
          end else if (bump_left) begin
            state <= WALK_RIGHT;
          end else begin
            state <= WALK_LEFT;
          end
        end
        WALK_RIGHT: begin
          if (ground == 0) begin
            state <= FALL_RIGHT;
          end else if (bump_right) begin
            state <= WALK_LEFT;
          end else begin
            state <= WALK_RIGHT;
          end
        end
        FALL_LEFT: begin
          if (ground == 1) begin
            state <= WALK_LEFT;
          end else begin
            state <= FALL_LEFT;
          end
        end
        FALL_RIGHT: begin
          if (ground == 1) begin
            state <= WALK_RIGHT;
          end else begin
            state <= FALL_RIGHT;
          end
        end
      endcase
    end
  end

  assign walk_left = (state == WALK_LEFT);
  assign walk_right = (state == WALK_RIGHT);
  assign aaah = state[1];

endmodule