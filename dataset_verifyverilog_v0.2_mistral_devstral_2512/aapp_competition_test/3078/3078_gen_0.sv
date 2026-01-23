module longest_interesting_subsequence (
  input clk,
  input rst_n,
  input start,
  input [7:0] A [0:15],
  input [31:0] S,
  output reg [7:0] result [0:15],
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COMPUTE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [3:0] start_pos;
  reg [3:0] k_val;
  reg [3:0] max_len [0:15];
  reg [31:0] sum1, sum2;
  reg [3:0] i, j;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      start_pos <= 0;
      k_val <= 0;
      for (int idx = 0; idx < 16; idx++) begin
        result[idx] <= 0;
        max_len[idx] <= 0;
      end
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = COMPUTE;
        else next_state = IDLE;
      end
      COMPUTE: begin
        if (start_pos == 15 && k_val == 15) next_state = DONE;
        else next_state = COMPUTE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
        else next_state = DONE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else if (current_state == COMPUTE) begin
      // Compute sums for current (start_pos, k_val)
      sum1 = 0;
      sum2 = 0;
      for (i = 0; i < k_val; i++) begin
        if (start_pos + i < 16) sum1 = sum1 + A[start_pos + i];
      end
      for (i = 0; i < k_val; i++) begin
        if (start_pos + k_val + i < 16) sum2 = sum2 + A[start_pos + k_val + i];
      end

      // Check if both sums are <= S
      if (sum1 <= S && sum2 <= S && 2*k_val > max_len[start_pos]) begin
        max_len[start_pos] = 2*k_val;
      end

      // Update k_val and start_pos
      if (k_val == 15) begin
        k_val <= 0;
        start_pos <= start_pos + 1;
        result[start_pos - 1] <= max_len[start_pos - 1];
      end else begin
        k_val <= k_val + 1;
      end
    end else if (current_state == DONE) begin
      done <= 1;
      result[15] <= max_len[15];
    end
  end

endmodule