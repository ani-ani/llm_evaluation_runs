module TopModule (input clk, areset, x, output logic z);
  logic [1:0] state_reg, next_state;
  
  // State encoding: A = 2'b01, B = 2'b10
  localparam [1:0] A = 2'b01, B = 2'b10;
  
  always_ff @(posedge clk, posedge areset) begin
    if (areset) state_reg <= A;
    else state_reg <= next_state;
  end
  
  always_comb begin
    case (state_reg)
      A: next_state = x ? B : A;
      B: next_state = B;
      default: next_state = A;
    endcase
  end
  
  always_comb begin
    case (state_reg)
      A: z = x;
      B: z = ~x;
      default: z = 1'b0;
    endcase
  end
endmodule