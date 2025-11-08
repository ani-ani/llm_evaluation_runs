module TopModule (
  input  clk,
  input  areset,
  input  in,
  output out
);
  typedef enum logic [1:0] {S_A, S_B, S_C, S_D} state_t;
  state_t current_state, next_state;

  always_comb begin
    case (current_state)
      S_A: next_state = in ? S_B : S_A;
      S_B: next_state = in ? S_B : S_C;
      S_C: next_state = in ? S_D : S_A;
      S_D: next_state = in ? S_B : S_C;
      default: next_state = S_A;
    endcase
  end

  always_ff @(posedge clk, posedge areset) begin
    if (areset) current_state <= S_A;
    else current_state <= next_state;
  end

  assign out = (current_state == S_D) ? 1'b1 : 1'b0;
endmodule