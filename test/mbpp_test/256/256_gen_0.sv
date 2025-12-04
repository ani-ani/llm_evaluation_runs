module count_primes(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] n,
  output reg [7:0] count,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE         = 3'd0,
    CHECK_NUM    = 3'd1,
    CHECK_DIV    = 3'd2,
    UPDATE_COUNT = 3'd3,
    DONE         = 3'd4
  } state_t;

  state_t state, next_state;

  reg [7:0] current_num;
  reg [4:0] current_div;      // supports divisors up to 31, we use up to 15
  reg       is_composite;     // flag to indicate current_num is not prime

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      count        <= 8'd0;
      done         <= 1'b0;
      current_num  <= 8'd0;
      current_div  <= 5'd0;
      is_composite <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            count        <= 8'd0;
            current_num  <= 8'd2;     // start checking from 2
            current_div  <= 5'd2;
            is_composite <= 1'b0;
          end
        end

        CHECK_NUM: begin
          // Prepare to check divisors for current_num
          is_composite <= 1'b0;
          current_div  <= 5'd2;
        end

        CHECK_DIV: begin
          // Only check divisors less than current_num and up to 15
          if ((current_div < current_num) && (current_div <= 5'd15)) begin
            if (current_num % current_div == 0) begin
              is_composite <= 1'b1;   // found divisor, not prime
            end
            current_div <= current_div + 5'd1;
          end
        end

        UPDATE_COUNT: begin
          // If not composite and current_num >= 2, it's prime
          if (!is_composite && (current_num >= 8'd2)) begin
            count <= count + 8'd1;
          end
          // Move to next number
          current_num <= current_num + 8'd1;
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
          // Should not occur; safe reset behavior
          state <= IDLE;
        end
      endcase
    end
  end

  // Combinational next state logic
  always @* begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start) begin
          // If n <= 2, there are no primes < n; go straight to DONE
          if (n <= 8'd2)
            next_state = DONE;
          else
            next_state = CHECK_NUM;
        end
      end

      CHECK_NUM: begin
        // If current_num already reached n, we are done
        if (current_num >= n)
          next_state = DONE;
        else
          next_state = CHECK_DIV;
      end

      CHECK_DIV: begin
        // Stop divisor checking when:
        // 1) divisor reached 16 (past 15), or
        // 2) divisor is no longer less than current_num,
        // or we keep iterating otherwise.
        if ((current_div >= 5'd16) || (current_div >= current_num)) begin
          next_state = UPDATE_COUNT;
        end else begin
          next_state = CHECK_DIV; // continue checking next divisor
        end
      end

      UPDATE_COUNT: begin
        // After updating count and current_num, either done or next number
        if ((current_num + 8'd1) >= n)
          next_state = DONE;
        else
          next_state = CHECK_NUM;
      end

      DONE: begin
        // Stay in DONE until start is deasserted and reasserted (new operation)
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule