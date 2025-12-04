module prime_checker(
  input clk,
  input rst_n,
  input start,
  input [7:0] num,
  output reg is_prime,
  output reg done
);

  typedef enum logic [1:0] {IDLE = 2'b00, CHECKING = 2'b01, DONE = 2'b10} state_t;
  state_t state, next_state;

  reg [7:0] n;         // captured input value to test
  reg [7:0] divisor;   // current divisor being tested
  reg [7:0] max_div;   // floor(sqrt(n)) computed when n is captured
  reg is_prime_d;      // holds primality result while CHECKING

  // Update state and outputs (reset forces outputs to 0)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      is_prime <= 1'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      is_prime <= is_prime_d;
      done <= done;
    end
  end

  // Next-state logic
  always_comb begin
    // Default values to avoid latches
    next_state = state;
    is_prime_d = 1'b0;
    done = 1'b0;
    n = 8'd0;
    divisor = 8'd0;
    max_div = 8'd0;

    case (state)
      IDLE: begin
        if (start) begin
          n = num;
          if (n < 8'd2) begin
            is_prime_d = 1'b0;
            done = 1'b1;
            next_state = DONE;
          end else begin
            max_div = 8'd1;
            // Compute floor(sqrt(n)) by counting up
            for (int k = 8'd2; k * k <= n; k++) begin
              max_div = k;
            end
            divisor = 8'd2;
            is_prime_d = 1'b1; // assume prime until a divisor is found
            next_state = CHECKING;
          end
        end else begin
          next_state = IDLE;
        end
      end

      CHECKING: begin
        n = n;            // hold captured value
        max_div = max_div;
        is_prime_d = is_prime_d;
        divisor = divisor;

        if (divisor > max_div) begin
          done = 1'b1;
          next_state = DONE;
        end else begin
          if (n == divisor) begin
            // n is 2: prime
            is_prime_d = 1'b1;
            done = 1'b1;
            next_state = DONE;
          end else if ((divisor != 0) && (n % divisor == 0)) begin
            is_prime_d = 1'b0;
            done = 1'b1;
            next_state = DONE;
          end else begin
            divisor = divisor + 1;
            next_state = CHECKING;
          end
        end
      end

      DONE: begin
        done = 1'b1;
        if (start) begin
          // Start a new test in the same cycle if start is held
          n = num;
          if (n < 8'd2) begin
            is_prime_d = 1'b0;
            done = 1'b1;
            next_state = DONE;
          end else begin
            max_div = 8'd1;
            for (int k = 8'd2; k * k <= n; k++) begin
              max_div = k;
            end
            divisor = 8'd2;
            is_prime_d = 1'b1;
            next_state = CHECKING;
          end
        end else begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
