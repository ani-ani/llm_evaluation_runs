module TopModule(
  input clk,
  input areset,
  input x,
  output logic z
);
  localparam A = 2'b01;
  localparam B = 2'b10;
  
  logic [1:0] state_reg, next_state;
  
  always_ff @(posedge clk, posedge areset) begin
    if (areset) begin
      state_reg <= A;
    end else begin
      state_reg <= next_state;
    end
  end
  
  always_comb begin
    case (state_reg)
      A: next_state = x ? B : A;
      B: next_state = B;
      default: next_state = A;
    endcase
  end
  
  assign z = (state_reg == A) ? x : ~x;
  
endmodule