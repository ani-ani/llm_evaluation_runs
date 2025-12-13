module age_base_finder(
  input clk,
  input rst_n,
  input start,
  input [15:0] y,
  input [15:0] l,
  output reg [15:0] b,
  output reg done
);

  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_INIT   = 3'd1,
    S_DIVIDE = 3'd2,
    S_CHECK  = 3'd3,
    S_NEXT_B = 3'd4,
    S_DONE   = 3'd5
  } state_t;

  state_t state, next_state;

  reg [15:0] current_b;
  reg [15:0] initial_b;

  reg [15:0] y_reg;
  reg [15:0] l_reg;

  reg [15:0] work_y;
  reg [15:0] divisor;

  reg [15:0] dividend_reg;
  reg [15:0] divisor_reg;
  reg [15:0] quotient_reg;
  reg [15:0] remainder_reg;
  reg [4:0]  div_bit_idx;
  reg        div_busy;
  reg        div_start;

  reg [3:0] digits [0:15];
  reg [4:0] digit_cnt;
  reg       invalid_digit;

  reg [15:0] value10;

  reg        solution_found;

  integer i;

  // Synchronous state and main registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= S_IDLE;
      b               <= 16'd0;
      done            <= 1'b0;
      current_b       <= 16'd0;
      initial_b       <= 16'd0;
      y_reg           <= 16'd0;
      l_reg           <= 16'd0;
      work_y          <= 16'd0;
      divisor         <= 16'd0;
      dividend_reg    <= 16'd0;
      divisor_reg     <= 16'd0;
      quotient_reg    <= 16'd0;
      remainder_reg   <= 16'd0;
      div_bit_idx     <= 5'd0;
      div_busy        <= 1'b0;
      div_start       <= 1'b0;
      digit_cnt       <= 5'd0;
      invalid_digit   <= 1'b0;
      value10         <= 16'd0;
      solution_found  <= 1'b0;
      for (i = 0; i < 16; i = i + 1) begin
        digits[i] <= 4'd0;
      end
    end else begin
      state <= next_state;

      // default strobes
      div_start <= 1'b0;

      case (state)
        S_IDLE: begin
          done           <= 1'b0;
          solution_found <= 1'b0;
          b              <= 16'd0;
          if (start) begin
            y_reg <= y;
            l_reg <= l;
          end
        end

        S_INIT: begin
          // compute initial_b = (y_reg < 256) ? y_reg : 256
          if (y_reg < 16'd256)
            initial_b <= y_reg;
          else
            initial_b <= 16'd256;

          current_b      <= (y_reg < 16'd256) ? y_reg : 16'd256;
          solution_found <= 1'b0;
        end

        S_DIVIDE: begin
          // Division / digit extraction and base-10 accumulation
          if (!div_busy && (work_y != 16'd0) && !invalid_digit) begin
            // start a new division step: work_y / current_b
            dividend_reg  <= work_y;
            divisor_reg   <= divisor;
            quotient_reg  <= 16'd0;
            remainder_reg <= 16'd0;
            div_bit_idx   <= 5'd15;
            div_busy      <= 1'b1;
            div_start     <= 1'b1;
          end else if (div_busy) begin
            // iterative restoring division
            // process bit div_bit_idx
            // shift left remainder and bring next bit from dividend
            remainder_reg <= {remainder_reg[14:0], dividend_reg[div_bit_idx]};
            if ({remainder_reg[14:0], dividend_reg[div_bit_idx]} >= divisor_reg) begin
              remainder_reg <= {remainder_reg[14:0], dividend_reg[div_bit_idx]} - divisor_reg;
              quotient_reg[div_bit_idx] <= 1'b1;
            end else begin
              quotient_reg[div_bit_idx] <= 1'b0;
            end

            if (div_bit_idx == 5'd0) begin
              // division complete this cycle
              div_busy <= 1'b0;
              // use quotient_reg, remainder_reg

              // remainder is digit
              if (remainder_reg > 16'd9) begin
                invalid_digit <= 1'b1;
              end else begin
                digits[digit_cnt] <= remainder_reg[3:0];
                // value10 = value10 * 10 + remainder
                value10 <= (value10 * 16'd10) + remainder_reg;
                digit_cnt <= digit_cnt + 5'd1;
              end

              // prepare for possible next loop
              work_y <= quotient_reg;
            end else begin
              div_bit_idx <= div_bit_idx - 5'd1;
            end
          end
        end

        S_CHECK: begin
          if (!invalid_digit) begin
            if (value10 >= l_reg) begin
              solution_found <= 1'b1;
              b              <= current_b;
            end
          end
        end

        S_NEXT_B: begin
          if (solution_found) begin
            done <= 1'b1;
          end else begin
            if (current_b > 16'd2) begin
              current_b <= current_b - 16'd1;
            end else begin
              // No valid base found: keep b=0, done will be set in S_DONE
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: ;
      endcase

      // State-entry specific initializations driven by next_state
      if (next_state == S_DIVIDE && state != S_DIVIDE) begin
        // initialize per-base digit extraction
        work_y        <= y_reg;
        divisor       <= current_b;
        digit_cnt     <= 5'd0;
        invalid_digit <= 1'b0;
        value10       <= 16'd0;
        div_busy      <= 1'b0;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_DIVIDE;
      end

      S_DIVIDE: begin
        // Wait until digits for this base fully processed or invalid
        if (!div_busy) begin
          if (invalid_digit) begin
            next_state = S_NEXT_B;
          end else if (work_y == 16'd0) begin
            // finished decomposition for this base
            next_state = S_CHECK;
          end else begin
            // more digits to compute: stay in S_DIVIDE (will restart div)
            next_state = S_DIVIDE;
          end
        end else begin
          next_state = S_DIVIDE;
        end
      end

      S_CHECK: begin
        next_state = S_NEXT_B;
      end

      S_NEXT_B: begin
        if (solution_found) begin
          next_state = S_DONE;
        end else begin
          if (current_b > 16'd2)
            next_state = S_DIVIDE;
          else
            next_state = S_DONE;
        end
      end

      S_DONE: begin
        if (!start)
          next_state = S_IDLE;
        else
          next_state = S_DONE;
      end

      default: next_state = S_IDLE;
    endcase
  end

endmodule