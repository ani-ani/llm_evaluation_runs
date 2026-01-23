module carryless_sqrt(
  input clk,
  input rst_n,
  input start,
  input [23:0] n,
  input [3:0] num_digits,
  output reg [11:0] result,
  output reg [3:0] result_digits,
  output reg done,
  output reg found
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SEARCH,
    VERIFY,
    DONE
  } state_t;

  state_t state, next_state;

  // Candidate value (3 digits, 12 bits)
  reg [11:0] candidate;
  reg [11:0] candidate_sq;

  // Verification variables
  reg [3:0] c0, c1, c2, c3, c4;
  reg [3:0] a0, a1, a2;
  reg [3:0] verify_cycle;

  // Control signals
  reg [1:0] verify_state;

  // Initialize state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      candidate <= 0;
      result <= 0;
      result_digits <= 0;
      done <= 0;
      found <= 0;
      verify_cycle <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = SEARCH;
      end
      SEARCH: begin
        if (candidate == 999) next_state = DONE;
        else if (verify_cycle == 0) next_state = VERIFY;
      end
      VERIFY: begin
        if (verify_cycle == 4) next_state = SEARCH;
      end
      DONE: next_state = IDLE;
    endcase
  end

  // Candidate generation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      candidate <= 0;
    end else if (state == SEARCH && verify_cycle == 0) begin
      if (candidate == 999) candidate <= 0;
      else candidate <= candidate + 1;
    end
  end

  // Verification state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      verify_cycle <= 0;
      a0 <= 0; a1 <= 0; a2 <= 0;
      c0 <= 0; c1 <= 0; c2 <= 0; c3 <= 0; c4 <= 0;
    end else if (state == VERIFY) begin
      case (verify_cycle)
        0: begin
          a0 <= candidate[3:0];
          a1 <= candidate[7:4];
          a2 <= candidate[11:8];
          c0 <= (a0 * a0) % 10;
          verify_cycle <= 1;
        end
        1: begin
          c1 <= (2 * a0 * a1) % 10;
          verify_cycle <= 2;
        end
        2: begin
          c2 <= (2 * a0 * a2 + a1 * a1) % 10;
          verify_cycle <= 3;
        end
        3: begin
          c3 <= (2 * a1 * a2) % 10;
          verify_cycle <= 4;
        end
        4: begin
          c4 <= (a2 * a2) % 10;
          verify_cycle <= 0;
        end
      endcase
    end
  end

  // Result comparison
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      found <= 0;
    end else if (state == VERIFY && verify_cycle == 4) begin
      // Pack the result
      candidate_sq = {c4, c3, c2, c1, c0};
      
      // Compare with N (only compare up to num_digits)
      reg match = 1;
      for (int i = 0; i < num_digits; i++) begin
        if (candidate_sq[(i*4)+:4] != n[(i*4)+:4]) match = 0;
      end
      
      if (match) begin
        result <= candidate;
        result_digits <= 3;
        found <= 1;
        done <= 1;
        next_state = DONE;
      end
    end else if (state == SEARCH && candidate == 999) begin
      done <= 1;
      found <= 0;
    end
  end

endmodule