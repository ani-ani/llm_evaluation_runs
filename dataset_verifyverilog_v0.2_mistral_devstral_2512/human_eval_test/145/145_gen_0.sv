module order_by_points (
  input clk,
  input rst_n,
  input start,
  input [4:0] count,
  input signed [15:0] nums [0:7],
  output reg [4:0] done_count,
  output reg signed [15:0] result [0:7],
  output reg done
);

  // Internal state machine states
  typedef enum logic [3:0] {
    IDLE,
    CALCULATE,
    COMPARE,
    SWAP,
    DONE
  } state_t;

  // State machine registers
  state_t state, next_state;
  reg [4:0] pass_count;      // Bubble sort pass counter (0-6)
  reg [4:0] elem_count;      // Element index counter (0-6)
  reg [4:0] digit_count;     // Digit extraction counter (0-4)
  reg [5:0] digit_sum_a;     // Digit sum for element A
  reg [5:0] digit_sum_b;     // Digit sum for element B
  reg [15:0] abs_a, abs_b;   // Absolute values for digit sum calculation
  reg [15:0] temp_a, temp_b; // Temporary values during digit extraction
  reg [15:0] current_num;    // Current number being processed
  reg [4:0] current_index;   // Current index being processed
  reg [4:0] swap_flag;       // Flag to indicate swap needed
  reg [4:0] done_delay;      // Delay counter for done signal

  // Internal array for sorting
  reg signed [15:0] sort_array [0:7];

  // State machine transition
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      pass_count <= 0;
      elem_count <= 0;
      digit_count <= 0;
      digit_sum_a <= 0;
      digit_sum_b <= 0;
      abs_a <= 0;
      abs_b <= 0;
      temp_a <= 0;
      temp_b <= 0;
      current_num <= 0;
      current_index <= 0;
      swap_flag <= 0;
      done_delay <= 0;
      done <= 0;
      done_count <= 0;
      for (int i = 0; i < 8; i = i + 1) begin
        sort_array[i] <= nums[i];
        result[i] <= 0;
      end
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          if (start) begin
            pass_count <= 0;
            elem_count <= 0;
            next_state <= CALCULATE;
          end else begin
            next_state <= IDLE;
          end
        end
        CALCULATE: begin
          // Calculate digit sums for two elements
          if (digit_count == 0) begin
            // Initialize for new pair
            abs_a <= (sort_array[elem_count] < 0) ? -sort_array[elem_count] : sort_array[elem_count];
            abs_b <= (sort_array[elem_count + 1] < 0) ? -sort_array[elem_count + 1] : sort_array[elem_count + 1];
            temp_a <= abs_a;
            temp_b <= abs_b;
            digit_sum_a <= 0;
            digit_sum_b <= 0;
            digit_count <= digit_count + 1;
          end else begin
            // Extract next digit
            if (digit_count < 5) begin
              digit_sum_a <= digit_sum_a + (temp_a % 10);
              digit_sum_b <= digit_sum_b + (temp_b % 10);
              temp_a <= temp_a / 10;
              temp_b <= temp_b / 10;
              digit_count <= digit_count + 1;
            end else begin
              // Done with digit sum calculation
              digit_count <= 0;
              next_state <= COMPARE;
            end
          end
        end
        COMPARE: begin
          // Compare digit sums and indices
          if (digit_sum_a > digit_sum_b) begin
            swap_flag <= 1;
          end else if (digit_sum_a == digit_sum_b) begin
            // For equal digit sums, preserve original order (no swap)
            swap_flag <= 0;
          end else begin
            swap_flag <= 0;
          end
          next_state <= SWAP;
        end
        SWAP: begin
          // Perform swap if needed
          if (swap_flag) begin
            reg signed [15:0] temp;
            temp = sort_array[elem_count];
            sort_array[elem_count] = sort_array[elem_count + 1];
            sort_array[elem_count + 1] = temp;
          end
          // Move to next element
          if (elem_count < (count - 2)) begin
            elem_count <= elem_count + 1;
            next_state <= CALCULATE;
          end else begin
            // Move to next pass
            if (pass_count < (count - 2)) begin
              pass_count <= pass_count + 1;
              elem_count <= 0;
              next_state <= CALCULATE;
            end else begin
              // Done with sorting
              next_state <= DONE;
            end
          end
        end
        DONE: begin
          // Copy results and set done signal
          if (done_delay < 2) begin
            done_delay <= done_delay + 1;
            for (int i = 0; i < 8; i = i + 1) begin
              result[i] <= sort_array[i];
            end
            done_count <= count;
            done <= 1;
          end else begin
            done <= 0;
            next_state <= IDLE;
          end
        end
        default: next_state <= IDLE;
      endcase
    end
  end

endmodule