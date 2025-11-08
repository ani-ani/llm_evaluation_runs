module TopModule (
  input clk,
  input reset,
  input [2:0] s,
  output fr2,
  output fr1,
  output fr0,
  output dfr
);
  parameter [1:0] STATE_BELOW_S0       = 2'd0;
  parameter [1:0] STATE_BETWEEN_S1_S0  = 2'd1;
  parameter [1:0] STATE_BETWEEN_S2_S1  = 2'd2;
  parameter [1:0] STATE_ABOVE_S2       = 2'd3;
  reg [1:0] current_state, prev_state, next_state;

  always_comb begin
    case (s)
      3'b111: next_state = STATE_ABOVE_S2;
      3'b011: next_state = STATE_BETWEEN_S2_S1;
      3'b001: next_state = STATE_BETWEEN_S1_S0;
      3'b000: next_state = STATE_BELOW_S0;
      default: next_state = STATE_BELOW_S0;
    endcase
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= STATE_BELOW_S0;
      prev_state    <= STATE_BELOW_S0;
    end else begin
      current_state <= next_state;
      prev_state    <= current_state;
    end
  end

  reg [2:0] fr;
  assign {fr2, fr1, fr0} = fr;

  always_comb begin
    case (current_state)
      STATE_BELOW_S0:      fr = 3'b111;
      STATE_BETWEEN_S1_S0: fr = 3'b110;
      STATE_BETWEEN_S2_S1: fr = 3'b100;
      STATE_ABOVE_S2:      fr = 3'b000;
      default:             fr = 3'b111;
    endcase
  end

  assign dfr = (current_state == STATE_BELOW_S0) ? 1'b1 : (prev_state < current_state);

endmodule