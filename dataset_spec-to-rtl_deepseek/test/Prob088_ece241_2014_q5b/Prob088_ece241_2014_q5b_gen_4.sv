module TopModule(input clk, input areset, input x, output reg z);
  localparam [1:0] state_A = 2'b01;
  localparam [1:0] state_B = 2'b10;
  
  reg [1:0] state_reg, next_state;
  
  always @(posedge clk or posedge areset) begin
    if (areset) state_reg <= state_A;
    else state_reg <= next_state;
  end
  
  always @(*) begin
    case (state_reg)
      state_A: next_state = x ? state_B : state_A;
      state_B: next_state = state_B;
      default: next_state = state_A;
    endcase
  end
  
  always @(*) begin
    case (state_reg)
      state_A: z = x ? 1'b1 : 1'b0;
      state_B: z = x ? 1'b0 : 1'b1;
      default: z = 1'b0;
    endcase
  end
endmodule