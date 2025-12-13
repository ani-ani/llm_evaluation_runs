module mirko_game_solver(
  input clk,
  input rst_n,
  input start,
  input [7:0] K,
  input [7:0] L,
  input [7:0] M,
  output reg [15:0] result,
  output reg done
);

  // State encoding
  localparam IDLE        = 3'd0;
  localparam CHECK_S     = 3'd1;
  localparam CHECK_NUM   = 3'd2;
  localparam CHECK_PRIME = 3'd3;
  localparam UPDATE      = 3'd4;
  localparam DONE_STATE  = 3'd5;

  reg [2:0] state, next_state;

  reg [15:0] S;                 // current candidate start
  reg [7:0]  idx;               // index 0..K-1 within window
  reg [7:0]  happy_cnt;         // count of happy numbers in current window
  reg [15:0] cur_num;           // current number being evaluated: S + idx

  // prime checking
  reg        is_happy;          // result for current number
  reg        prime_check_done;  // pulse when prime check done
  reg        prime_candidate_prime; // result of prime check
  reg [15:0] div;

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      result     <= 16'd0;
      done       <= 1'b0;
      S          <= 16'd1;
      idx        <= 8'd0;
      happy_cnt  <= 8'd0;
      cur_num    <= 16'd0;
      div        <= 16'd0;
      is_happy   <= 1'b0;
      prime_check_done <= 1'b0;
      prime_candidate_prime <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          // Wait for start; reset outputs when new start asserted
          if (start) begin
            done      <= 1'b0;
            result    <= 16'd0;
            S         <= 16'd1;
            idx       <= 8'd0;
            happy_cnt <= 8'd0;
          end
        end

        CHECK_S: begin
          // Initialize for new candidate S
          idx       <= 8'd0;
          happy_cnt <= 8'd0;
        end

        CHECK_NUM: begin
          // Prepare current number and check immediate happy condition
          cur_num  <= S + idx;
          is_happy <= 1'b0;

          // If num <= M, it's happy (handled combinationally via next_state)
          // Otherwise, start prime check if needed.

          // Reset prime check flags when entering prime check phase
          if (!( (S + idx) <= M )) begin
            prime_check_done       <= 1'b0;
            prime_candidate_prime  <= 1'b1; // assume prime until proven otherwise
            // Start from first possible divisor (2)
            div <= 16'd2;
          end
        end

        CHECK_PRIME: begin
          // Perform one trial division step per cycle until sqrt(cur_num)
          if (!prime_check_done) begin
            if (div * div > cur_num) begin
              // No divisor found up to sqrt -> prime
              prime_check_done      <= 1'b1;
              prime_candidate_prime <= 1'b1;
            end else if (cur_num % div == 16'd0) begin
              // Found a divisor -> not prime
              prime_check_done      <= 1'b1;
              prime_candidate_prime <= 1'b0;
            end else begin
              // Next divisor
              div <= div + 16'd1;
            end
          end
        end

        UPDATE: begin
          // Decide happiness based on M or prime result
          if (cur_num <= M) begin
            is_happy <= 1'b1;
          end else begin
            is_happy <= prime_candidate_prime;
          end

          // Update count and index/window
          if (is_happy) begin
            happy_cnt <= happy_cnt + 8'd1;
          end

          if (idx + 8'd1 < K) begin
            // Move to next number in window
            idx <= idx + 8'd1;
          end else begin
            // Completed window for current S: check if it matches L
            if (happy_cnt + (is_happy ? 8'd1 : 8'd0) == L) begin
              result <= S;
              done   <= 1'b1;
            end else begin
              // Try next S
              if (S == 16'd65535) begin
                // Exceeded max S
                result <= 16'hFFFF; // -1 represented as 0xFFFF
                done   <= 1'b1;
              end else begin
                S <= S + 16'd1;
              end
            end
          end
        end

        DONE_STATE: begin
          // Hold result and done high until next start
          if (start) begin
            done      <= 1'b0;
            result    <= 16'd0;
            S         <= 16'd1;
            idx       <= 8'd0;
            happy_cnt <= 8'd0;
          end
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start)
          next_state = CHECK_S;
        else
          next_state = IDLE;
      end

      CHECK_S: begin
        // Start checking first number in window for current S
        if (S > 16'd65535) begin
          next_state = DONE_STATE;
        end else begin
          next_state = CHECK_NUM;
        end
      end

      CHECK_NUM: begin
        if (S > 16'd65535) begin
          next_state = DONE_STATE;
        end else begin
          // If cur_num <= M, immediate happy, go to UPDATE
          if ((S + idx) <= M)
            next_state = UPDATE;
          else
            // need to check primality
            next_state = CHECK_PRIME;
        end
      end

      CHECK_PRIME: begin
        if (prime_check_done)
          next_state = UPDATE;
        else
          next_state = CHECK_PRIME;
      end

      UPDATE: begin
        // Decide where to go based on progress
        if (done) begin
          // Found solution or reached limit
          next_state = DONE_STATE;
        end else begin
          // If finished window (idx updated in seq block), either go to CHECK_S for next S or continue
          if (idx + 8'd1 < K)
            next_state = CHECK_NUM;
          else
            next_state = CHECK_S;
        end
      end

      DONE_STATE: begin
        if (start)
          next_state = CHECK_S;
        else
          next_state = DONE_STATE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule