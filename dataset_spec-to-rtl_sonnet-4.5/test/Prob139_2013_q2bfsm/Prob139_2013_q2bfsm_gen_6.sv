module TopModule(
  input  clk,
  input  resetn,
  input  x,
  input  y,
  output reg f,
  output reg g
);

  typedef enum reg [3:0] {
    A,
    F_HIGH,
    WAIT_X1,
    WAIT_X0,
    WAIT_X1_AGAIN,
    G_HIGH_Y_WAIT1,
    G_HIGH_Y_WAIT2,
    G_HIGH_PERM,
    G_LOW_PERM
  } state_t;

  state_t current_state, next_state;

  // State register
  always_ff @(posedge clk) begin
    if (!resetn)
      current_state <= A;
    else
      current_state <= next_state;
  end

  // Next state logic
  always_comb begin
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
          next_state = G_HIGH_Y_WAIT1;
        else
          next_state = WAIT_X1;
      end
      G_HIGH_Y_WAIT1: begin
        if (y == 1)
          next_state = G_HIGH_PERM;
        else
          next_state = G_HIGH_Y_WAIT2;
      end
      G_HIGH_Y_WAIT2: begin
        if (y == 1)
          next_state = G_HIGH_PERM;
        else
          next_state = G_LOW_PERM;
      end
      G_HIGH_PERM: begin
        next_state = G_HIGH_PERM;
      end
      G_LOW_PERM: begin
        next_state = G_LOW_PERM;
      end
      default: begin
        next_state = A;
      end
    endcase
  end

  // Output logic
  always_ff @(posedge clk) begin
    if (!resetn) begin
      f <= 1'b0;
      g <= 1'b0;
    end else begin
      f <= (next_state == F_HIGH);
      g <= (next_state == G_HIGH_Y_WAIT1 || next_state == G_HIGH_Y_WAIT2 || next_state == G_HIGH_PERM);
    end
  end

endmodule