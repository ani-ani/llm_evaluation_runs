module TopModule (
  input  clk,
  input  areset,
  input  in,
  output out
);

  localparam [1:0] A = 2'b00;
  localparam [1:0] B = 2'b01;
  localparam [1:0] C = 2'b10;
  localparam [1:0] D = 2'b11;

  reg [1:0] state_reg, next_state;

  always @(posedge clk or posedge areset) begin
    if (areset) state_reg <= A;
    else state_reg <= next_state;
  end

  always @(*) begin
    case (state_reg)
      A: next_state = in ? B : A;
      B: next_state = in ? B : C;
      C: next_state = in ? D : A;
      D: next_state = in ? B : C;
      default: next_state = A;
    endcase
  end

  assign out = (state_reg == D);
endmodule