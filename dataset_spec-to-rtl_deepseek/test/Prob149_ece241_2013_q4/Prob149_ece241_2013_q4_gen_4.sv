module TopModule(input clk, input reset, input [2:0] s, output fr2, output fr1, output fr0, output dfr);
  localparam [1:0] STATE_BELOW = 2'b00;
  localparam [1:0] STATE_LOW   = 2'b01;
  localparam [1:0] STATE_MID   = 2'b10;
  localparam [1:0] STATE_HIGH  = 2'b11;

  reg [1:0] current_state, prev_state;
  reg [1:0] next_state;

  always_comb begin
    casez(s)
      3'b000: next_state = STATE_BELOW;
      3'b001: next_state = STATE_LOW;
      3'b011: next_state = STATE_MID;
      3'b111: next_state = STATE_HIGH;
      default: next_state = current_state;
    endcase
  end

  always @(posedge clk) begin
    if (reset) begin
      current_state <= STATE_BELOW;
      prev_state <= STATE_BELOW;
    end else begin
      current_state <= next_state;
      prev_state <= current_state;
    end
  end

  assign fr0 = (current_state == STATE_BELOW) ? 1'b1 :
               (current_state == STATE_LOW)   ? 1'b1 :
               (current_state == STATE_MID)   ? 1'b1 : 1'b0;

  assign fr1 = (current_state == STATE_BELOW) ? 1'b1 :
               (current_state == STATE_LOW)   ? 1'b1 :
               (current_state == STATE_MID)   ? 1'b0 : 1'b0;

  assign fr2 = (current_state == STATE_BELOW) ? 1'b1 :
               (current_state == STATE_LOW)   ? 1'b0 :
               (current_state == STATE_MID)   ? 1'b0 : 1'b0;

  assign dfr = (current_state == STATE_BELOW) ? 1'b1 :
               (current_state == STATE_HIGH)  ? 1'b0 :
               (current_state > prev_state);
endmodule