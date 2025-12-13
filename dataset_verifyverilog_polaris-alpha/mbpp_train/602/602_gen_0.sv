module first_repeated_char(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [7:0]  str [0:7],
  output logic [7:0]  result,
  output logic        found,
  output logic        done
);

  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    SCAN  = 2'b01,
    DONE  = 2'b10
  } state_t;

  state_t      state, next_state;
  logic [2:0]  idx, next_idx;
  logic [7:0]  next_result;
  logic        next_found;
  logic        match_found;

  // Combinational match detection for current idx
  always_comb begin
    match_found = 1'b0;
    if (idx > 3'd0) begin
      if (idx > 3'd0 && str[idx] == str[0]) match_found = 1'b1;
      if (!match_found && idx > 3'd1 && str[idx] == str[1]) match_found = 1'b1;
      if (!match_found && idx > 3'd2 && str[idx] == str[2]) match_found = 1'b1;
      if (!match_found && idx > 3'd3 && str[idx] == str[3]) match_found = 1'b1;
      if (!match_found && idx > 3'd4 && str[idx] == str[4]) match_found = 1'b1;
      if (!match_found && idx > 3'd5 && str[idx] == str[5]) match_found = 1'b1;
      if (!match_found && idx > 3'd6 && str[idx] == str[6]) match_found = 1'b1;
    end
  end

  // Next-state and next-output logic (except done)
  always_comb begin
    next_state  = state;
    next_idx    = idx;
    next_result = result;
    next_found  = found;

    case (state)
      IDLE: begin
        next_result = 8'd0;
        next_found  = 1'b0;
        next_idx    = 3'd0;
        if (start) begin
          next_state = SCAN;
        end
      end

      SCAN: begin
        // Check current index for repetition
        if (match_found && !found) begin
          next_result = str[idx];
          next_found  = 1'b1;
          next_state  = DONE; // done will pulse next cycle
        end else if (idx == 3'd7) begin
          // Last index processed without finding a repetition
          next_found  = 1'b0;
          next_state  = DONE; // done will pulse next cycle
        end else begin
          // Move to next index
          next_idx = idx + 3'd1;
        end
      end

      DONE: begin
        // done is asserted for one cycle via sequential logic
        // Then return to IDLE and wait for next start
        next_state  = IDLE;
        next_idx    = 3'd0;
        // result and found held; cleared in IDLE on next cycle
      end

      default: begin
        next_state  = IDLE;
        next_idx    = 3'd0;
        next_result = 8'd0;
        next_found  = 1'b0;
      end
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state  <= IDLE;
      idx    <= 3'd0;
      result <= 8'd0;
      found  <= 1'b0;
      done   <= 1'b0;
    end else begin
      state  <= next_state;
      idx    <= next_idx;
      result <= next_result;
      found  <= next_found;

      // done pulse generation: high only in DONE state
      if (next_state == DONE)
        done <= 1'b1;
      else
        done <= 1'b0;
    end
  end

endmodule