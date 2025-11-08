module TopModule(input clk, input reset, input data, output start_shifting);
  typedef enum logic [2:0] { S0, S1, S2, S3, S4 } state_t;
  state_t current_state, next_state;

  always_ff @(posedge clk) begin
    if (reset) current_state <= S0;
    else current_state <= next_state;
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      S0: next_state = data ? S1 : S0;
      S1: next_state = data ? S2 : S0;
      S2: next_state = data ? S2 : S3;
      S3: if (data) next_state = S4; else next_state = S0;
      S4: next_state = S4;
      default: next_state = S0;
    endcase
  end

  assign start_shifting = (current_state == S4);
endmodule