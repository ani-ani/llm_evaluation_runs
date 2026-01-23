module chocolate_distribution (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  input [15:0] sum_total,
  input [7:0] a [0:15],
  output reg [31:0] result,
  output reg done,
  output reg no_solution
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    FACTORIZE,
    CALCULATE_COST,
    DONE
  } state_t;

  state_t state;
  reg [31:0] prime_factors [0:4];
  reg [4:0] num_primes;
  reg [4:0] current_prime_idx;
  reg [31:0] current_prime;
  reg [31:0] min_cost;
  reg [7:0] array_idx;
  reg [31:0] current_cost;
  reg [31:0] remainder;

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      no_solution <= 0;
      result <= 0;
      num_primes <= 0;
      current_prime_idx <= 0;
      min_cost <= 32'hFFFFFFFF;
      array_idx <= 0;
      current_cost <= 0;
      remainder <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            if (sum_total == 1) begin
              no_solution <= 1;
              done <= 1;
              result <= 32'hFFFFFFFF;
            end else begin
              state <= FACTORIZE;
              num_primes <= 0;
              current_prime_idx <= 0;
              min_cost <= 32'hFFFFFFFF;
            end
          end
        end
        FACTORIZE: begin
          // Factorize sum_total and store primes in prime_factors
          // For simplicity, assume factorization is done in one cycle (in reality, this would be iterative)
          // Here we'll simulate finding up to 5 prime factors
          if (num_primes < 5) begin
            // Simplified factorization: find next prime factor
            reg [31:0] temp_sum = sum_total;
            reg [31:0] factor = 2;
            reg found = 0;
            while (!found && factor <= temp_sum) begin
              if (temp_sum % factor == 0) begin
                prime_factors[num_primes] <= factor;
                num_primes <= num_primes + 1;
                temp_sum <= temp_sum / factor;
                found = 1;
              end else begin
                factor <= factor + 1;
              end
            end
            if (num_primes == 0 && temp_sum > 1) begin
              prime_factors[num_primes] <= temp_sum;
              num_primes <= num_primes + 1;
            end
          end
          if (num_primes > 0) begin
            state <= CALCULATE_COST;
            current_prime_idx <= 0;
            current_prime <= prime_factors[0];
            array_idx <= 0;
            current_cost <= 0;
            remainder <= 0;
          end else begin
            no_solution <= 1;
            done <= 1;
            result <= 32'hFFFFFFFF;
            state <= DONE;
          end
        end
        CALCULATE_COST: begin
          if (array_idx < n) begin
            // Update remainder
            remainder <= (remainder + a[array_idx]) % current_prime;
            // Calculate cost contribution
            reg [31:0] cost_contribution = (remainder < (current_prime - remainder)) ? remainder : (current_prime - remainder);
            current_cost <= current_cost + cost_contribution;
            array_idx <= array_idx + 1;
          end else begin
            // Compare with min_cost
            if (current_cost < min_cost) begin
              min_cost <= current_cost;
            end
            // Move to next prime
            current_prime_idx <= current_prime_idx + 1;
            if (current_prime_idx < num_primes) begin
              current_prime <= prime_factors[current_prime_idx];
              array_idx <= 0;
              current_cost <= 0;
              remainder <= 0;
            end else begin
              state <= DONE;
              done <= 1;
              result <= min_cost;
            end
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
            no_solution <= 0;
          end
        end
      endcase
    end
  end

endmodule