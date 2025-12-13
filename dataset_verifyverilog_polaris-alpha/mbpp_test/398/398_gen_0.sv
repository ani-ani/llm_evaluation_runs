module digit_sum (
  input        clk,
  input        rst_n,
  input        start,
  input  [7:0] numbers [7:0],
  output reg [6:0] total_sum,
  output reg       done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    LOAD  = 2'b01,
    DIGIT = 2'b10,
    NEXT  = 2'b11
  } state_t;

  state_t state, next_state;

  reg [2:0]  index;         // index for 8 numbers
  reg [7:0]  cur_num;       // absolute value of current number
  reg [3:0]  tens;          // tens digit (0-12 max for 8-bit abs)
  reg [3:0]  ones;          // ones digit (0-9)
  reg [6:0]  sum_reg;       // running total sum
  reg        start_d;       // registered start for edge detection

  // Edge detect for start (1-cycle pulse)
  wire start_pulse = start & ~start_d;

  // Combinational digit extraction logic
  // Using absolute value and simple two-digit decimal decomposition
  // Assumes cur_num holds |numbers[index]|.
  always_comb begin
    tens = cur_num / 10;
    ones = cur_num % 10;
  end

  // Next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse)
          next_state = LOAD;
      end

      LOAD: begin
        next_state = DIGIT;
      end

      DIGIT: begin
        next_state = NEXT;
      end

      NEXT: begin
        if (index == 3'd7)
          next_state = IDLE;
        else
          next_state = LOAD;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      start_d    <= 1'b0;
      index      <= 3'd0;
      cur_num    <= 8'd0;
      sum_reg    <= 7'd0;
      total_sum  <= 7'd0;
      done       <= 1'b0;
    end else begin
      // Register start for edge detection
      start_d <= start;

      // Default done low except when explicitly set
      done <= 1'b0;

      state <= next_state;

      case (state)
        IDLE: begin
          if (start_pulse) begin
            index     <= 3'd0;
            sum_reg   <= 7'd0;
            total_sum <= 7'd0;
          end
        end

        LOAD: begin
          // Capture absolute value of current number
          if (numbers[index][7] == 1'b1)
            cur_num <= (~numbers[index]) + 8'd1; // two's complement abs
          else
            cur_num <= numbers[index];
        end

        DIGIT: begin
          // Accumulate digit sum for current number
          sum_reg <= sum_reg + tens + ones;
        end

        NEXT: begin
          if (index == 3'd7) begin
            total_sum <= sum_reg;
            done      <= 1'b1;
          end else begin
            index <= index + 3'd1;
          end
        end

        default: begin
        end
      endcase
    end
  end

endmodule