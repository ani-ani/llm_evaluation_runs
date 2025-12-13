module largest_prime_digit_sum (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [511:0] lst_packed,
  output logic [4:0]  digit_sum,
  output logic        done
);

  // FSM States
  typedef enum logic [2:0] {
    S_IDLE       = 3'd0,
    S_SCAN       = 3'd1,
    S_PRIME_TEST = 3'd2,
    S_UPDATE_MAX = 3'd3,
    S_FIND_SUM   = 3'd4,
    S_DONE       = 3'd5
  } state_t;

  state_t state, next_state;

  // Index for 32 elements
  logic [4:0] idx;            // 0..31
  logic [15:0] curr_val;

  // Prime test signals
  logic        prime_check_in_progress;
  logic [15:0] prime_n;
  logic [15:0] prime_div;
  logic        is_prime_flag;
  logic        prime_test_done;

  // Largest prime tracking
  logic [15:0] largest_prime;
  logic        found_prime;

  // For digit sum
  logic [15:0] sum_n;
  logic [4:0]  sum_acc;

  // Rising edge detect for start
  logic start_d;
  wire  start_pulse = start & ~start_d;

  // Extract current value from packed list
  always_comb begin
    curr_val = lst_packed[(idx*16) +: 16];
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state              <= S_IDLE;
      idx                <= 5'd0;
      largest_prime      <= 16'd0;
      found_prime        <= 1'b0;
      prime_check_in_progress <= 1'b0;
      prime_n            <= 16'd0;
      prime_div          <= 16'd0;
      is_prime_flag      <= 1'b0;
      sum_n              <= 16'd0;
      sum_acc            <= 5'd0;
      digit_sum          <= 5'd0;
      done               <= 1'b0;
      start_d            <= 1'b0;
    end else begin
      start_d <= start;

      state <= next_state;

      case (state)
        S_IDLE: begin
          if (start_pulse) begin
            // Initialize for new computation
            idx           <= 5'd0;
            largest_prime <= 16'd0;
            found_prime   <= 1'b0;
            digit_sum     <= 5'd0;
            done          <= 1'b0;
          end
        end

        S_SCAN: begin
          // Nothing sequential here; transition handled in next_state
        end

        S_PRIME_TEST: begin
          if (!prime_check_in_progress) begin
            // Start prime test for curr_val
            prime_check_in_progress <= 1'b1;
            prime_n   <= curr_val;
            // Handle values <= 3 quickly
            if (curr_val <= 16'd1) begin
              is_prime_flag <= 1'b0;
              prime_div     <= 16'd0;
            end else if (curr_val == 16'd2 || curr_val == 16'd3) begin
              is_prime_flag <= 1'b1;
              prime_div     <= 16'd0;
            end else if ((curr_val[0] == 1'b0)) begin
              // Even >2 is not prime
              is_prime_flag <= 1'b0;
              prime_div     <= 16'd0;
            end else begin
              // Start trial division from 3
              is_prime_flag <= 1'b1;
              prime_div     <= 16'd3;
            end
          end else if (prime_check_in_progress && !prime_test_done) begin
            // Ongoing trial division
            if (prime_div != 16'd0) begin
              // Check divisor up to prime_div*prime_div <= prime_n
              if ((prime_div * prime_div) > prime_n) begin
                // No divisor found
                prime_div <= 16'd0; // indicates completion
              end else if ((prime_n % prime_div) == 16'd0) begin
                // Found a divisor -> not prime
                is_prime_flag <= 1'b0;
                prime_div     <= 16'd0; // indicates completion
              end else begin
                prime_div <= prime_div + 16'd2; // check next odd divisor
              end
            end
          end

          // Detect completion
          if (prime_check_in_progress && (prime_div == 16'd0)) begin
            prime_check_in_progress <= 1'b0;
          end
        end

        S_UPDATE_MAX: begin
          // Update largest_prime if needed and move to next index
          if (is_prime_flag) begin
            if (!found_prime || (curr_val > largest_prime)) begin
              largest_prime <= curr_val;
              found_prime   <= 1'b1;
            end
          end
          // advance index
          idx <= idx + 5'd1;
        end

        S_FIND_SUM: begin
          // Iteratively compute decimal digit sum of largest_prime
          if (sum_n == 16'd0) begin
            digit_sum <= sum_acc;
          end else begin
            sum_acc <= sum_acc + sum_n % 10;
            sum_n   <= sum_n / 10;
          end
        end

        S_DONE: begin
          // Hold done and digit_sum until next start_pulse
          if (start_pulse) begin
            done <= 1'b0; // will be reasserted at end of next computation
          end else begin
            done <= 1'b1;
          end
        end

        default: begin
        end
      endcase
    end
  end

  // Prime test done combinational flag
  assign prime_test_done = (prime_check_in_progress && (prime_div == 16'd0));

  // Next state logic
  always_comb begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start_pulse) begin
          next_state = S_SCAN;
        end
      end

      S_SCAN: begin
        // Move to prime test for current idx
        next_state = S_PRIME_TEST;
      end

      S_PRIME_TEST: begin
        if (!prime_check_in_progress && (prime_n != 16'd0 || !is_prime_flag || prime_n <= 16'd3 || (prime_n[0] == 1'b0) || prime_n <= 16'd1)) begin
          // For small/quick decisions, completion happens immediately
          next_state = S_UPDATE_MAX;
        end else if (prime_test_done) begin
          next_state = S_UPDATE_MAX;
        end
      end

      S_UPDATE_MAX: begin
        if (idx == 5'd31) begin
          // Completed last element just now
          if (!found_prime) begin
            // No prime found: digit_sum = 0, done = 1
            next_state = S_DONE;
          end else begin
            // Start digit sum of largest_prime
            next_state = S_FIND_SUM;
          end
        end else begin
          // Continue scanning
          next_state = S_SCAN;
        end
      end

      S_FIND_SUM: begin
        if (sum_n == 16'd0) begin
          // One more cycle to latch digit_sum, then done
          next_state = S_DONE;
        end else begin
          next_state = S_FIND_SUM;
        end
      end

      S_DONE: begin
        if (start_pulse) begin
          next_state = S_SCAN;
        end else begin
          next_state = S_DONE;
        end
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // Initialize digit sum computation when entering S_FIND_SUM
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum_n   <= 16'd0;
      sum_acc <= 5'd0;
    end else begin
      if (state == S_UPDATE_MAX && next_state == S_FIND_SUM) begin
        sum_n   <= largest_prime;
        sum_acc <= 5'd0;
      end else if (state == S_FIND_SUM) begin
        // Body handled in main FSM sequential block
      end else if (state == S_UPDATE_MAX && next_state == S_DONE && !found_prime) begin
        // No prime case: ensure digit_sum is zeroed here; done asserted in S_DONE
        sum_n   <= 16'd0;
        sum_acc <= 5'd0;
      end
    end
  end

endmodule
