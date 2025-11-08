module TopModule (
  input clk,
  input areset,
  input bump_left,
  input bump_right,
  input ground,
  output walk_left,
  output walk_right,
  output aaah
);
  localparam [1:0] WL = 2'b00,
                   WR = 2'b01,
                   FL = 2'b10,
                   FR = 2'b11;
  reg [1:0] state, next_state;

  always_ff @(posedge clk, posedge areset) begin
    if (areset) state <= WL;
    else state <= next_state;
  end

  always_comb begin
    case (state)
      WL: next_state = (!ground) ? FL : (bump_left ? WR : WL);
      WR: next_state = (!ground) ? FR : (bump_right ? WL : WR);
      FL: next_state = ground ? WL : FL;
      FR: next_state = ground ? WR : FR;
      default: next_state = WL;
    endcase
  end

  assign walk_left = (state == WL);
  assign walk_right = (state == WR);
  assign aaah = (state == FL || state == FR);
endmodule