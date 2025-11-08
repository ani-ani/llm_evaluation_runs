module TopModule(
  input reg clk,
  input reg areset,
  input reg x,
  output reg z
);

  // One-hot encoding parameters
  parameter STATE_A = 2'b01;
  parameter STATE_B = 2'b10;

  reg [1:0] state;

  // State transition logic
  always @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= STATE_A;
    end else begin
      case (state)
        STATE_A: if (x) state <= STATE_B; else state <= STATE_A;
        STATE_B: state <= STATE_B;
        default: state <= STATE_A;
      endcase
    end
  end

  // Output logic (Mealy FSM)
  always @(*) begin
    case (state)
      STATE_A: z = x ? 1'b1 : 1'b0;
      STATE_B: z = x ? 1'b0 : 1'b1;
      default: z = 1'b0;
    endcase
  end
\endmodule