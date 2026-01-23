module largest_prime_factor (
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    INIT_FACTORS,
    CHECK_PRIME,
    UPDATE_LARGEST,
    DONE
  } state_t;

  state_t state, next_state;

  // Registers
  reg [15:0] n_reg;
  reg [7:0] divisor;
  reg [15:0] largest;
  reg [15:0] temp;
  reg [7:0] prime_check_counter;
  reg prime_check_flag;
  reg [15:0] sqrt_n;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      n_reg <= 0;
      divisor <= 0;
      largest <= 0;
      temp <= 0;
      prime_check_counter <= 0;
      prime_check_flag <= 0;
      result <= 0;
      done <= 0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (start) begin
            n_reg <= n;
            divisor <= 2;
            largest <= 1;
            temp <= 0;
            prime_check_counter <= 0;
            prime_check_flag <= 0;
          end
        end

        INIT_FACTORS: begin
          n_reg <= n;
          divisor <= 2;
          largest <= 1;
          temp <= 0;
          prime_check_counter <= 0;
          prime_check_flag <= 0;
        end

        CHECK_PRIME: begin
          // Primality check logic
          if (prime_check_counter == 0) begin
            prime_check_flag <= 1;
            prime_check_counter <= 2;
          end else if (prime_check_counter < divisor) begin
            if (divisor % prime_check_counter == 0) begin
              prime_check_flag <= 0;
              prime_check_counter <= divisor;
            end else begin
              prime_check_counter <= prime_check_counter + 1;
            end
          end
        end

        UPDATE_LARGEST: begin
          if (prime_check_flag && (n_reg % divisor == 0)) begin
            largest <= divisor;
            n_reg <= n_reg / divisor;
          end
          divisor <= divisor + 1;
        end

        DONE: begin
          result <= largest;
          done <= 1;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT_FACTORS;
      end

      INIT_FACTORS: begin
        next_state = CHECK_PRIME;
      end

      CHECK_PRIME: begin
        if (prime_check_counter >= divisor) begin
          next_state = UPDATE_LARGEST;
        end
      end

      UPDATE_LARGEST: begin
        sqrt_n = divisor * divisor;
        if (sqrt_n > n_reg || divisor > 255) begin
          next_state = DONE;
        end else begin
          next_state = CHECK_PRIME;
        end
      end

      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

endmodule