module even_odd_counter (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic signed [15:0] num,
  output logic [3:0]  even_count,
  output logic [3:0]  odd_count,
  output logic        done
);

  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    COUNT = 2'b01,
    DONE  = 2'b10
  } state_t;

  state_t       state, next_state;
  logic [15:0]  abs_num, next_abs_num;
  logic [2:0]   digit_cnt, next_digit_cnt; // counts up to 5
  logic [3:0]   next_even_count;
  logic [3:0]   next_odd_count;

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      abs_num     <= 16'd0;
      digit_cnt   <= 3'd0;
      even_count  <= 4'd0;
      odd_count   <= 4'd0;
      done        <= 1'b0;
    end else begin
      state       <= next_state;
      abs_num     <= next_abs_num;
      digit_cnt   <= next_digit_cnt;
      even_count  <= next_even_count;
      odd_count   <= next_odd_count;
      // done is driven combinationally from next_state; register for clean pulse
      done        <= (next_state == DONE);
    end
  end

  // Combinational next-state and outputs logic
  always_comb begin
    // Default assignments
    next_state       = state;
    next_abs_num     = abs_num;
    next_digit_cnt   = digit_cnt;
    next_even_count  = even_count;
    next_odd_count   = odd_count;

    case (state)
      IDLE: begin
        // Wait for start pulse
        if (start) begin
          // Take absolute value of input number
          if (num[15] == 1'b1)
            next_abs_num = (~num + 16'd1);
          else
            next_abs_num = num[15:0];

          next_even_count = 4'd0;
          next_odd_count  = 4'd0;
          next_digit_cnt  = 3'd0;

          // If abs value is already zero, move directly to DONE
          if (next_abs_num == 16'd0)
            next_state = DONE;
          else
            next_state = COUNT;
        end
      end

      COUNT: begin
        // Process one digit (LSB) per cycle
        // Check LSB to determine even/odd digit
        if (abs_num[0] == 1'b0)
          next_even_count = even_count + 4'd1;
        else
          next_odd_count  = odd_count  + 4'd1;

        // Shift right to drop the processed digit (binary digit)
        next_abs_num = abs_num >> 1;
        next_digit_cnt = digit_cnt + 3'd1;

        // Check stopping conditions: abs_num becomes 0 OR 5 digits processed
        if ((next_abs_num == 16'd0) || (next_digit_cnt == 3'd5)) begin
          next_state = DONE;
        end else begin
          next_state = COUNT;
        end
      end

      DONE: begin
        // done asserted for this cycle via registered logic
        // Return to IDLE on next cycle
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule