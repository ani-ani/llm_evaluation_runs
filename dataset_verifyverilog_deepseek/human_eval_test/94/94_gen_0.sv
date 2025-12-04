module largest_prime_digit_sum(
  input clk,
  input rst_n,
  input start,
  input [511:0] lst_packed,
  output reg [4:0] digit_sum,
  output reg done
);

  typedef enum logic [3:0] {
    IDLE,
    INIT,
    LOAD_ELEMENT,
    EVALUATE_ELEMENT,
    CHECK_PRIME_LOOP,
    CHECK_PRIME_NEXT,
    HANDLE_PRIME,
    CALC_DIGIT_SUM,
    DONE
  } state_t;

  state_t state;
  reg [15:0] max_prime_reg;
  reg [4:0] index;
  reg [15:0] current_element;
  reg [7:0] divisor;
  reg is_prime_flag;
  reg has_prime_flag;

  wire [15:0] divisor_squared = divisor * divisor;
  wire [15:0] remainder = current_element % divisor;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      digit_sum <= 0;
      max_prime_reg <= 0;
      index <= 0;
      current_element <= 0;
      divisor <= 0;
      is_prime_flag <= 0;
      has_prime_flag <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          digit_sum <= 0;
          if (start) state <= INIT;
        end
        INIT: begin
          max_prime_reg <= 0;
          has_prime_flag <= 0;
          index <= 0;
          state <= LOAD_ELEMENT;
        end
        LOAD_ELEMENT: begin
          current_element <= lst_packed[index*16 +: 16];
          state <= EVALUATE_ELEMENT;
        end
        EVALUATE_ELEMENT: begin
          if (current_element <= 1) begin
            is_prime_flag <= 0;
            state <= HANDLE_PRIME;
          end else begin
            divisor <= 2;
            is_prime_flag <= 1;
            state <= CHECK_PRIME_LOOP;
          end
        end
        CHECK_PRIME_LOOP: begin
          if (divisor_squared > current_element) begin
            state <= HANDLE_PRIME;
          end else if (remainder == 0) begin
            is_prime_flag <= 0;
            state <= HANDLE_PRIME;
          end else begin
            state <= CHECK_PRIME_NEXT;
          end
        end
        CHECK_PRIME_NEXT: begin
          divisor <= divisor + 1;
          state <= CHECK_PRIME_LOOP;
        end
        HANDLE_PRIME: begin
          if (is_prime_flag == 1'b1) begin
            if (current_element > max_prime_reg) begin
              max_prime_reg <= current_element;
              has_prime_flag <= 1;
            end
          end
          if (index == 5'd31) begin
            state <= CALC_DIGIT_SUM;
          end else begin
            index <= index + 1;
            state <= LOAD_ELEMENT;
          end
        end
        CALC_DIGIT_SUM: begin
          if (has_prime_flag) begin
            digit_sum <= (max_prime_reg / 10000) % 10 +
                         (max_prime_reg / 1000) % 10 +
                         (max_prime_reg / 100) % 10 +
                         (max_prime_reg / 10) % 10 +
                         max_prime_reg % 10;
          end else begin
            digit_sum <= 0;
          end
          state <= DONE;
        end
        DONE: begin
          done <= 1;
          if (start) state <= INIT;
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule