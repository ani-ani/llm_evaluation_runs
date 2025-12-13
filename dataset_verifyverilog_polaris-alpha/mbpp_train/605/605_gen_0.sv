module prime_checker(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] num,
  output reg is_prime,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE     = 2'b00,
    CHECKING = 2'b01,
    DONE     = 2'b10
  } state_t;

  state_t state, next_state;

  reg [7:0] num_reg;
  reg [3:0] divisor;   // 2..15 (sqrt(255) < 16)
  reg       prime_flag;

  // Sequential logic: state, registers, outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      num_reg    <= 8'd0;
      divisor    <= 4'd0;
      prime_flag <= 1'b0;
      is_prime   <= 1'b0;
      done       <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            num_reg <= num;
            if (num < 8'd2) begin
              // Not prime
              is_prime   <= 1'b0;
              done       <= 1'b1;
              prime_flag <= 1'b0;
              divisor    <= 4'd0;
            end else if (num == 8'd2) begin
              // 2 is prime
              is_prime   <= 1'b1;
              done       <= 1'b1;
              prime_flag <= 1'b1;
              divisor    <= 4'd0;
            end else begin
              // Initialize for checking
              divisor    <= 4'd2;
              prime_flag <= 1'b1; // assume prime until a divisor is found
              is_prime   <= 1'b0;
              // done cleared above
            end
          end
        end

        CHECKING: begin
          done <= 1'b0;
          // Check current divisor if still potentially prime
          if (prime_flag) begin
            if ((num_reg % divisor) == 8'd0) begin
              prime_flag <= 1'b0; // found a divisor
            end
          end

          // Increment divisor for next cycle
          divisor <= divisor + 4'd1;
        end

        DONE: begin
          done     <= 1'b1;
          is_prime <= prime_flag;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          if (num < 8'd2 || num == 8'd2) begin
            next_state = DONE;
          end else begin
            next_state = CHECKING;
          end
        end
      end

      CHECKING: begin
        // Stop when divisor exceeds sqrt(num_reg) or known not prime
        // Use divisor*divisor > num_reg as termination condition
        if (!prime_flag) begin
          // Non-prime found
          next_state = DONE;
        end else if ((divisor * divisor) > num_reg) begin
          // No divisor found up to sqrt(num_reg): prime
          next_state = DONE;
        end else begin
          next_state = CHECKING;
        end
      end

      DONE: begin
        // Wait for start to deassert then be asserted again for new check
        if (!start)
          next_state = IDLE;
        else
          next_state = DONE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule