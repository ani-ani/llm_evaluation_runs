module digit_sum_pair_counter(
  input clk,
  input rst_n,
  input start,
  input [15:0] S_in,
  output reg [31:0] count,
  output reg done
);

  // Parameters
  localparam MOD = 32'd1000000007;

  // FSM States
  localparam [2:0]
    IDLE       = 3'd0,
    INIT_L     = 3'd1,
    SUM_DIGITS = 3'd2,
    CHECK_SUM  = 3'd3,
    NEXT_L     = 3'd4,
    FINISH     = 3'd5;

  reg [2:0] state, next_state;

  // Registers
  reg [15:0] S_reg;
  reg [31:0] l;
  reg [31:0] r;
  reg [31:0] sum;

  // Digit count function using comparators (ceil(log10(x)))
  function automatic [4:0] digit_count;
    input [31:0] x;
    begin
      if (x == 0)
        digit_count = 1;
      else if (x < 10)
        digit_count = 1;
      else if (x < 100)
        digit_count = 2;
      else if (x < 1000)
        digit_count = 3;
      else if (x < 10000)
        digit_count = 4;
      else if (x < 100000)
        digit_count = 5;
      else if (x < 1000000)
        digit_count = 6;
      else if (x < 10000000)
        digit_count = 7;
      else if (x < 100000000)
        digit_count = 8;
      else if (x < 1000000000)
        digit_count = 9;
      else
        digit_count = 10;
    end
  endfunction

  // FSM Sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      S_reg <= 16'd0;
      l <= 32'd0;
      r <= 32'd0;
      sum <= 32'd0;
      count <= 32'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            S_reg <= S_in;
            count <= 32'd0;
          end
        end

        INIT_L: begin
          // Initialize l, r, and sum for new l
          l <= 32'd1;
          r <= 32'd1;
          sum <= digit_count(32'd1);
        end

        SUM_DIGITS: begin
          // Accumulate digit counts by advancing r until sum >= S_reg or r > 2*S_reg
          if ((sum < S_reg) && (r < (S_reg << 1))) begin
            r <= r + 32'd1;
            sum <= sum + digit_count(r + 32'd1 - 32'd1); // corrected below in next always block style
          end
        end

        CHECK_SUM: begin
          // If sum matches S_reg, record pair
          if (sum == S_reg) begin
            if (count >= MOD - 1)
              count <= count + 32'd1 - MOD;
            else
              count <= count + 32'd1;
          end
        end

        NEXT_L: begin
          // Move to next l
          if (l < (S_reg << 1)) begin
            l <= l + 32'd1;
            if (l + 32'd1 <= r) begin
              // Reuse previous window: subtract digit_count(old l), keep r, sum
              sum <= sum - digit_count(l);
            end else begin
              // Reset r and sum to new l when window collapses
              r <= l + 32'd1;
              sum <= digit_count(l + 32'd1);
            end
          end
        end

        FINISH: begin
          done <= 1'b1;
        end
      endcase
    end
  end

  // Next-state & combinational updates
  always @* begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start)
          next_state = INIT_L;
      end

      INIT_L: begin
        next_state = SUM_DIGITS;
      end

      SUM_DIGITS: begin
        if ((sum >= S_reg) || (r >= (S_reg << 1)))
          next_state = CHECK_SUM;
        else
          next_state = SUM_DIGITS;
      end

      CHECK_SUM: begin
        next_state = NEXT_L;
      end

      NEXT_L: begin
        if (l < (S_reg << 1))
          next_state = SUM_DIGITS;
        else
          next_state = FINISH;
      end

      FINISH: begin
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule