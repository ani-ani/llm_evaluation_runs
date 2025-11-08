module TopModule(input clk, input areset, input bump_left, input bump_right, input ground, output walk_left, output walk_right, output aaah);
  typedef enum {WL, WR, FL, FR} state_t;
  state_t state;

  always_ff @(posedge clk, posedge areset) begin
    if (areset) state <= WL;
    else begin
      case (state)
        WL: state <= (~ground) ? FL : (bump_left ? WR : WL);
        WR: state <= (~ground) ? FR : (bump_right ? WL : WR);
        FL: state <= (ground) ? WL : FL;
        FR: state <= (ground) ? WR : FR;
      endcase
    end
  end

  assign walk_left = (state == WL);
  assign walk_right = (state == WR);
  assign aaah = (state == FL || state == FR);
endmodule