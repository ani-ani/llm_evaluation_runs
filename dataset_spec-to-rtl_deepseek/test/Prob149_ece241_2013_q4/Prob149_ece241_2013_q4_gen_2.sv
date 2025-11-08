module TopModule (
  input clk,
  input reset,
  input [2:0] s,
  output fr2,
  output fr1,
  output fr0,
  output dfr
);

  typedef enum logic [1:0] {
    BELOW,
    LOW_MID,
    HIGH_MID,
    ABOVE
  } state_t;

  state_t current_state, previous_state, next_state;

  always_comb begin
    unique case (s)
      3'b000: next_state = BELOW;
      3'b001: next_state = LOW_MID;
      3'b011: next_state = HIGH_MID;
      3'b111: next_state = ABOVE;
      default: next_state = current_state;
    endcase
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= BELOW;
      previous_state <= BELOW;
    end else begin
      previous_state <= current_state;
      current_state <= next_state;
    end
  end

  assign fr0 = (current_state inside {BELOW, LOW_MID, HIGH_MID});
  assign fr1 = (current_state inside {BELOW, LOW_MID});
  assign fr2 = (current_state == BELOW);
  assign dfr = (current_state == BELOW) ? 1'b1 :
               (current_state > previous_state) ? 1'b1 :
               1'b0;
endmodule