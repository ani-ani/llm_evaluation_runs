module TopModule(
  input clk,
  input reset,
  input w,
  output z
);
  localparam [2:0] A = 3'b000;
  localparam [2:0] B = 3'b001;
  localparam [2:0] C = 3'b010;
  localparam [2:0] D = 3'b011;
  localparam [2:0] E = 3'b100;
  localparam [2:0] F = 3'b101;

  reg [2:0] state, next_state;

  // State table
  always @* begin
    case(state)
      A: next_state = (w) ? B : A;
      B: next_state = (w) ? C : D;
      C: next_state = (w) ? E : D;
      D: next_state = (w) ? F : A;
      E: next_state = (w) ? E : D;
      F: next_state = (w) ? C : D;
      default: next_state = A;
    endcase
  end

  // State flip-flops
  always @(posedge clk) begin
    if (reset)
      state <= A;
    else
      state <= next_state;
  end

  // Output
  assign z = (state == E || state == F);
endmodule