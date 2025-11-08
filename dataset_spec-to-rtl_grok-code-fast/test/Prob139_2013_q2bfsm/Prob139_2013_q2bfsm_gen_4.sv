module TopModule(
  input clk,
  input resetn,
  input x,
  input y,
  output reg f,
  output reg g
);
  parameter A = 0;
  parameter S_SET_F = 1;
  parameter S_X_IDLE = 2;
  parameter S_X1 = 3;
  parameter S_X10 = 4;
  parameter S_SET_G = 5;
  parameter S_CHECK1 = 6;
  parameter S_CHECK2 = 7;
  parameter S_PERM0 = 8;
  parameter S_PERM1 = 9;
  reg [3:0] state;
  always @(posedge clk) begin
    if (!resetn) begin
      state <= A;
    end else begin
      case (state)
        A: state <= S_SET_F;
        S_SET_F: state <= S_X_IDLE;
        S_X_IDLE: if (x) state <= S_X1; else state <= S_X_IDLE;
        S_X1: if (x == 0) state <= S_X10; else state <= S_X_IDLE;
        S_X10: if (x) state <= S_SET_G; else state <= S_X1;
        S_SET_G: state <= S_CHECK1;
        S_CHECK1: if (y) state <= S_PERM1; else state <= S_CHECK2;
        S_CHECK2: if (y) state <= S_PERM1; else state <= S_PERM0;
        S_PERM0: state <= S_PERM0;
        S_PERM1: state <= S_PERM1;
        default: state <= A;
      endcase
    end
  end
  assign f = (state == S_SET_F);
  assign g = ((state == S_SET_G) || (state == S_CHECK1) || (state == S_CHECK2) || (state == S_PERM1));
endmodule