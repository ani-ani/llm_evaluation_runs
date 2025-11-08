module TopModule(input clk, input resetn, input x, input y, output reg f, output reg g);

  parameter [3:0] StateA = 4'b0000;
  parameter [3:0] StateF = 4'b0001;
  parameter [3:0] StateX0 = 4'b0010;
  parameter [3:0] StateX1 = 4'b0011;
  parameter [3:0] StateX2 = 4'b0100;
  parameter [3:0] StateG1 = 4'b0101;
  parameter [3:0] StateG2 = 4'b0110;
  parameter [3:0] StateGP = 4'b0111;
  parameter [3:0] StateGO = 4'b1000;

  reg [3:0] state, next_state;

  always @(posedge clk) begin
    if (!resetn) state <= StateA;
    else state <= next_state;
  end

  always @* begin
    case (state)
      StateA: next_state = resetn ? StateF : StateA;
      StateF: next_state = StateX0;
      StateX0: next_state = x ? StateX1 : StateX0;
      StateX1: next_state = ~x ? StateX2 : StateX1;
      StateX2: next_state = x ? StateG1 : StateX0;
      StateG1: next_state = y ? StateGP : StateG2;
      StateG2: next_state = y ? StateGP : StateGO;
      StateGP: next_state = StateGP;
      StateGO: next_state = StateGO;
      default: next_state = StateA;
    endcase
  end

  always @* begin
    case (state)
      StateF: {f, g} = 2'b10;
      StateG1, StateG2, StateGP: {f, g} = 2'b01;
      default: {f, g} = 2'b00;
    endcase
  end

endmodule