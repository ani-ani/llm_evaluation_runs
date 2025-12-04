module mirko_game_solver(
  input clk,                      // system clock
  input rst_n,                    // active-low reset
  input start,                    // pulse high to start processing
  input [7:0] K,                  // window size [1-150]
  input [7:0] L,                  // required happy count [0-K]
  input [7:0] M,                  // happy threshold [1-150]
  output reg [15:0] result,       // solution (start number or -1)
  output reg done                 // high when result valid
);

  // State encoding
  localparam IDLE       = 3'd0;
  localparam CHECK_S    = 3'd1;
  localparam CHECK_NUM  = 3'd2;
  localparam CHECK_PRIME= 3'd3;
  localparam UPDATE     = 3'd4;
  localparam DONE       = 3'd5;

  reg [2:0] state, next_state;

  // Search and window control
  reg [15:0] S;          // current candidate start number
  reg [15:0] n;          // current number within window [S, S+K-1]
  reg [7:0] happy_cnt;   // count of happy numbers in current window

  // Prime check signals
  reg [15:0] p_n;
  reg [7:0] p_i;
  reg p_valid;           // prime result valid flag
  reg p_prime;           // primality result

  // FSM sequential part
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 16'h0000;
      done <= 1'b0;
      S <= 16'h0000;
      n <= 16'h0000;
      happy_cnt <= 8'd0;
      p_n <= 16'h0000;
      p_i <= 8'd0;
      p_valid <= 1'b0;
      p_prime <= 1'b0;
    end else begin
      state <= next_state;
      // Prime micro-FSM only updates in CHECK_PRIME
      p_valid <= 1'b0;
      p_prime <= 1'b0;
      if (state == CHECK_PRIME) begin
        if (p_n <= 16'd1) begin
          p_valid <= 1'b1;
          p_prime <= 1'b0;
        end else if (p_n == 16'd2) begin
          p_valid <= 1'b1;
          p_prime <= 1'b1;
        end else if (p_n[0] == 1'b0) begin // even > 2
          p_valid <= 1'b1;
          p_prime <= 1'b0;
        end else begin
          p_i <= p_i + 8'd1;
          if (p_i * p_i > p_n) begin
            p_valid <= 1'b1;
            p_prime <= 1'b1;
          end else if (p_n % p_i == 16'd0) begin
            p_valid <= 1'b1;
            p_prime <= 1'b0;
          end
        end
      end
      // Other signals updated in next_state logic via blocking assigns
    end
  end

  // Next-state and output logic
  always @(*) begin
    // Default next state
    next_state = state;

    // Update signals default (will be overridden in states)
    S = S;
    n = n;
    happy_cnt = happy_cnt;
    result = result;
    done = done;

    case (state)
      IDLE: begin
        done = 1'b0;
        result = 16'h0000;
        if (start) begin
          S = 16'd1;
          n = 16'd1;
          happy_cnt = 8'd0;
          next_state = CHECK_S;
        end
      end

      CHECK_S: begin
        if (S > 16'd65535) begin
          // Not found within range
          result = 16'hFFFF; // -1 in 16-bit two's complement
          done = 1'b1;
          next_state = DONE;
        end else begin
          n = S;
          happy_cnt = 8'd0;
          next_state = CHECK_NUM;
        end
      end

      CHECK_NUM: begin
        // Check if current n is happy
        if (n <= M) begin
          // Happy by threshold
          happy_cnt = happy_cnt + 8'd1;
          // Decide if we can stop early
          if (happy_cnt == L) begin
            result = S;
            done = 1'b1;
            next_state = DONE;
          end else begin
            // Move to next number or finalize window
            if (n == S + K - 1) begin
              // End of window
              next_state = UPDATE;
            end else begin
              n = n + 16'd1;
              next_state = CHECK_NUM;
            end
          end
        end else begin
          // Must check primality for n > M
          p_n = n;
          p_i = 8'd2;
          // Stay in CHECK_PRIME for at least one cycle
          next_state = CHECK_PRIME;
        end
      end

      CHECK_PRIME: begin
        if (p_valid) begin
          if (p_prime) begin
            happy_cnt = happy_cnt + 8'd1;
          end
          // Early exit check
          if (happy_cnt == L) begin
            result = S;
            done = 1'b1;
            next_state = DONE;
          end else begin
            // Move to next number or finalize window
            if (n == S + K - 1) begin
              next_state = UPDATE;
            end else begin
              n = n + 16'd1;
              next_state = CHECK_NUM;
            end
          end
        end else begin
          // Continue trial division
          next_state = CHECK_PRIME;
        end
      end

      UPDATE: begin
        if (happy_cnt == L) begin
          result = S;
          done = 1'b1;
          next_state = DONE;
        end else begin
          // Try next start number
          S = S + 16'd1;
          next_state = CHECK_S;
        end
      end

      DONE: begin
        result = result;
        done = 1'b1;
        if (start) begin
          // Restart if requested while done
          S = 16'd1;
          n = 16'd1;
          happy_cnt = 8'd0;
          next_state = CHECK_S;
        end
        // else remain in DONE until next start
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
