module TopModule(
  input clk,
  input reset,
  input in,
  output out
);

  typedef enum logic [1:0] {S_A = 2'b00, S_B = 2'b01, S_C = 2'b10, S_D = 2'b11} state_t;
  state_t current, next;

  always_comb begin
    case(current)
      S_A: next = in ? S_B : S_A;
      S_B: next = in ? S_B : S_C;
      S_C: next = in ? S_D : S_A;
      S_D: next = in ? S_B : S_C;
    endcase
  end

  always_ff @(posedge clk) begin
    if(reset)
      current <= S_A;
    else
      current <= next;
  end

  assign out = (current == S_D) ? 1'b1 : 1'b0;

endmodule