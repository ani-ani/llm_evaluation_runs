module TopModule(input clk, input reset, input in, output out);
  typedef enum logic {B, A} state_t;
  state_t state;
  always_ff @(posedge clk) begin
    if (reset) state <= B;
    else begin
      case (state)
        B: state <= in ? B : A;
        A: state <= in ? A : B;
      endcase
    end
  end
  assign out = (state == B) ? 1'b1 : 1'b0;
endmodule