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
    S0 = 4'd0,  // 0 consecutive 1s
    S1 = 4'd1,  // 1 consecutive 1s
    S2 = 4'd2,  // 2 consecutive 1s
    S3 = 4'd3,  // 3 consecutive 1s
    S4 = 4'd4,  // 4 consecutive 1s
    S5 = 4'd5,  // 5 consecutive 1s
    S6 = 4'd6,  // 6 consecutive 1s (flag or discard next)
    S_ERR = 4'd7  // 7+ consecutive 1s (error)
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
          next_state = S0;
      end
      
      S6: begin
        if (in)
          next_state = S_ERR;
        else
          next_state = S0;
      end
      
      S_ERR: begin
        if (in)
          next_state = S_ERR;
        else
          next_state = S0;
      end
      
      default: next_state = S0;
    endcase
  end

  // Output logic (Moore outputs based on current state)
  assign disc = (current_state == S6) && (in == 1'b0);
  assign flag = (current_state == S6) && (in == 1'b0) && (next_state == S0);
  assign err = (current_state == S6) && (in == 1'b1);

  // Corrected output logic for Moore machine
  // Outputs depend only on current state
  reg disc_reg, flag_reg, err_reg;
  
  always_ff @(posedge clk) begin
    if (reset) begin
      disc_reg <= 1'b0;
      flag_reg <= 1'b0;
      err_reg <= 1'b0;
    end else begin
      // disc: 0111110 pattern (6 ones followed by 0)
      disc_reg <= (current_state == S6) && (in == 1'b0);
      // flag: 01111110 pattern (6 ones followed by 0, same as disc in this case)
      flag_reg <= (current_state == S6) && (in == 1'b0);
      // err: 01111111... pattern (7 or more ones)
      err_reg <= (current_state == S6) && (in == 1'b1);
    end
  end

  assign disc = disc_reg;
  assign flag = flag_reg;
  assign err = err_reg;

endmodule