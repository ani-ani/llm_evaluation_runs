module TopModule(input clk, reset, in, output out);
  typedef enum logic {A, B} state_t;
  state_t current_state, next_state;

  always_ff @(posedge clk) begin
    if (reset) current_state <= B;
    else current_state <= next_state;
  end

  always_comb begin
    case (current_state)
      B: next_state = in ? B : A;
      A: next_state = in ? A : B;
      default: next_state = B;
    endcase
  end

  assign out = (current_state == B) ? 1'b1 : 1'b0;
endmodule