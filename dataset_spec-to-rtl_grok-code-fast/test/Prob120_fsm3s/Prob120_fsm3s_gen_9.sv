module TopModule(
  input clk,
  input reset,
  input in,
  output out
);
  reg [1:0] state;
  parameter A = 2'b00;
  parameter B = 2'b01;
  parameter C = 2'b10;
  parameter D = 2'b11;
  always @(posedge clk) begin
    if (reset)
      state <= A;
    else begin
      case(state)
        A: state <= in ? B : A;
        B: state <= in ? B : C;
        C: state <= in ? D : A;
        D: state <= in ? B : C;
      endcase
    end
  end
  assign out = (state == D) ? 1'b1 : 1'b0;
endmodule