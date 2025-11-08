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
    STATE_F,
    STATE_X1,
    STATE_X10,
    STATE_X101,
    STATE_G1,
    STATE_G2,
    STATE_G_HIGH,
    STATE_G_LOW
  } state_t;

  state_t current_state, next_state;

  // State register
  always @(posedge clk) begin
    if (!resetn) begin
      current_state <= STATE_A;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      STATE_A: begin
        next_state = STATE_F;
      end
      STATE_F: begin
        if (x == 1)
          next_state = STATE_X1;
        else
          next_state = STATE_X1;
      end
      STATE_X1: begin
        if (x == 1)
          next_state = STATE_X1;
        else
          next_state = STATE_X10;
      end
      STATE_X10: begin
        if (x == 1)
          next_state = STATE_X101;
        else
          next_state = STATE_X1;
      end
      STATE_X101: begin
        next_state = STATE_G1;
      end
      STATE_G1: begin
        if (y == 1)
          next_state = STATE_G_HIGH;
        else
          next_state = STATE_G2;
      end
      STATE_G2: begin
        if (y == 1)
          next_state = STATE_G_HIGH;
        else
          next_state = STATE_G_LOW;
      end
      STATE_G_HIGH: begin
        next_state = STATE_G_HIGH;
      end
      STATE_G_LOW: begin
        next_state = STATE_G_LOW;
      end
      default: begin
        next_state = STATE_A;
      end
    endcase
  end

  // Output logic
  always @(*) begin
    f = 0;
    g = 0;
    case (current_state)
      STATE_F: begin
        f = 1;
      end
      STATE_G1: begin
        g = 1;
      end
      STATE_G2: begin
        g = 1;
      end
      STATE_G_HIGH: begin
        g = 1;
      end
      default: begin
        f = 0;
        g = 0;
      end
    endcase
  end

endmodule