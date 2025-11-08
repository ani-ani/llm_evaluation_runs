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
    SET_F,
    WAIT_X1,
    WAIT_X0,
    WAIT_X1_AGAIN,
    SET_G,
    CHECK_Y1,
    CHECK_Y2,
    G_HIGH,
    G_LOW
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
          next_state = SET_F;
      end
      SET_F: begin
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
          next_state = SET_G;
        else
          next_state = WAIT_X1;
      end
      SET_G: begin
        next_state = CHECK_Y1;
      end
      CHECK_Y1: begin
        if (y == 1)
          next_state = G_HIGH;
        else
          next_state = CHECK_Y2;
      end
      CHECK_Y2: begin
        if (y == 1)
          next_state = G_HIGH;
        else
          next_state = G_LOW;
      end
      G_HIGH: begin
        next_state = G_HIGH;
      end
      G_LOW: begin
        next_state = G_LOW;
      end
      default: next_state = A;
    endcase
  end

  // Output logic
  always_ff @(posedge clk) begin
    if (!resetn) begin
      f <= 1'b0;
      g <= 1'b0;
    end else begin
      f <= 1'b0;
      g <= 1'b0;
      case (current_state)
        SET_F: begin
          f <= 1'b1;
        end
        SET_G: begin
          g <= 1'b1;
        end
        CHECK_Y1: begin
          g <= 1'b1;
        end
        CHECK_Y2: begin
          g <= 1'b1;
        end
        G_HIGH: begin
          g <= 1'b1;
        end
        G_LOW: begin
          g <= 1'b0;
        end
      endcase
    end
  end

endmodule