module armstrong_checker(input clk, rst_n, start, [15:0] number, output reg result, output reg done);

  typedef enum logic [2:0] {IDLE, COUNT_DIGITS, CALC_POWER, COMPARE} state_t;
  state_t current_state, next_state;

  reg [15:0] original_num;
  reg [3:0] digits[0:3];
  reg [2:0] digit_count;
  reg [1:0] digit_index;
  reg [15:0] temp_num;
  reg [15:0] sum;
  reg [15:0] power_temp;
  reg [1:0] multiply_counter;
  reg [3:0] current_digit_reg;

  wire [1:0] required_mults = (digit_count == 3'd1) ? 2'd0 :
                              (digit_count == 3'd2) ? 2'd1 : 2'd2;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      original_num <= 16'd0;
      foreach(digits[i]) digits[i] <= 4'd0;
      digit_count <= 3'd0;
      digit_index <= 2'd0;
      temp_num <= 16'd0;
      sum <= 16'd0;
      power_temp <= 16'd0;
      multiply_counter <= 2'd0;
      current_digit_reg <= 4'd0;
      done <= 1'b0;
      result <= 1'b0;
    end else begin
      done <= 1'b0;

      case (current_state)
        IDLE: begin
          if (start) begin
            original_num <= number;
            temp_num <= number;
            digit_count <= 3'd0;
            sum <= 16'd0;
            current_state <= COUNT_DIGITS;
          end
        end

        COUNT_DIGITS: begin
          if (temp_num != 16'd0) begin
            digits[digit_count] <= temp_num % 10;
            temp_num <= temp_num / 10;
            digit_count <= digit_count + 3'd1;
          end else begin
            digit_index <= 2'd0;
            current_digit_reg <= digits[0];
            power_temp <= digits[0];
            multiply_counter <= 2'd0;
            current_state <= CALC_POWER;
          end
        end

        CALC_POWER: begin
          if (multiply_counter < required_mults) begin
            power_temp <= power_temp * current_digit_reg;
            multiply_counter <= multiply_counter + 2'd1;
          end else begin
            sum <= sum + power_temp;
            if (digit_index == (digit_count - 3'd1)) begin
              current_state <= COMPARE;
            end else begin
              digit_index <= digit_index + 2'd1;
              current_digit_reg <= digits[digit_index + 2'd1];
              power_temp <= digits[digit_index + 2'd1];
              multiply_counter <= 2'd0;
            end
          end
        end

        COMPARE: begin
          result <= (sum == original_num);
          done <= 1'b1;
          current_state <= IDLE;
        end
      endcase
    end
  end
endmodule