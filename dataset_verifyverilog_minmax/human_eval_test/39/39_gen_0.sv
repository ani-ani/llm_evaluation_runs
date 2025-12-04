module prime_fib(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [2:0] n,
  output reg [14:0] result,
  output reg done
);

  // State machine states
  localparam IDLE_S = 3'd0;
  localparam GENERATE_S = 3'd1;
  localparam CHECK_PRIME_S = 3'd2;
  localparam EVALUATE_S = 3'd3;
  localparam DONE_S = 3'd4;

  // Internal variables
  reg [2:0] state;
  reg [14:0] fib_curr, fib_prev, fib_next;
  reg [3:0] prime_count;
  reg [7:0] divisor;
  reg is_prime;
  reg prime_check_done;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE_S;
      result <= 15'd0;
      done <= 1'b0;
      fib_curr <= 15'd0;
      fib_prev <= 15'd0;
      fib_next <= 15'd0;
      prime_count <= 4'd0;
      divisor <= 8'd0;
      is_prime <= 1'b0;
      prime_check_done <= 1'b0;
    end else begin
      case (state)
        IDLE_S: begin
          if (start) begin
            state <= GENERATE_S;
            fib_prev <= 15'd1;  // F(2) = 1
            fib_curr <= 15'd2;  // F(3) = 2
            prime_count <= 4'd0;
            divisor <= 8'd0;
            is_prime <= 1'b0;
            prime_check_done <= 1'b0;
          end
        end

        GENERATE_S: begin
          // Initialize for first Fibonacci number
          state <= CHECK_PRIME_S;
          divisor <= 8'd2;  // Start divisor from 2
          prime_check_done <= 1'b0;
        end

        CHECK_PRIME_S: begin
          if (!prime_check_done) begin
            if (divisor == 8'd2) begin
              if (fib_curr <= 15'd2) begin
                is_prime <= 1'b1;
                prime_check_done <= 1'b1;
              end else if (fib_curr % 2 == 0) begin
                is_prime <= 1'b0;
                prime_check_done <= 1'b1;
              end else begin
                divisor <= 8'd3;  // Move to next odd divisor
              end
            end else begin
              if (divisor * divisor > fib_curr) begin
                is_prime <= 1'b1;
                prime_check_done <= 1'b1;
              end else if (fib_curr % divisor == 0) begin
                is_prime <= 1'b0;
                prime_check_done <= 1'b1;
              end else begin
                divisor <= divisor + 8'd2;  // Increment by 2 for next odd divisor
              end
            end
          end else begin
            state <= EVALUATE_S;
          end
        end

        EVALUATE_S: begin
          if (is_prime) begin
            prime_count <= prime_count + 1;
            if (prime_count == n - 1) begin
              result <= fib_curr;
              done <= 1'b1;
              state <= DONE_S;
            end else begin
              // Generate next Fibonacci number
              fib_next <= fib_prev + fib_curr;
              fib_prev <= fib_curr;
              fib_curr <= fib_next;
              divisor <= 8'd2;  // Reset divisor for next prime check
              prime_check_done <= 1'b0;
              is_prime <= 1'b0;
              state <= CHECK_PRIME_S;
            end
          end else begin
            // Not prime, generate next Fibonacci number
            fib_next <= fib_prev + fib_curr;
            fib_prev <= fib_curr;
            fib_curr <= fib_next;
            divisor <= 8'd2;
            prime_check_done <= 1'b0;
            is_prime <= 1'b0;
            state <= CHECK_PRIME_S;
          end
        end

        DONE_S: begin
          if (start) begin
            // New start, reinitialize
            state <= GENERATE_S;
            fib_prev <= 15'd1;
            fib_curr <= 15'd2;
            prime_count <= 4'd0;
            divisor <= 8'd0;
            prime_check_done <= 1'b0;
            is_prime <= 1'b0;
            done <= 1'b0;
          end
          // else, stay in DONE_S with done=1
        end

        default: state <= IDLE_S;
      endcase
    end
  end

endmodule