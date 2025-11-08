module TopModule(input clk, input reset, input in, output out);
  typedef enum logic [1:0] {A, B, C, D} state_t;
  state_t current_state;

  always_ff @(posedge clk) begin
    if (reset)
      current_state <= A;
    else
      case (current_state)
        A: current_state <= in ? B : A;
        B: current_state <= in ? B : C;
        C: current_state <= in ? D : A;
        D: current_state <= in ? B : C;
      endcase
  end

  assign out = (current_state == D);
endmodule