module amicable_sum(
  input  clk,
  input  rst_n,
  input  start,
  input  [15:0] limit,
  output reg [15:0] sum,
  output reg done
);

  // State encoding
  typedef enum logic [3:0] {
    S_IDLE          = 4'd0,
    S_INIT          = 4'd1,
    S_SUM1_START    = 4'd2,
    S_SUM1_DIV      = 4'd3,
    S_SUM1_DONE     = 4'd4,
    S_CHECK_SUM1    = 4'd5,
    S_SUM2_START    = 4'd6,
    S_SUM2_DIV      = 4'd7,
    S_SUM2_DONE     = 4'd8,
    S_CHECK_PAIR    = 4'd9,
    S_NEXT_I        = 4'd10,
    S_DONE          = 4'd11
  } state_t;

  state_t state, next_state;

  reg [15:0] i;              // current number
  reg [15:0] sum1;           // sum of proper divisors of i
  reg [15:0] sum2;           // sum of proper divisors of sum1
  reg [15:0] div;            // divisor counter
  reg [15:0] upper;          // upper bound for divisor search

  // Found pairs bitmap (for numbers up to 2047 supported directly)
  // Each bit indicates if number has been counted in an amicable pair.
  // For simplicity and to satisfy requirement, we provide 2048-bit bitmap.
  // For limit > 2047, bitmap protection is partial (lower indices), but
  // implementation follows the instruction to use a tracking register.
  reg [2047:0] found_pairs;

  // Combinational next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_SUM1_START;
      end

      S_SUM1_START: begin
        if (i > limit)
          next_state = S_DONE;
        else
          next_state = S_SUM1_DIV;
      end

      S_SUM1_DIV: begin
        if (div > upper)
          next_state = S_SUM1_DONE;
        else
          next_state = S_SUM1_DIV;
      end

      S_SUM1_DONE: begin
        next_state = S_CHECK_SUM1;
      end

      S_CHECK_SUM1: begin
        if (sum1 > i)
          next_state = S_SUM2_START;
        else
          next_state = S_NEXT_I;
      end

      S_SUM2_START: begin
        next_state = S_SUM2_DIV;
      end

      S_SUM2_DIV: begin
        if (div > upper)
          next_state = S_SUM2_DONE;
        else
          next_state = S_SUM2_DIV;
      end

      S_SUM2_DONE: begin
        next_state = S_CHECK_PAIR;
      end

      S_CHECK_PAIR: begin
        next_state = S_NEXT_I;
      end

      S_NEXT_I: begin
        if (i > limit)
          next_state = S_DONE;
        else
          next_state = S_SUM1_START;
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

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      sum          <= 16'd0;
      done         <= 1'b0;
      i            <= 16'd0;
      sum1         <= 16'd0;
      sum2         <= 16'd0;
      div          <= 16'd0;
      upper        <= 16'd0;
      found_pairs  <= {2048{1'b0}};
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            sum         <= 16'd0;
            i           <= 16'd2;
            found_pairs <= {2048{1'b0}};
          end
        end

        S_INIT: begin
          // Already initialized in IDLE on start
        end

        // Start computing sum1 for current i
        S_SUM1_START: begin
          sum1  <= 16'd1;                // 1 is always a proper divisor for i>=2
          if (i <= 16'd1)
            sum1 <= 16'd0;
          upper <= i[15:1];              // i/2
          div   <= 16'd2;
        end

        // Accumulate sum1 over divisors 2..i/2
        S_SUM1_DIV: begin
          if (div <= upper) begin
            if (i % div == 16'd0) begin
              sum1 <= sum1 + div;
            end
            div <= div + 16'd1;
          end
        end

        S_SUM1_DONE: begin
          // nothing; transition to check
        end

        // Check if sum1 qualifies to compute sum2
        S_CHECK_SUM1: begin
          // condition checked in next_state logic; no registers changed here
        end

        // Initialize sum2 computation for sum1
        S_SUM2_START: begin
          if (sum1 <= 16'd1) begin
            sum2 <= 16'd0;
            div  <= 16'd0;
            upper <= 16'd0;
          end else begin
            sum2  <= 16'd1;
            upper <= sum1[15:1];         // sum1/2
            div   <= 16'd2;
          end
        end

        // Accumulate sum2 over divisors 2..sum1/2
        S_SUM2_DIV: begin
          if (div <= upper) begin
            if (sum1 % div == 16'd0) begin
              sum2 <= sum2 + div;
            end
            div <= div + 16'd1;
          end
        end

        S_SUM2_DONE: begin
          // nothing; proceed to CHECK_PAIR
        end

        // Validate amicable pair and update sum and found_pairs
        S_CHECK_PAIR: begin
          if ((sum2 == i) && (sum1 <= limit)) begin
            // Use bitmap protection where addressable (0..2047)
            // Only add if neither number was already counted.
            if ((i < 2048) && (sum1 < 2048)) begin
              if (!found_pairs[i] && !found_pairs[sum1]) begin
                sum <= sum + i + sum1; // wrap naturally to 16 bits
                found_pairs[i]    <= 1'b1;
                found_pairs[sum1] <= 1'b1;
              end
            end else begin
              // If out of bitmap range, still add once per detection
              sum <= sum + i + sum1;
            end
          end
        end

        // Move to next i
        S_NEXT_I: begin
          if (i < 16'hFFFF) begin
            i <= i + 16'd1;
          end
        end

        // Signal completion
        S_DONE: begin
          done <= 1'b1;
          // Hold sum stable until next start/reset
        end

        default: begin
        end
      endcase
    end
  end

endmodule