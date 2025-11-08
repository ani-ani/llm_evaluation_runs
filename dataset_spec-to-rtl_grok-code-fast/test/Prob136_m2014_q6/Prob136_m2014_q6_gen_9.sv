module TopModule(
  input clk,
  input reset,
  input w,
  output z
);
  parameter A = 3'b000;
  parameter B = 3'b001;
  parameter C = 3'b010;
  parameter D = 3'b011;
  parameter E = 3'b100;
  parameter F = 3'b101;

  reg [2:0] state, next_state;

  assign z = (state == E || state == F) ? 1'b1 : 1'b0;

  always @(*) begin
    case (state)
      A: next_state = (w == 0) ? B : A;
      B: next_state = (w == 0) ? C : D;
      C: next_state = (w == 0) ? E : D;
      D: next_state = (w == 0) ? F : A;
      E: next_state = (w == 0) ? E : D;
      F: next_state = (w == 0) ? C : D;
      default: next_state = A;
    endcase
  end

  always @(posedge clk) begin
    if (reset)
      state <= A;
    else
      state <= next_state;
  end

endmodule