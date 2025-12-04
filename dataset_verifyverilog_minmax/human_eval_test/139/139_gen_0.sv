module special_factorial(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [2:0] n,
  output reg [63:0] result,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE          = 2'b00,
    COMPUTE_FACT  = 2'b01,
    MULTIPLY_PROD = 2'b10,
    DONE          = 2'b11
  } state_t;

  state_t state, next_state;
  reg [2:0] k, next_k;
  reg [3:0] inner_cnt, next_inner_cnt;
  reg [63:0] fact_temp, next_fact_temp;
  reg [63:0] next_result;
  reg next_done;

  // Combinational next-state logic
  always_comb begin
    // Default assignments (avoid latches)
    next_state     = state;
    next_result    = result;
    next_done      = done;
    next_k         = k;
    next_inner_cnt = inner_cnt;
    next_fact_temp = fact_temp;

    case (state)
      IDLE: begin
        next_done = 1'b0;
        if (start) begin
          // Capture n and initialise registers
          next_k         = n;
          next_result    = 64'h1;        // product starts at 1
          next_fact_temp = 64'h0;        // will be set in COMPUTE_FACT
          next_inner_cnt = 4'b0;         // triggers initialisation in next state
          next_state     = COMPUTE_FACT;
        end
      end

      COMPUTE_FACT: begin
        // Compute k! using an inner counter
        if (inner_cnt == 4'b0) begin
          // First cycle of this factorial: set accumulator to 1
          next_fact_temp = 64'h1;
          next_inner_cnt = 4'b1;          // start multiplying by 1
        end else if (inner_cnt == k) begin
          // Final multiplication by k
          next_fact_temp = fact_temp * k;
          // Factorial completed – go to product stage
          next_state = MULTIPLY_PROD;
          // Reset inner counter for the next factorial (will be ignored in next state)
          next_inner_cnt = 4'b0;
        end else begin
          // Intermediate multiplication
          next_fact_temp = fact_temp * inner_cnt;
          next_inner_cnt = inner_cnt + 1;
        end
        next_done = 1'b0;
      end

      MULTIPLY_PROD: begin
        // Multiply the running product by the freshly computed factorial
        next_result = result * fact_temp;
        // After multiplication, check if this was the last factorial
        if (k == 3'b1) begin
          // All factorials have been incorporated
          next_state = DONE;
        end else begin
          // Prepare for the next factorial (k-1)
          next_k         = k - 1;
          next_inner_cnt = 4'b0;         // reset inner counter
          next_state     = COMPUTE_FACT;
        end
        next_done = 1'b0;
      end

      DONE: begin
        next_done = 1'b1;
        if (!start) begin
          // Return to IDLE when start is deasserted
          next_state = IDLE;
        end
      end

      default: begin
        // Undefined state – default to IDLE
        next_state = IDLE;
        next_done  = 1'b0;
      end
    endcase
  end

  // Sequential (registered) updates
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      result      <= 64'h1;   // reset result to 1
      done        <= 1'b0;
      k           <= 3'b0;
      inner_cnt   <= 4'b0;
      fact_temp   <= 64'b0;
    end else begin
      state       <= next_state;
      result      <= next_result;
      done        <= next_done;
      k           <= next_k;
      inner_cnt   <= next_inner_cnt;
      fact_temp   <= next_fact_temp;
    end
  end

endmodule
