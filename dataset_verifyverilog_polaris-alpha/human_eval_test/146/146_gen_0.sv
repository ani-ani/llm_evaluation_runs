module special_filter (
  input  logic              clk,
  input  logic              rst_n,
  input  logic              start,
  input  logic       [15:0] nums [7:0],
  output logic       [3:0]  count,
  output logic              done
);

  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    RUN   = 2'b01,
    HOLD  = 2'b10
  } state_t;

  state_t state, next_state;

  logic [3:0] cycle_ctr;      // 0..15 cycles
  logic [2:0] elem_idx;       // index 0..7
  logic       phase;          // 0: compute, 1: idle/transition (2 cycles per element)
  logic [3:0] cnt_reg;

  // Combinational signals for current element processing
  logic signed [15:0] cur_val;
  logic [15:0]        abs_val;
  logic [3:0]         first_digit;
  logic [3:0]         last_digit;
  logic               cond_met;

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      cycle_ctr  <= 4'd0;
      elem_idx   <= 3'd0;
      phase      <= 1'b0;
      cnt_reg    <= 4'd0;
      count      <= 4'd0;
      done       <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          count     <= cnt_reg;   // keep consistent
          if (start) begin
            // Initialize for new run
            cycle_ctr <= 4'd0;
            elem_idx  <= 3'd0;
            phase     <= 1'b0;    // first cycle of first element
            cnt_reg   <= 4'd0;
          end
        end

        RUN: begin
          // Two cycles per element: phase=0 (evaluate), phase=1 (gap)
          if (phase == 1'b0) begin
            // Evaluation cycle for current element
            if (cond_met) begin
              cnt_reg <= cnt_reg + 4'd1;
            end
          end

          // Advance phase / element / cycle counter
          if (phase == 1'b0) begin
            phase <= 1'b1;                 // next is gap cycle
          end else begin
            phase <= 1'b0;                 // next is evaluation of next element
            elem_idx <= elem_idx + 3'd1;   // move to next element
          end

          cycle_ctr <= cycle_ctr + 4'd1;

          // When 16 cycles complete, latch final count and assert done next_state logic
          if (cycle_ctr == 4'd15) begin
            count <= cnt_reg;
            done  <= 1'b1;
          end else begin
            done  <= 1'b0;
          end
        end

        HOLD: begin
          // Hold results until next start or reset
          done  <= 1'b1;
          count <= cnt_reg;
          if (start) begin
            // New run initialization
            done       <= 1'b0;
            cycle_ctr  <= 4'd0;
            elem_idx   <= 3'd0;
            phase      <= 1'b0;
            cnt_reg    <= 4'd0;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = RUN;
      end

      RUN: begin
        if (cycle_ctr == 4'd15)
          next_state = HOLD;
      end

      HOLD: begin
        if (start)
          next_state = RUN;
      end

      default: next_state = IDLE;
    endcase
  end

  // Current value selection
  assign cur_val = nums[elem_idx];

  // Absolute value
  assign abs_val = cur_val[15] ? (~cur_val + 16'd1) : cur_val;

  // Last digit (LSB of absolute value modulo 10)
  assign last_digit = abs_val % 10;

  // First non-zero digit of absolute value
  function automatic [3:0] get_first_digit(input [15:0] v);
    integer d;
    begin
      if (v == 16'd0) begin
        get_first_digit = 4'd0;
      end else begin
        // Extract decimal digits from most-significant side
        d = v;
        // Remove trailing zeros on the left by finding highest power of 10 <= v
        // Then walk down until first non-zero decimal digit encountered
        int place;
        place = 10000;
        if (d < 10000) place = 1000;
        if (d < 1000)  place = 100;
        if (d < 100)   place = 10;
        if (d < 10)    place = 1;

        while (place > 0) begin
          int digit;
          digit = d / place;
          if (digit != 0) begin
            get_first_digit = digit[3:0];
            return;
          end
          d = d % place;
          place = place / 10;
        end
        get_first_digit = 4'd0; // fallback
      end
    end
  endfunction

  assign first_digit = get_first_digit(abs_val);

  // Condition check
  function automatic bit is_odd_digit(input [3:0] d);
    begin
      is_odd_digit = (d == 4'd1) || (d == 4'd3) || (d == 4'd5) || (d == 4'd7) || (d == 4'd9);
    end
  endfunction

  assign cond_met = (abs_val > 16'd10) && is_odd_digit(first_digit) && is_odd_digit(last_digit);

endmodule