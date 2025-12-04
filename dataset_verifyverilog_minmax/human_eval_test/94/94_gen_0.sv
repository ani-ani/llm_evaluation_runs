module largest_prime_digit_sum(
  input clk,
  input rst_n,
  input start,
  input [511:0] lst_packed,
  output reg [4:0] digit_sum,
  output reg done
);

  // Internal signals
  reg [4:0] index; // 0 to 31
  reg [15:0] current_element;
  reg [8:0] divisor; // up to 255
  reg [15:0] largest_prime_reg;
  reg found_prime;
  reg [4:0] digit_sum_temp;
  reg [15:0] temp_largest_prime; // not used? We are using largest_prime_reg

  // State machine
  localparam IDLE = 0, SCAN = 1, DIGIT_SUM = 2, DONE = 3;
  reg [1:0] state, next_state;

  // Combinational next_state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = SCAN;
      SCAN: if (index == 31) next_state = DIGIT_SUM;
      DIGIT_SUM: begin
        if (found_prime == 0) 
          next_state = DONE;
        else if (largest_prime_reg == 0) 
          next_state = DONE;
        else 
          next_state = DIGIT_SUM;
      end
      DONE: if (start) next_state = IDLE;
    endcase
  end

  // Sequential block: update state and internal signals
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      index <= 0;
      current_element <= 0;
      divisor <= 2;
      largest_prime_reg <= 0;
      found_prime <= 0;
      digit_sum_temp <= 0;
    end else begin
      state <= next_state;
      done <= (next_state == DONE);

      case (state)
        IDLE: begin
          if (start) begin
            index <= 0;
            current_element <= lst_packed[0*16 +: 16];
            divisor <= 2;
            largest_prime_reg <= 0;
            found_prime <= 0;
            digit_sum_temp <= 0;
          end
        end

        SCAN: begin
          // Prime check
          if (current_element > 1) begin
            if (divisor * divisor > current_element) begin
              // prime
              if (current_element > largest_prime_reg) begin
                largest_prime_reg <= current_element;
              end
              found_prime <= 1;
            end else if (current_element % divisor == 0) begin
              // not prime: do nothing? 
            end else begin
              divisor <= divisor + 1;
            end
          end

          // Set up next element if not done with the list
          if (next_state != DIGIT_SUM) begin
            index <= index + 1;
            current_element <= lst_packed[(index+1)*16 +: 16];
            divisor <= 2;
          end
        end

        DIGIT_SUM: begin
          if (found_prime == 0) begin
            // nothing? 
          end else if (largest_prime_reg == 0) begin
            // nothing? 
          end else begin
            digit_sum_temp <= digit_sum_temp + (largest_prime_reg % 10);
            largest_prime_reg <= largest_prime_reg / 10;
          end
        end

        DONE: begin
          // do nothing
        end
      endcase
    end
  end

  // Update the output digit_sum
  always @(posedge clk) begin
    if (!rst_n) begin
      digit_sum <= 0;
    end else begin
      if (state == DONE) begin
        digit_sum <= digit_sum_temp;
      end
    end
  end

endmodule
