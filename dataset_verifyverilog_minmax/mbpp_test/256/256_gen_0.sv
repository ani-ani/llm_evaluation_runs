module count_primes (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output logic [7:0] count,
  output logic done
);

  // State machine states
  typedef enum logic [2:0] {IDLE = 3'b000, CHECK_NUM = 3'b001, CHECK_DIV = 3'b010, UPDATE_COUNT = 3'b011, DONE = 3'b100} state_t;
  state_t state, next_state;

  // Iteration registers
  logic [7:0] current; // candidate number under test (2..n-1)
  logic [7:0] divisor; // divisor candidate (2..15)
  logic is_prime;
  logic done_next;

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  // Output and iteration registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count   <= 8'h0;
      current <= 8'h0;
      divisor <= 8'h0;
      is_prime <= 1'b0;
      done    <= 'b0;
    end else begin
      // Defaults; actual updates depend on next_state
      done    <= done_next;

      case (next_state)
        IDLE: begin
          count   <= 8'h0;
          current <= 8'h0;
          divisor <= 8'h0;
          is_prime <= 1'b0;
        end

        CHECK_NUM: begin
          // current is already set before entering this state
          divisor <= 8'd2; // start divisors from 2
          is_prime <= 1'b1; // assume prime until a divisor is found
        end

        CHECK_DIV: begin
          if (divisor >= current) begin
            // No divisor in [2..15) found and divisor reached current -> prime
            is_prime <= 1'b1;
          end else if (current % divisor == 8'b0) begin
            // Found a divisor in [2..15) that evenly divides current -> not prime
            is_prime <= 1'b0;
          end
          // Else keep is_prime and increment divisor in combinatorial logic below
          if (divisor < 8'd15) begin
            divisor <= divisor + 1;
          end
        end

        UPDATE_COUNT: begin
          if (is_prime) count <= count + 1;
          current <= current + 1;
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
          // Keep current values; shouldn't get here
        end
      endcase
    end
  end

  // Combinatorial next-state logic
  always_comb begin
    next_state = state;
    done_next  = 1'b0;

    case (state)
      IDLE: begin
        if (start) begin
          // Initialize for a new computation
          if (n <= 8'd2) begin
            // No numbers in [2, n-1], so result is 0 and done immediately
            next_state = DONE;
          end else begin
            // Start checking numbers beginning at 2
            current = 8'd2;
            next_state = CHECK_NUM;
          end
        end else begin
          next_state = IDLE;
        end
      end

      CHECK_NUM: begin
        if (current >= n) begin
          // Completed checking all numbers in [2, n-1]
          next_state = DONE;
        end else begin
          next_state = CHECK_DIV;
        end
      end

      CHECK_DIV: begin
        // Move to UPDATE_COUNT when divisor reaches 15 or current
        if (divisor >= 8'd15 || divisor >= current) begin
          next_state = UPDATE_COUNT;
        end else begin
          next_state = CHECK_DIV; // remain in this state while divisor advances
        end
      end

      UPDATE_COUNT: begin
        // After counting, proceed to next number or finish
        if (current + 1 >= n) begin
          next_state = DONE;
        end else begin
          next_state = CHECK_NUM;
        end
      end

      DONE: begin
        done_next = 1'b1;
        if (start) begin
          // If start is held, restart on next cycle
          if (n <= 8'd2) begin
            next_state = DONE;
          end else begin
            current = 8'd2;
            next_state = CHECK_NUM;
          end
        end else begin
          next_state = DONE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
