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

  localparam WL = 2'b00;
  localparam WR = 2'b01;
  localparam FL = 2'b10;
  localparam FR = 2'b11;

  reg [1:0] state, next_state;

  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= WL;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      WL: begin
        if (!ground) next_state = FL;
        else if (bump_left | bump_right) next_state = WR;
        else next_state = WL;
      end
      WR: begin
        if (!ground) next_state = FR;
        else if (bump_left | bump_right) next_state = WL;
        else next_state = WR;
      end
      FL: begin
        if (ground) next_state = WL;
        else next_state = FL;
      end
      FR: begin
        if (ground) next_state = WR;
        else next_state = FR;
      end
    endcase
  end

  always_comb begin
    walk_left = (state == WL);
    walk_right = (state == WR);
    aaah = (state == FL || state == FR);
  end

endmodule