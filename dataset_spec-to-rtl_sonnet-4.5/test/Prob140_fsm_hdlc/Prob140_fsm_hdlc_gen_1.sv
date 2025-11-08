module TopModule(
  input  clk,
  input  reset,
  input  in,
  output disc,
  output flag,
  output err
);

  // State encoding
  typedef enum logic [3:0] {
    S0 = 4'b0000,  // 0 consecutive 1s
    S1 = 4'b0001,  // 1 consecutive 1
    S2 = 4'b0010,  // 2 consecutive 1s
    S3 = 4'b0011,  // 3 consecutive 1s
    S4 = 4'b0100,  // 4 consecutive 1s
    S5 = 4'b0101,  // 5 consecutive 1s
    S6 = 4'b0110,  // 6 consecutive 1s
    SDISC = 4'b0111,  // Discard state (after 6 1s and a 0)
    SFLAG = 4'b1000,  // Flag state (after 6 1s, then 0)
    SERR = 4'b1001   // Error state (7 or more 1s)
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
          next_state = SDISC;
      end
      
      S6: begin
        if (in)
          next_state = SERR;
        else
          next_state = SFLAG;
      end
      
      SDISC: begin
        if (in)
          next_state = S1;
        else
          next_state = S0;
      end
      
      SFLAG: begin
        if (in)
          next_state = S1;
        else
          next_state = S0;
      end
      
      SERR: begin
        if (in)
          next_state = SERR;
        else
          next_state = S0;
      end
      
      default: next_state = S0;
    endcase
  end

  // Output logic (Moore machine - outputs depend only on current state)
  assign disc = (current_state == SDISC);
  assign flag = (current_state == SFLAG);
  assign err = (current_state == SERR);

endmodule