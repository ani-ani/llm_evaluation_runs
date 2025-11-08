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
    S0 = 4'd0,  // 0 consecutive 1s (or last bit was 0)
    S1 = 4'd1,  // 1 consecutive 1s
    S2 = 4'd2,  // 2 consecutive 1s
    S3 = 4'd3,  // 3 consecutive 1s
    S4 = 4'd4,  // 4 consecutive 1s
    S5 = 4'd5,  // 5 consecutive 1s
    S6 = 4'd6,  // 6 consecutive 1s
    S7 = 4'd7,  // 7 or more consecutive 1s (error)
    DISC = 4'd8,  // Discard state
    FLAG = 4'd9,  // Flag state
    ERR = 4'd10   // Error state
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
          next_state = DISC;  // 0111110 - discard
      end
      
      S6: begin
        if (in)
          next_state = ERR;   // 01111111... - error
        else
          next_state = FLAG;  // 01111110 - flag
      end
      
      DISC: begin
        if (in)
          next_state = S1;
        else
          next_state = S0;
      end
      
      FLAG: begin
        if (in)
          next_state = S1;
        else
          next_state = S0;
      end
      
      ERR: begin
        if (in)
          next_state = ERR;  // Stay in error while 1s continue
        else
          next_state = S0;
      end
      
      default: begin
        next_state = S0;
      end
    endcase
  end

  // Output logic (Moore machine - outputs depend only on current state)
  assign disc = (current_state == DISC);
  assign flag = (current_state == FLAG);
  assign err = (current_state == ERR);

endmodule
