module TopModule(
  input clk,
  input reset,
  input in,
  output disc,
  output flag,
  output err
);

  // State encoding
  typedef enum logic [3:0] {
    S0 = 4'd0,  // 0 consecutive 1s (or just saw a 0)
    S1 = 4'd1,  // 1 consecutive 1
    S2 = 4'd2,  // 2 consecutive 1s
    S3 = 4'd3,  // 3 consecutive 1s
    S4 = 4'd4,  // 4 consecutive 1s
    S5 = 4'd5,  // 5 consecutive 1s
    S6 = 4'd6,  // 6 consecutive 1s
    S_DISC = 4'd7,  // Discard state (after 01111110)
    S_FLAG = 4'd8,  // Flag state (after 01111110)
    S_ERR = 4'd9    // Error state (after 7+ 1s)
  } state_t;

  state_t current_state, next_state;

  // State register
  always_ff @(posedge clk) begin
    if (reset)
      current_state <= S0;
    else
      current_state <= next_state;
  end

  // Next state logic
  always_comb begin
    next_state = current_state;
    
    case (current_state)
      S0: begin
        if (in)
          next_state = S1;
        else
          next_state = S0;
      end
      
      S1: begin
        if (in)
          next_state = S2;
        else
          next_state = S0;
      end
      
      S2: begin
        if (in)
          next_state = S3;
        else
          next_state = S0;
      end
      
      S3: begin
        if (in)
          next_state = S4;
        else
          next_state = S0;
      end
      
      S4: begin
        if (in)
          next_state = S5;
        else
          next_state = S0;
      end
      
      S5: begin
        if (in)
          next_state = S6;
        else
          next_state = S_DISC;  // 01111110 - discard the 0
      end
      
      S6: begin
        if (in)
          next_state = S_ERR;  // 7 or more 1s - error
        else
          next_state = S_FLAG;  // 01111110 - flag
      end
      
      S_DISC: begin
        if (in)
          next_state = S1;
        else
          next_state = S0;
      end
      
      S_FLAG: begin
        if (in)
          next_state = S1;
        else
          next_state = S0;
      end
      
      S_ERR: begin
        if (in)
          next_state = S_ERR;  // Stay in error while 1s continue
        else
          next_state = S0;
      end
      
      default: next_state = S0;
    endcase
  end

  // Output logic (Moore machine - outputs depend only on current state)
  assign disc = (current_state == S_DISC);
  assign flag = (current_state == S_FLAG);
  assign err = (current_state == S_ERR);

endmodule
