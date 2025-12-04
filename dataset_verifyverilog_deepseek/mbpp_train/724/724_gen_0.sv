module power_digit_sum (
  input clk,
  input rst_n,
  input start,
  input [3:0] base,
  input [3:0] power,
  output reg [7:0] digit_sum,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE,
    MULTIPLY,
    PREPARE_DOUBLE_DABBLE,
    DOUBLE_DABBLE,
    SUM_DIGITS,
    DONE
  } state_t;

  reg [63:0] product_reg;
  reg [3:0] exp_counter;
  reg [135:0] bin_bcd;
  reg [6:0] shift_counter;
  state_t state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      digit_sum <= 0;
      product_reg <= 0;
      exp_counter <= 0;
      bin_bcd <= 0;
      shift_counter <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            if (power == 0) begin
              product_reg <= 64'd1;
              state <= PREPARE_DOUBLE_DABBLE;
            end
            else begin
              product_reg <= base;
              exp_counter <= power - 4'd1;
              state <= MULTIPLY;
            end
          end
        end

        MULTIPLY: begin
          if (exp_counter > 0) begin
            product_reg <= product_reg * base;
            exp_counter <= exp_counter - 4'd1;
          end
          if (exp_counter == 0) begin
            state <= PREPARE_DOUBLE_DABBLE;
          end
        end

        PREPARE_DOUBLE_DABBLE: begin
          bin_bcd <= {72'b0, product_reg};
          shift_counter <= 7'd64;
          state <= DOUBLE_DABBLE;
        end

        DOUBLE_DABBLE: begin
          if (shift_counter > 0) begin
            reg [135:0] adjusted_bcd;
            adjusted_bcd = bin_bcd;
            for (int i=0; i<18; i++) begin
              if (adjusted_bcd[135 - (4*i) -:4] >= 5)
                adjusted_bcd[135 - (4*i) -:4] += 3;
            end
            bin_bcd <= adjusted_bcd << 1;
            shift_counter <= shift_counter - 7'd1;
          end
          else begin
            state <= SUM_DIGITS;
          end
        end

        SUM_DIGITS: begin
          digit_sum <= 0;
          for (int i=0; i<18; i++)
            digit_sum += bin_bcd[135 - (4*i) -:4];
          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          if (!start)
            state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule