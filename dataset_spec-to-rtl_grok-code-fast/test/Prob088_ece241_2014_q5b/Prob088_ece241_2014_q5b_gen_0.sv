module TopModule(
  input clk,
  input areset,
  input x,
  output logic z
);

  typedef enum logic [1:0] {
    A = 2'b01,
    B = 2'b10
  } state_t;

  state_t state;

  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= A;
    end else begin
      case (state)
        A: state <= x ? B : A;
        B: state <= B;
        default: state <= A;
      endcase
    end
  end

  assign z = (state == A && x) || (state == B && ~x);

endmodule