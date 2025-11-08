module TopModule(
  input clk,
  input reset,
  input in,
  output out
);
  localparam A = 2'd0;
  localparam B = 2'd1;
  localparam C = 2'd2;
  localparam D = 2'd3;
  
  reg [1:0] state;
  reg [1:0] next_state;
  
  always @(posedge clk) begin
    if (reset) state <= A;
    else state <= next_state;
  end
  
  always @(*) begin
    case (state)
      A: next_state = (in ? B : A);
      B: next_state = (in ? B : C);
      C: next_state = (in ? D : A);
      D: next_state = (in ? B : C);
    endcase
  end
  
  assign out = (state == D) ? 1 : 0;
endmodule