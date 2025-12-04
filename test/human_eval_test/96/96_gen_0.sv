module prime_generator (
  input        clk,
  input        rst_n,
  input        start,
  input  [4:0] n,
  output reg [4:0] prime,
  output reg       valid,
  output reg       done
);

  // State encoding
  localparam IDLE       = 2'd0;
  localparam FIND_NEXT  = 2'd1;
  localparam CHECK_DIV  = 2'd2;
  localparam OUTPUT_PR  = 2'd3;

  reg [1:0] state, next_state;

  reg [4:0] candidate;       // Current candidate number to test
  reg [4:0] divisor;         // Current divisor being tested
  reg       is_prime;        // Flag indicating current candidate is still prime
  reg [4:0] limit;           // sqrt-based limit for divisor checking

  // Next-state and control logic
  always @(*) begin
    // Default assignments for combinational signals
    next_state = state;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = FIND_NEXT;
        end
      end

      FIND_NEXT: begin
        // Decide behavior in sequential block; here we only select next state:
        // If candidate >= n -> go DONE (handled via done flag stay), else check primality
        // Next state will be CHECK_DIV when candidate < n
        next_state = CHECK_DIV;
      end

      CHECK_DIV: begin
        // If not prime or exceeded limit, move to either OUTPUT_PR or FIND_NEXT
        if (!is_prime) begin
          next_state = FIND_NEXT;
        end else if (divisor >= limit) begin
          next_state = OUTPUT_PR; // candidate confirmed prime
        end else begin
          next_state = CHECK_DIV; // continue checking
        end
      end

      OUTPUT_PR: begin
        // After one cycle of valid, move to FIND_NEXT to search for next prime
        next_state = FIND_NEXT;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      candidate <= 5'd0;
      divisor   <= 5'd0;
      is_prime  <= 1'b0;
      limit     <= 5'd0;
      prime     <= 5'd0;
      valid     <= 1'b0;
      done      <= 1'b0;
    end else begin
      state <= next_state;

      // Default per-cycle outputs
      valid <= 1'b0;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          prime     <= 5'd0;
          candidate <= 5'd0;
          divisor   <= 5'd0;
          is_prime  <= 1'b0;
          limit     <= 5'd0;
          if (start) begin
            // Start search from first prime candidate
            candidate <= 5'd2;
          end
        end

        FIND_NEXT: begin
          done <= 1'b0;
          // If all candidates checked (candidate >= n), assert done and wait for next start
          if (candidate >= n || n <= 2) begin
            done <= 1'b1;
            // Stay here until new start resets sequence via IDLE->FIND_NEXT
            if (start) begin
              done      <= 1'b0;
              candidate <= 5'd2;
              divisor   <= 5'd0;
              is_prime  <= 1'b0;
              limit     <= 5'd0;
            end
          end else begin
            // Initialize prime checking for current candidate
            is_prime <= 1'b1;
            divisor  <= 5'd2;
            // Compute limit = floor(sqrt(candidate)) via small lookup/logic
            // For 5-bit numbers, direct comparison is efficient
            if (candidate <= 5'd3)       limit <= 5'd1;  // no divisor checks needed
            else if (candidate <= 5'd8)  limit <= 5'd2;  // sqrt(max 8)  ~ 2.x
            else if (candidate <= 5'd15) limit <= 5'd3;  // sqrt(max 15) ~ 3.x
            else if (candidate <= 5'd24) limit <= 5'd4;  // sqrt(max 24) ~ 4.x
            else                         limit <= 5'd5;  // up to 31 -> sqrt ~ 5.x
          end
        end

        CHECK_DIV: begin
          done <= 1'b0;
          if (candidate >= n || n <= 2) begin
            done <= 1'b1;
          end else begin
            // If still considered prime and divisor within limit, test divisibility
            if (is_prime && (divisor <= limit) && (divisor != 0)) begin
              if ((candidate % divisor) == 0 && divisor != candidate) begin
                // Not prime
                is_prime <= 1'b0;
              end
              // Increment divisor for next cycle if continuing
              if (divisor < limit)
                divisor <= divisor + 5'd1;
            end
          end
        end

        OUTPUT_PR: begin
          if (is_prime && candidate < n && candidate >= 5'd2) begin
            prime <= candidate;
            valid <= 1'b1; // Pulse valid for this prime
          end
          // Prepare next candidate for next cycle
          if (candidate + 5'd1 < 5'd31)
            candidate <= candidate + 5'd1;
          else
            candidate <= 5'd31;
          // Clear prime-checking state
          is_prime <= 1'b0;
          divisor  <= 5'd0;
          limit    <= 5'd0;
          done     <= 1'b0;
        end

        default: begin
          // Safety defaults
          done  <= 1'b0;
          valid <= 1'b0;
        end
      endcase
    end
  end

endmodule