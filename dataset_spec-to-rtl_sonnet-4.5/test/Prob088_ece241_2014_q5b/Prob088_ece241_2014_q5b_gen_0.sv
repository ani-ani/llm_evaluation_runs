module TopModule(
  input  clk,
  input  areset,
  input  x,
  output z
);

  // One-hot state encoding
  localparam STATE_A = 2'b01;
  localparam STATE_B = 2'b10;

  reg [1:0] state, next_state;

  // State register with asynchronous active-high reset
  always @(posedge clk or posedge areset) begin
    if (areset)
      state <= STATE_A;
    else
      state <= next_state;
  end

  // Next state logic and output logic (Mealy machine)
  always @(*) begin
    case (state)
      STATE_A: begin
        if (x) begin
          next_state = STATE_B;
        end else begin
          next_state = STATE_A;
        end
      end
      STATE_B: begin
        next_state = STATE_B;
      end
      default: begin
        next_state = STATE_A;
      end
    endcase
  end

  // Output logic (Mealy - depends on current state and input)
  assign z = (state == STATE_A && x == 1'b1) || (state == STATE_B && x == 1'b0);

endmodule