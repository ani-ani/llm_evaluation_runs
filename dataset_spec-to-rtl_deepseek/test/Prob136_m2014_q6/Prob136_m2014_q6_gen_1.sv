module TopModule(input clk, reset, w, output z);
  parameter [2:0] A = 3'b000,
                  B = 3'b001,
                  C = 3'b010,
                  D = 3'b011,
                  E = 3'b100,
                  F = 3'b101;

  reg [2:0] current_state;

  always @(posedge clk or posedge reset) begin
    if (reset)
      current_state <= A;
    else
      case(current_state)
        A: current_state <= w ? A : B;
        B: current_state <= w ? D : C;
        C: current_state <= w ? D : E;
        D: current_state <= w ? A : F;
        E: current_state <= w ? D : E;
        F: current_state <= w ? D : C;
        default: current_state <= A;
      endcase
  end

  assign z = (current_state == E || current_state == F) ? 1'b1 : 1'b0;
endmodule