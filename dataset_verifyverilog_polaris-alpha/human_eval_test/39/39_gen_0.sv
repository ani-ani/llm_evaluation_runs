module prime_fib (
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] n,
  output reg [14:0] result,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE        = 3'd0,
    GENERATE    = 3'd1,
    CHECK_PRIME = 3'd2,
    EVALUATE    = 3'd3,
    DONE        = 3'd4
  } state_t;

  state_t state, next_state;

  // Fibonacci generation registers
  reg [14:0] fib_prev;      // F(k-1)
  reg [14:0] fib_curr;      // F(k)
  reg [14:0] fib_next;      // F(k+1) candidate

  // Prime checking registers
  reg [14:0] candidate;     // Current Fibonacci number being checked
  reg [7:0]  divisor;       // Trial divisor (sufficient width for sqrt(28657) < 256)
  reg        is_prime;      // Flag indicating primality status
  reg        div_done;      // Division iteration done flag

  // Count of prime Fibonacci numbers found so far
  reg [2:0] prime_count;

  // sqrt limit register (integer sqrt of candidate)
  reg [7:0] sqrt_limit;

  // Simple combinational integer sqrt (floor) up to 15-bit input
  function automatic [7:0] isqrt15 (input [14:0] x);
    integer i;
    reg [7:0] r;
    begin
      r = 0;
      for (i = 7; i >= 0; i = i - 1) begin
        if (((r | (8'd1 << i)) * (r | (8'd1 << i))) <= x)
          r = r | (8'd1 << i);
      end
      isqrt15 = r;
    end
  endfunction

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
    end else begin
      state        <= next_state;
    end
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      fib_prev     <= 15'd0;
      fib_curr     <= 15'd0;
      fib_next     <= 15'd0;
      candidate    <= 15'd0;
      divisor      <= 8'd0;
      is_prime     <= 1'b0;
      div_done     <= 1'b0;
      prime_count  <= 3'd0;
      result       <= 15'd0;
      done         <= 1'b0;
      sqrt_limit   <= 8'd0;
    end else begin
      done <= 1'b0; // default, may be overridden in DONE state

      case (state)

        IDLE: begin
          // Wait for start; initialize on start
          if (start) begin
            // Initialize Fibonacci sequence starting at F(3) = 2
            // We'll hold F(2)=1 and F(3)=2 so next = 3
            fib_prev    <= 15'd1;   // F(2)
            fib_curr    <= 15'd2;   // F(3)
            prime_count <= 3'd0;
            result      <= 15'd0;
          end
        end

        GENERATE: begin
          // Compute next Fibonacci number: fib_next = fib_prev + fib_curr
          fib_next   <= fib_prev + fib_curr;
          // Prepare for prime checking in next states
          candidate  <= fib_prev + fib_curr;
          // Update sequence for subsequent iterations
          fib_prev   <= fib_curr;
          fib_curr   <= fib_prev + fib_curr; // uses old fib_prev via non-blocking
          // Initialize prime checking variables (next cycle used in CHECK_PRIME)
          is_prime   <= 1'b1;     // assume prime until proven composite
          div_done   <= 1'b0;
          // Compute sqrt limit combinationally here for use in CHECK_PRIME
          sqrt_limit <= isqrt15(fib_prev + fib_curr);
          // Initialize divisor (actual load in CHECK_PRIME for clarity)
        end

        CHECK_PRIME: begin
          // Handle small / trivial cases first (sequentially)
          if (!div_done) begin
            if (candidate < 15'd2) begin
              // 0 and 1 are not prime
              is_prime  <= 1'b0;
              div_done  <= 1'b1;
            end else if (candidate == 15'd2) begin
              is_prime  <= 1'b1;
              div_done  <= 1'b1;
            end else if ((candidate[0] == 1'b0)) begin
              // Even and not 2 -> not prime
              is_prime  <= 1'b0;
              div_done  <= 1'b1;
            end else begin
              // Start / continue trial division with odd divisors from 3 up to sqrt_limit
              if (divisor == 8'd0) begin
                divisor <= 8'd3;
              end else begin
                // Perform one divisor check per cycle
                if (divisor <= sqrt_limit) begin
                  if ((candidate % divisor) == 0) begin
                    is_prime <= 1'b0;
                    div_done <= 1'b1; // composite found
                  end else begin
                    // Move to next odd divisor
                    divisor <= divisor + 8'd2;
                  end
                end else begin
                  // No divisors found up to sqrt_limit -> prime
                  is_prime <= 1'b1;
                  div_done <= 1'b1;
                end
              end
            end
          end
        end

        EVALUATE: begin
          // Use is_prime result from CHECK_PRIME
          if (is_prime) begin
            prime_count <= prime_count + 3'd1;
            if (prime_count + 3'd1 == n) begin
              result <= candidate;
            end
          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start)
          next_state = GENERATE;
      end

      GENERATE: begin
        // Move directly to prime checking of newly generated Fibonacci number
        next_state = CHECK_PRIME;
      end

      CHECK_PRIME: begin
        // Wait until division process completes
        if (div_done)
          next_state = EVALUATE;
      end

      EVALUATE: begin
        // If reached requested count, go to DONE; else generate next Fibonacci
        if (is_prime && (prime_count + 3'd1 == n))
          next_state = DONE;
        else
          next_state = GENERATE;
      end

      DONE: begin
        // Stay in DONE until start is deasserted and reasserted; return to IDLE on new start
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule