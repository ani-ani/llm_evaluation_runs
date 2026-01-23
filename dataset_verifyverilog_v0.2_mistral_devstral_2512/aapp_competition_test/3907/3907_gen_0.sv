module max_payout (
  input clk,
  input rst_n,
  input start,
  input [11:0] num_n,
  input [7:0] num_m,
  input [15:0] weights [0:99],
  output reg [31:0] max_sum,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALC,
    DONE
  } state_t;
  state_t current_state, next_state;

  // Internal registers
  reg [5:0] k_counter;
  reg [31:0] sum_reg;
  reg [15:0] current_weight;
  reg [11:0] required_size;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      k_counter <= 0;
      sum_reg <= 0;
      max_sum <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CALC;
        else next_state = IDLE;
      end
      CALC: begin
        if (k_counter == num_m) next_state = DONE;
        else next_state = CALC;
      end
      DONE: next_state = IDLE;
    endcase
  end

  // Calculation logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      k_counter <= 0;
      sum_reg <= 0;
    end else if (current_state == CALC) begin
      // Calculate required size based on k
      if (k_counter[0]) begin // k is odd
        required_size = (k_counter * (k_counter - 1)) / 2 + 1;
      end else begin // k is even
        required_size = (k_counter * k_counter) / 2;
      end

      // Check if we can use this k
      if (required_size <= num_n) begin
        current_weight = weights[k_counter - 1];
        sum_reg <= sum_reg + current_weight;
      end

      // Increment k
      if (k_counter < num_m) begin
        k_counter <= k_counter + 1;
      end
    end else if (current_state == DONE) begin
      max_sum <= sum_reg;
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule