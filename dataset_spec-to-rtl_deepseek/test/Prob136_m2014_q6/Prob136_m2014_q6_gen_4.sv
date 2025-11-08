module TopModule(input clk, input reset, input w, output z);
  localparam [2:0] A = 3'b000,
                   B = 3'b001,
                   C = 3'b010,
                   D = 3'b011,
                   E = 3'b100,
                   F = 3'b101;

  reg [2:0] state, next_state;

  always_comb begin
    case (state)
      A: next_state = w ? A : B;
      B: next_state = w ? D : C;
      C: next_state = w ? D : E;
      D: next_state = w ? A : F;
      E: next_state = w ? D : E;
      F: next_state = w ? D : C;
      default: next_state = A;
    endcase
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) state <= A;
    else state <= next_state;
  end

  assign z = state[2];
endmodule