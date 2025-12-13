module abbb_matcher (
  input  clk,
  input  rst_n,
  input  [7:0] char,
  input  valid,
  input  last,
  output match
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE       = 3'd0,
    GOT_A      = 3'd1,
    GOT_B1     = 3'd2,
    GOT_B2     = 3'd3,
    MATCH_DONE = 3'd4
  } state_t;

  state_t state, next_state;

  // Sequential state update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else if (valid)
      state <= next_state;
  end

  // Next-state logic and Mealy-style match
  logic match_cmb;

  always_comb begin
    next_state = state;
    match_cmb  = 1'b0;

    if (!rst_n) begin
      next_state = IDLE;
      match_cmb  = 1'b0;
    end else if (valid) begin
      unique case (state)
        IDLE: begin
          if (char == 8'h61) // 'a'
            next_state = GOT_A;
          else
            next_state = IDLE;
        end

        GOT_A: begin
          if (char == 8'h62) // 'b'
            next_state = GOT_B1;
          else if (char == 8'h61)
            next_state = GOT_A; // overlapping potential: new 'a'
          else
            next_state = IDLE;
        end

        GOT_B1: begin
          if (char == 8'h62)
            next_state = GOT_B2;
          else if (char == 8'h61)
            next_state = GOT_A;
          else
            next_state = IDLE;
        end

        GOT_B2: begin
          if (char == 8'h62) begin
            // Completed "abbb" pattern
            match_cmb  = 1'b1;     // Mealy: assert on this char
            next_state = MATCH_DONE;
          end else if (char == 8'h61)
            next_state = GOT_A;
          else
            next_state = IDLE;
        end

        MATCH_DONE: begin
          // Allow overlapping detection after a match
          if (char == 8'h61)
            next_state = GOT_A;
          else if (char == 8'h62)
            next_state = GOT_B1; // treat as potential start "b" after implied 'a'? kept simple
          else
            next_state = IDLE;
        end

        default: begin
          next_state = IDLE;
        end
      endcase
    end
  end

  // Combinational match output (Mealy-style)
  assign match = match_cmb;

endmodule