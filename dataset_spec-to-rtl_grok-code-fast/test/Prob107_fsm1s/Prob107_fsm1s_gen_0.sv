module TopModule(
  input clk,
  input reset,
  input in,
  output out
);
  reg state;
  localparam B = 1'b0;
  localparam A = 1'b1;
  always @(posedge clk) begin
    if (reset)
      state <= B;
    else begin
      case (state)
        B: state <= (in == 1'b0) ? A : B;
        A: state <= (in == 1'b0) ? B : A;
      endcase
    end
  end
  assign out = (state == B) ? 1'b1 : 1'b0;
endmodule