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
    F_SET,
    WAIT_X1,
    WAIT_X0,
    WAIT_X1_AGAIN,
    G_SET_Y1,
    G_SET_Y2,
    G_PERMANENT_HIGH,
    G_PERMANENT_LOW
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
        next_state = F_SET;
      end
      F_SET: begin
        next_state = WAIT_X1;
      end
      WAIT_X1: begin
        if (x == 1)
          next_state = WAIT_X0;
        else
          next_state = WAIT_X1;
      end
      WAIT_X0: begin
        if (x == 0)
          next_state = WAIT_X1_AGAIN;
        else
          next_state = WAIT_X1;
      end
      WAIT_X1_AGAIN: begin
        if (x == 1)
          next_state = G_SET_Y1;
        else
          next_state = WAIT_X1;
      end
      G_SET_Y1: begin
        if (y == 1)
          next_state = G_PERMANENT_HIGH;
        else
          next_state = G_SET_Y2;
      end
      G_SET_Y2: begin
        if (y == 1)
          next_state = G_PERMANENT_HIGH;
        else
          next_state = G_PERMANENT_LOW;
      end
      G_PERMANENT_HIGH: begin
        next_state = G_PERMANENT_HIGH;
      end
      G_PERMANENT_LOW: begin
        next_state = G_PERMANENT_LOW;
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
      case (next_state)
        F_SET: begin
          f <= 1'b1;
          g <= 1'b0;
        end
        G_SET_Y1, G_SET_Y2, G_PERMANENT_HIGH: begin
          f <= 1'b0;
          g <= 1'b1;
        end
        G_PERMANENT_LOW: begin
          f <= 1'b0;
          g <= 1'b0;
        end
        default: begin
          f <= 1'b0;
          g <= 1'b0;
        end
      endcase
    end
  end

endmodule