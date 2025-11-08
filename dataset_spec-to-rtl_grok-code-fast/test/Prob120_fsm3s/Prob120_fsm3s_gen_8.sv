module TopModule(input clk, input reset, input in, output reg out);
  parameter A = 2'b00;
  parameter B = 2'b01;
  parameter C = 2'b10;
  parameter D = 2'b11;
  
  reg [1:0] current_state, next_state;
  
  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= A;
    end else begin
      current_state <= next_state;
    end
  end
  
  always_comb begin
    // Output logic (Moore)
    out = (current_state == D);
    // Next state logic
    case (current_state)
      A: next_state = in ? B : A;
      B: next_state = in ? B : C;
      C: next_state = in ? D : A;
      D: next_state = in ? B : C;
      default: next_state = A;
    endcase
  end
endmodule