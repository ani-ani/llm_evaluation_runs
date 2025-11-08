module TopModule(input clk, input reset, input [2:0] s, output logic fr2, fr1, fr0, dfr);
  typedef enum logic [1:0] {STATE_LOW, STATE_MID_LOW, STATE_MID_HIGH, STATE_HIGH} state_t;
  state_t current_state, prev_state;

  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= STATE_LOW;
      prev_state <= STATE_LOW;
    end else begin
      prev_state <= current_state;
      casez(s)
        3'b111: current_state <= STATE_HIGH;
        3'b011: current_state <= STATE_MID_HIGH;
        3'b001: current_state <= STATE_MID_LOW;
        3'b000: current_state <= STATE_LOW;
        default: current_state <= STATE_LOW;
      endcase
    end
  end

  always_comb begin
    if (reset) begin
      fr2 = 1'b1;
      fr1 = 1'b1;
      fr0 = 1'b1;
      dfr = 1'b1;
    end else begin
      case(current_state)
        STATE_HIGH: {fr2, fr1, fr0} = 3'b000;
        STATE_MID_HIGH: {fr2, fr1, fr0} = 3'b001;
        STATE_MID_LOW: {fr2, fr1, fr0} = 3'b011;
        STATE_LOW: {fr2, fr1, fr0} = 3'b111;
        default: {fr2, fr1, fr0} = 3'b111;
      endcase
      dfr = (prev_state < current_state) ? 1'b1 : 1'b0;
    end
  end
endmodule