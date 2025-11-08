module TopModule(input clk, areset, bump_left, bump_right, ground, output walk_left, walk_right, aaah);
  enum {WL, WR, FL, FR} state;
  
  always @(posedge clk, posedge areset) begin
    if (areset) begin
      state <= WL;
    end else begin
      case (state)
        WL: state <= (!ground) ? FL : (bump_left ? WR : WL);
        WR: state <= (!ground) ? FR : (bump_right ? WL : WR);
        FL: state <= (ground) ? WL : FL;
        FR: state <= (ground) ? WR : FR;
        default: state <= WL;
      endcase
    end
  end
  
  assign walk_left = (state == WL);
  assign walk_right = (state == WR);
  assign aaah = (state == FL || state == FR);
endmodule