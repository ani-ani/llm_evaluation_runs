module TopModule(input clk, input reset, input in, output out);
  typedef enum logic {B, A} state_t;
  state_t state_reg, next_state;
  
  assign out = state_reg;
  
  always_comb begin
    case (state_reg)
      B: next_state = in ? B : A;
      A: next_state = in ? A : B;
    endcase
  end
  
  always_ff @(posedge clk) begin
    if (reset)
      state_reg <= B;
    else
      state_reg <= next_state;
  end
endmodule