module ab_pattern_matcher (
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] data,
  input  valid,
  output reg match,
  output reg done
);

  // FSM states
  typedef enum logic [2:0] {
    IDLE      = 3'b000,
    SEARCH_A  = 3'b001,
    SEARCH_B  = 3'b010,
    MATCH     = 3'b011,
    NO_MATCH  = 3'b100
  } state_t;

  state_t state, next_state;
  logic [4:0] char_cnt;     // up to 16 characters
  logic a_found;            // 'a' seen flag
  logic done_next;

  // Character count (counts only valid incoming characters, up to 16)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) char_cnt <= 5'b0;
    else if (state == IDLE) char_cnt <= 5'b0;
    else if (valid) char_cnt <= (char_cnt >= 5'd15) ? 5'd15 : (char_cnt + 1'b1);
  end

  // Registered one-cycle pulse for end-of-stream (valid falling edge)
  logic valid_r;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) valid_r <= 1'b0;
    else        valid_r <= valid;
  end
  assign end_of_stream = (~valid) & (valid_r); // one-cycle pulse when data stream ends

  // Main FSM state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  // Combinational next-state logic
  always_comb begin
    next_state = state; // default
    case (state)
      IDLE: begin
        if (start) next_state = SEARCH_A;
        else       next_state = IDLE;
      end

      SEARCH_A: begin
        if (valid && (data == 8'h61)) next_state = SEARCH_B; // found 'a'
        else if (end_of_stream)       next_state = NO_MATCH; // ended before any 'a'
        else                           next_state = SEARCH_A;
      end

      SEARCH_B: begin
        if (valid && (data == 8'h62)) next_state = MATCH;    // one or more 'b' after 'a'
        else if (end_of_stream)       next_state = NO_MATCH; // ended without 'b' after 'a'
        else                           next_state = SEARCH_B;
      end

      MATCH:     next_state = MATCH;    // terminal
      NO_MATCH:  next_state = NO_MATCH; // terminal
      default:   next_state = IDLE;
    endcase
  end

  // Done pulse only on end-of-stream; stays high for 1 cycle
  assign done_next = (end_of_stream && (state != IDLE)) ? 1'b1 : 1'b0;

  // Registered outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      match <= 1'b0;
      done  <= 1'b0;
    end else begin
      // match: sticky; only cleared on explicit NO_MATCH; set on MATCH
      if (next_state == MATCH)  match <= 1'b1;
      else if (next_state == NO_MATCH) match <= 1'b0;
      // done: one-cycle pulse when the input stream ends
      done <= done_next;
    end
  end

endmodule
