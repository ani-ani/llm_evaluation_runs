module TopModule(input clk, reset, w, output z);
  parameter A = 3'b000;
  parameter B = 3'b001;
  parameter C = 3'b010;
  parameter D = 3'b011;
  parameter E = 3'b100;
  parameter F = 3'b101;
  
  reg [2:0] current_state, next_state;
  
  always_ff @(posedge clk) begin
    if (reset)
      current_state <= A;
    else
      current_state <= next_state;
  end
  
  always_comb begin
    case (current_state)
      A: next_state = w ? A : B;
      B: next_state = w ? D : C;
      C: next_state = w ? D : E;
      D: next_state = w ? A : F;
      E: next_state = w ? D : E;
      F: next_state = w ? D : C;
      default: next_state = A;
    endcase
  end
  
  assign z = current_state[2];
endmodule