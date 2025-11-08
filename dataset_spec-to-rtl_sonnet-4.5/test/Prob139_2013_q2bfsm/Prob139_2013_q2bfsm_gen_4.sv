module TopModule(
  input  clk,
  input  resetn,
  input  x,
  input  y,
  output reg f,
  output reg g
);

  typedef enum reg [3:0] {
    STATE_A,
    STATE_F_HIGH,
    STATE_WAIT_X1,
    STATE_WAIT_X0,
    STATE_WAIT_X1_2,
    STATE_G_HIGH_Y1,
    STATE_G_HIGH_Y2,
    STATE_G_PERMANENT_HIGH,
    STATE_G_PERMANENT_LOW
  } state_t;

  state_t current_state, next_state;

  // State register
  always @(posedge clk) begin
    if (!resetn)
      current_state <= STATE_A;
    else
      current_state <= next_state;
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      STATE_A: begin
        next_state = STATE_F_HIGH;
      end
      STATE_F_HIGH: begin
        next_state = STATE_WAIT_X1;
      end
      STATE_WAIT_X1: begin
        if (x == 1'b1)
          next_state = STATE_WAIT_X0;
      end
      STATE_WAIT_X0: begin
        if (x == 1'b0)
          next_state = STATE_WAIT_X1_2;
        else
          next_state = STATE_WAIT_X1;
      end
      STATE_WAIT_X1_2: begin
        if (x == 1'b1)
          next_state = STATE_G_HIGH_Y1;
        else
          next_state = STATE_WAIT_X1;
      end
      STATE_G_HIGH_Y1: begin
        if (y == 1'b1)
          next_state = STATE_G_PERMANENT_HIGH;
        else
          next_state = STATE_G_HIGH_Y2;
      end
      STATE_G_HIGH_Y2: begin
        if (y == 1'b1)
          next_state = STATE_G_PERMANENT_HIGH;
        else
          next_state = STATE_G_PERMANENT_LOW;
      end
      STATE_G_PERMANENT_HIGH: begin
        next_state = STATE_G_PERMANENT_HIGH;
      end
      STATE_G_PERMANENT_LOW: begin
        next_state = STATE_G_PERMANENT_LOW;
      end
      default: begin
        next_state = STATE_A;
      end
    endcase
  end

  // Output logic
  always @(*) begin
    f = 1'b0;
    g = 1'b0;
    case (current_state)
      STATE_F_HIGH: begin
        f = 1'b1;
      end
      STATE_G_HIGH_Y1: begin
        g = 1'b1;
      end
      STATE_G_HIGH_Y2: begin
        g = 1'b1;
      end
      STATE_G_PERMANENT_HIGH: begin
        g = 1'b1;
      end
      default: begin
        f = 1'b0;
        g = 1'b0;
      end
    endcase
  end

endmodule