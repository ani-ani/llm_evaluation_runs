module mirko_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] K,
  input [7:0] L,
  input [7:0] M,
  output reg [15:0] result,
  output reg done
);

  // States
  typedef enum logic [3:0] {
    IDLE,
    PRIME_CHECK,
    COUNT_HAPPY,
    INCREMENT,
    FOUND
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [15:0] x;
  reg [7:0] count;
  reg [15:0] current_num;
  reg [7:0] divisor;
  reg is_prime;
  reg [15:0] max_x = 2000;

  // Primality check for numbers up to 2150
  function automatic logic is_prime_func(input [15:0] num);
    if (num <= 1) return 0;
    if (num <= 3) return 1;
    if (num % 2 == 0 || num % 3 == 0) return 0;
    for (int i = 5; i * i <= num; i = i + 6) begin
      if (num % i == 0 || num % (i + 2) == 0) return 0;
    end
    return 1;
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      x <= 0;
      count <= 0;
      current_num <= 0;
      divisor <= 0;
      is_prime <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            x <= 1;
            count <= 0;
            current_num <= x;
            next_state <= PRIME_CHECK;
          end
        end

        PRIME_CHECK: begin
          is_prime <= is_prime_func(current_num);
          next_state <= COUNT_HAPPY;
        end

        COUNT_HAPPY: begin
          if ((current_num <= M) || is_prime) begin
            count <= count + 1;
          end
          if (current_num == x + K - 1) begin
            if (count == L) begin
              result <= x;
              next_state <= FOUND;
            end else begin
              x <= x + 1;
              if (x > max_x) begin
                result <= -1;
                next_state <= FOUND;
              end else begin
                current_num <= x;
                count <= 0;
                next_state <= PRIME_CHECK;
              end
            end
          end else begin
            current_num <= current_num + 1;
            next_state <= PRIME_CHECK;
          end
        end

        INCREMENT: begin
          x <= x + 1;
          if (x > max_x) begin
            result <= -1;
            next_state <= FOUND;
          end else begin
            current_num <= x;
            count <= 0;
            next_state <= PRIME_CHECK;
          end
        end

        FOUND: begin
          done <= 1;
          next_state <= IDLE;
        end

        default: next_state <= IDLE;
      endcase
    end
  end

  // Default state transitions
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: next_state = start ? PRIME_CHECK : IDLE;
      PRIME_CHECK: next_state = COUNT_HAPPY;
      COUNT_HAPPY: next_state = (current_num == x + K - 1) ? (count == L ? FOUND : INCREMENT) : PRIME_CHECK;
      INCREMENT: next_state = (x > max_x) ? FOUND : PRIME_CHECK;
      FOUND: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

endmodule