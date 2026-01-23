module lucky_numbers_supply (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [31:0] supply,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COUNTING,
    DONE
  } state_t;

  state_t state, next_state;
  reg [3:0] pos; // current digit position (1 to n)
  reg [31:0] counts [0:7]; // counts for remainders 0..(pos-1)
  reg [31:0] next_counts [0:7]; // next state counts

  // Initialize counts for position 1
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      pos <= 0;
      supply <= 0;
      done <= 0;
      for (int i = 0; i < 8; i = i + 1) begin
        counts[i] <= 0;
      end
    end else begin
      state <= next_state;
      if (state == COUNTING && pos < n) begin
        pos <= pos + 1;
        for (int i = 0; i < 8; i = i + 1) begin
          counts[i] <= next_counts[i];
        end
      end
    end
  end

  // State transition logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = COUNTING;
        else next_state = IDLE;
      end
      COUNTING: begin
        if (pos == n) next_state = DONE;
        else next_state = COUNTING;
      end
      DONE: begin
        if (!start) next_state = IDLE;
        else next_state = DONE;
      end
    endcase
  end

  // Compute next counts for current position
  always @(*) begin
    // Initialize next_counts to 0
    for (int i = 0; i < 8; i = i + 1) begin
      next_counts[i] = 0;
    end

    if (state == COUNTING) begin
      if (pos == 0) begin
        // Position 1: digits 1-9, all divisible by 1
        // Remainder 0 gets count of 9
        next_counts[0] = 9;
      end else begin
        // For positions 2 to n
        for (int prev_rem = 0; prev_rem < pos; prev_rem = prev_rem + 1) begin
          if (counts[prev_rem] > 0) begin
            for (int digit = 0; digit < 10; digit = digit + 1) begin
              // Compute new number: prev_num * 10 + digit
              // prev_num = prev_rem (since we're tracking remainders)
              // new_num = prev_rem * 10 + digit
              // new_rem = new_num % (pos + 1)
              int new_num = prev_rem * 10 + digit;
              int new_rem = new_num % (pos + 1);
              next_counts[new_rem] = next_counts[new_rem] + counts[prev_rem];
            end
          end
        end
      end
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      supply <= 0;
      done <= 0;
    end else begin
      if (state == DONE) begin
        supply <= counts[0]; // At position n, remainder 0 is the valid count
        done <= 1;
      end else begin
        supply <= 0;
        done <= 0;
      end
    end
  end

endmodule