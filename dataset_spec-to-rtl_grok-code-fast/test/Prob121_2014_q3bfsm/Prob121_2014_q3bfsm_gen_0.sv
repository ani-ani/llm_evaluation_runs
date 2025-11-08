module TopModule(
  input clk,
  input reset,
  input x,
  output z
);

  typedef enum logic [2:0] {
    s000 = 3'b000,
    s001 = 3'b001,
    s010 = 3'b010,
    s011 = 3'b011,
    s100 = 3'b100
  } state_t;

  state_t current_state, next_state;

  // State register
  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= s000;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always_comb begin
    case (current_state)
      s000: next_state = (x) ? s001 : s000;
      s001: next_state = (x) ? s100 : s001;
      s010: next_state = (x) ? s001 : s010;
      s011: next_state = (x) ? s010 : s001;
      s100: next_state = (x) ? s100 : s011;
    endcase
  end

  // Output logic
  assign z = (current_state == s011) || (current_state == s100);

endmodule