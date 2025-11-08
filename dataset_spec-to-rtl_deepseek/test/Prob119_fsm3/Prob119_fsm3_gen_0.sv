module TopModule(input clk, input areset, input in, output out);
  localparam [1:0] A = 2'b00;
  localparam [1:0] B = 2'b01;
  localparam [1:0] C = 2'b10;
  localparam [1:0] D = 2'b11;
  
  reg [1:0] current_state;
  reg [1:0] next_state;
  
  always_ff @(posedge clk, posedge areset) begin
    if (areset) current_state <= A;
    else current_state <= next_state;
  end
  
  always_comb begin
    case (current_state)
      A: next_state = in ? B : A;
      B: next_state = in ? B : C;
      C: next_state = in ? D : A;
      D: next_state = in ? B : C;
      default: next_state = A;
    endcase
  end
  
  assign out = (current_state == D) ? 1'b1 : 1'b0;
endmodule