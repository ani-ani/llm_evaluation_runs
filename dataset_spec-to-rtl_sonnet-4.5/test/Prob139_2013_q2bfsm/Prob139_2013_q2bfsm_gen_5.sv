module TopModule(
  input clk,
  input resetn,
  input x,
  input y,
  output reg f,
  output reg g
);

  typedef enum reg [3:0] {
    A,
    F_HIGH,
    WAIT_X1,
    WAIT_X0,
    WAIT_X1_AGAIN,
    G_HIGH_WAIT_Y1,
    G_HIGH_WAIT_Y2,
    G_HIGH_PERMANENT,
    G_LOW_PERMANENT
  } state_t;

  state_t current_state, next_state;

  // State register
  always @(posedge clk) begin
    if (!resetn)
      current_state <= A;
    else
      current_state <= next_state;
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      A: begin
        if (resetn)
          next_state = F_HIGH;
      end
      F_HIGH: begin
        next_state = WAIT_X1;
      end
      WAIT_X1: begin
        if (x == 1)
          next_state = WAIT_X0;
      end
      WAIT_X0: begin
        if (x == 0)
          next_state = WAIT_X1_AGAIN;
        else
          next_state = WAIT_X1;
      end
      WAIT_X1_AGAIN: begin
        if (x == 1)
          next_state = G_HIGH_WAIT_Y1;
        else if (x == 0)
          next_state = WAIT_X0;
        else
          next_state = WAIT_X1;
      end
      G_HIGH_WAIT_Y1: begin
        if (y == 1)
          next_state = G_HIGH_PERMANENT;
        else
          next_state = G_HIGH_WAIT_Y2;
      end
      G_HIGH_WAIT_Y2: begin
        if (y == 1)
          next_state = G_HIGH_PERMANENT;
        else
          next_state = G_LOW_PERMANENT;
      end
      G_HIGH_PERMANENT: begin
        next_state = G_HIGH_PERMANENT;
      end
      G_LOW_PERMANENT: begin
        next_state = G_LOW_PERMANENT;
      end
      default: next_state = A;
    endcase
  end

  // Output logic
  always @(*) begin
    f = 0;
    g = 0;
    case (current_state)
      F_HIGH: begin
        f = 1;
      end
      G_HIGH_WAIT_Y1: begin
        g = 1;
      end
      G_HIGH_WAIT_Y2: begin
        g = 1;
      end
      G_HIGH_PERMANENT: begin
        g = 1;
      end
      default: begin
        f = 0;
        g = 0;
      end
    endcase
  end

endmodule