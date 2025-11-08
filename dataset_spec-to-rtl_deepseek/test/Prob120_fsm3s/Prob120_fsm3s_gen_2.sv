module TopModule(input clk, input reset, input in, output logic out);
  typedef enum {A, B, C, D} state_t;
  state_t current_state;

  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= A;
    end else begin
      case (current_state)
        A: current_state <= in ? B : A;
        B: current_state <= in ? B : C;
        C: current_state <= in ? D : A;
        D: current_state <= in ? B : C;
      endcase
    end
  end

  assign out = (current_state == D) ? 1'b1 : 1'b0;
endmodule