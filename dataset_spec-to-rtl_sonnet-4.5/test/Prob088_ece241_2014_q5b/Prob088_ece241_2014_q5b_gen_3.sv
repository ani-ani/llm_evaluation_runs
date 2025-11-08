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

  // Sequential logic with asynchronous active-high reset
  always @(posedge clk or posedge areset) begin
    if (areset)
      state <= STATE_A;
    else
      state <= next_state;
  end

  // Next state logic
  always @(*) begin
    case (state)
      STATE_A: begin
        if (x)
          next_state = STATE_B;
        else
          next_state = STATE_A;
      end
      STATE_B: begin
        next_state = STATE_B;
      end
      default: begin
        next_state = STATE_A;
      end
    endcase
  end

  // Output logic (Mealy machine - depends on state and input)
  reg z_out;
  always @(*) begin
    case (state)
      STATE_A: begin
        if (x)
          z_out = 1'b1;
        else
          z_out = 1'b0;
      end
      STATE_B: begin
        if (x)
          z_out = 1'b0;
        else
          z_out = 1'b1;
      end
      default: begin
        z_out = 1'b0;
      end
    endcase
  end

  assign z = z_out;

endmodule