module TopModule(
  input  clk,
  input  resetn,
  input  x,
  input  y,
  output reg f,
  output reg g
);

  // State encoding
  typedef enum reg [3:0] {
    A        = 4'd0,  // Reset state
    B        = 4'd1,  // Set f=1 for one cycle
    WAIT_X1  = 4'd2,  // Waiting for first x=1
    WAIT_X0  = 4'd3,  // Waiting for x=0 after x=1
    WAIT_X1_2= 4'd4,  // Waiting for second x=1
    CHECK_Y1 = 4'd5,  // First cycle checking y (g=1)
    CHECK_Y2 = 4'd6,  // Second cycle checking y (g=1)
    G_HIGH   = 4'd7,  // g=1 permanently
    G_LOW    = 4'd8   // g=0 permanently
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
          next_state = B;
      end
      
      B: begin
        next_state = WAIT_X1;
      end
      
      WAIT_X1: begin
        if (x)
          next_state = WAIT_X0;
      end
      
      WAIT_X0: begin
        if (x)
          next_state = WAIT_X1;
        else
          next_state = WAIT_X1_2;
      end
      
      WAIT_X1_2: begin
        if (x)
          next_state = CHECK_Y1;
        else
          next_state = WAIT_X1;
      end
      
      CHECK_Y1: begin
        if (y)
          next_state = G_HIGH;
        else
          next_state = CHECK_Y2;
      end
      
      CHECK_Y2: begin
        if (y)
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
  always @(*) begin
    f = 1'b0;
    g = 1'b0;
    
    case (current_state)
      B: begin
        f = 1'b1;
      end
      
      CHECK_Y1: begin
        g = 1'b1;
      end
      
      CHECK_Y2: begin
        g = 1'b1;
      end
      
      G_HIGH: begin
        g = 1'b1;
      end
      
      default: begin
        f = 1'b0;
        g = 1'b0;
      end
    endcase
  end

endmodule