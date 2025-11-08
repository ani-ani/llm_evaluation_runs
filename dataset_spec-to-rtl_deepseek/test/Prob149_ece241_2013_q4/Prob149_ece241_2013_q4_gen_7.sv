module TopModule(
  input clk,
  input reset,
  input [2:0] s,
  output fr2,
  output fr1,
  output fr0,
  output dfr
);
  reg [1:0] current_state, prev_state;
  localparam BELOW   = 2'b00;
  localparam MID_LOW = 2'b01;
  localparam MID_HIGH = 2'b10;
  localparam ABOVE   = 2'b11;

  wire [1:0] next_state;
  assign next_state = s[2] ? ABOVE   :
                     s[1] ? MID_HIGH :
                     s[0] ? MID_LOW  : BELOW;

  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= BELOW;
      prev_state    <= BELOW;
    end else begin
      prev_state    <= current_state;
      current_state <= next_state;
    end
  end

  assign fr0 = reset ? 1'b1 : (current_state != ABOVE);
  assign fr1 = reset ? 1'b1 : (current_state == BELOW || current_state == MID_LOW);
  assign fr2 = reset ? 1'b1 : (current_state == BELOW);
  assign dfr = reset ? 1'b1 : (current_state > prev_state);

endmodule