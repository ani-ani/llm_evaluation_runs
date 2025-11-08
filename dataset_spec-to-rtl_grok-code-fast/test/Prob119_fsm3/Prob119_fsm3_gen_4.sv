module TopModule (
  input clk,
  input areset,
  input in,
  output out
);

  reg [1:0] state;
  localparam A = 2'b00, B = 2'b01, C = 2'b10, D = 2'b11;
  assign out = (state == D) ? 1'b1 : 1'b0;

  always_ff @(posedge clk or posedge areset) begin
    if (areset)
      state <= A;
    else begin
      case (state)
        A: state <= in ? B : A;
        B: state <= in ? B : C;
        C: state <= in ? D : A;
        D: state <= in ? B : C;
      endcase
    end
  end
endmodule