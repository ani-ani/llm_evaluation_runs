module TopModule(
  input wire clk,
  input wire reset,
  input wire w,
  output wire z
);

  localparam A = 3'b000;
  localparam B = 3'b001;
  localparam C = 3'b010;
  localparam D = 3'b011;
  localparam E = 3'b100;
  localparam F = 3'b101;

  reg [2:0] state;

  assign z = (state == E) | (state == F);

  always @(posedge clk) begin
    if (reset) begin
      state <= A;
    end else begin
      case (state)
        A: state <= w ? A : B;
        B: state <= w ? D : C;
        C: state <= w ? D : E;
        D: state <= w ? A : F;
        E: state <= w ? D : E;
        F: state <= w ? D : C;
        default: state <= A;
      endcase
    end
  end
endmodule