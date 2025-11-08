module TopModule(
  input clk,
  input resetn,
  input x,
  input y,
  output reg f,
  output reg g
);

  // State encoding
  typedef enum reg [3:0] {
    A,        // Initial/Reset state
    SET_F,    // Set f=1 for one cycle
    WAIT_X1,  // Waiting for x=1 (first)
    WAIT_X0,  // Waiting for x=0 (after first x=1)
    WAIT_X1_2,// Waiting for x=1 (second, after x=0)
    SET_G,    // Set g=1 and check y
    CHECK_Y2, // Second cycle to check y
    G_HIGH,   // g permanently high
    G_LOW     // g permanently low
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
        next_state = SET_F;
      end
      
      SET_F: begin
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
          next_state = WAIT_X1_2;
        else
          next_state = WAIT_X1;
      end
      
      WAIT_X1_2: begin
        if (x == 1)
          next_state = SET_G;
        else
          next_state = WAIT_X1;
      end
      
      SET_G: begin
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
      // f output
      if (current_state == SET_F)
        f <= 1'b1;
      else
        f <= 1'b0;
      
      // g output
      if (current_state == SET_G || current_state == CHECK_Y2 || current_state == G_HIGH)
        g <= 1'b1;
      else
        g <= 1'b0;
    end
  end

endmodule