module beautiful_number(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] n,
  input  [2:0] k,
  input  [3:0] digits [0:7],
  output reg [3:0] y_digits [0:7],
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    STATE_IDLE      = 3'd0,
    STATE_LOAD      = 3'd1,
    STATE_COMPARE_0 = 3'd2,
    STATE_COMPARE_1 = 3'd3,
    STATE_INC_0     = 3'd4,
    STATE_INC_1     = 3'd5,
    STATE_GENERATE  = 3'd6
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [3:0] orig_digits [0:7];      // Loaded input digits
  reg [3:0] base_digits [0:7];      // Current k-digit prefix (and working buffer)
  reg [3:0] pattern_digits [0:7];   // Temporary pattern for comparison

  reg [2:0] idx;                    // Index for loops up to 7

  // Flags
  reg        ge_flag;               // pattern_digits >= orig_digits
  reg        need_inc;              // Need to increment prefix

  // Synchronous state and registers
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= STATE_IDLE;
      done       <= 1'b0;
      ge_flag    <= 1'b0;
      need_inc   <= 1'b0;
      idx        <= 3'd0;
      for (i = 0; i < 8; i = i + 1) begin
        orig_digits[i]    <= 4'd0;
        base_digits[i]    <= 4'd0;
        pattern_digits[i] <= 4'd0;
        y_digits[i]       <= 4'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        STATE_IDLE: begin
          done     <= 1'b0;
          ge_flag  <= 1'b0;
          need_inc <= 1'b0;
          idx      <= 3'd0;
        end

        STATE_LOAD: begin
          // Load input digits into orig_digits and initialize base_digits prefix
          for (i = 0; i < 8; i = i + 1) begin
            orig_digits[i] <= digits[i];
          end
          for (i = 0; i < 8; i = i + 1) begin
            if (i < k)
              base_digits[i] <= digits[i];
            else
              base_digits[i] <= 4'd0;
          end
          ge_flag  <= 1'b0;
          need_inc <= 1'b0;
          idx      <= 3'd0;
        end

        STATE_COMPARE_0: begin
          // Build initial pattern_digits by repeating base_digits[0..k-1]
          for (i = 0; i < 8; i = i + 1) begin
            if (i < n)
              pattern_digits[i] <= base_digits[i % k];
            else
              pattern_digits[i] <= 4'd0;
          end
          idx      <= 3'd0;
          ge_flag  <= 1'b0;
          need_inc <= 1'b0;
        end

        STATE_COMPARE_1: begin
          // Perform lexicographic compare: pattern_digits vs orig_digits for i in [0, n-1]
          ge_flag  <= 1'b1; // assume >= until proven otherwise
          need_inc <= 1'b0;
          for (i = 0; i < 8; i = i + 1) begin
            if (i < n) begin
              if (!need_inc) begin
                if (pattern_digits[i] > orig_digits[i]) begin
                  ge_flag  <= 1'b1;
                  need_inc <= 1'b0;
                end else if (pattern_digits[i] < orig_digits[i]) begin
                  ge_flag  <= 1'b0;
                  need_inc <= 1'b1; // pattern < original, need increment
                end
              end
            end
          end
        end

        STATE_INC_0: begin
          // Copy current prefix into base_digits (already present) and prepare for increment
          // No operation needed beyond ensuring idx reset
          idx <= 3'd0;
        end

        STATE_INC_1: begin
          // Increment the k-digit prefix stored in base_digits[0..k-1] as a decimal number
          reg [3:0] temp;
          reg       carry;
          integer   j;
          carry = 1'b1; // add 1
          for (j = k-1; j >= 0; j = j - 1) begin
            if (carry) begin
              temp = base_digits[j] + 4'd1;
              if (temp >= 4'd10) begin
                base_digits[j] <= temp - 4'd10;
                carry          <= 1'b1;
              end else begin
                base_digits[j] <= temp;
                carry          <= 1'b0;
              end
            end
          end
          // If carry still 1 here, prefix overflowed; for this problem we ignore as inputs are constrained
        end

        STATE_GENERATE: begin
          // Generate final beautiful number from base_digits prefix
          for (i = 0; i < 8; i = i + 1) begin
            if (i < n)
              y_digits[i] <= base_digits[i % k];
            else
              y_digits[i] <= 4'd0;
          end
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      STATE_IDLE: begin
        if (start)
          next_state = STATE_LOAD;
      end

      STATE_LOAD: begin
        next_state = STATE_COMPARE_0; // 1 cycle
      end

      STATE_COMPARE_0: begin
        next_state = STATE_COMPARE_1; // 2nd compare cycle
      end

      STATE_COMPARE_1: begin
        // Decide whether we need increment based on comparison
        if (need_inc)
          next_state = STATE_INC_0;
        else
          next_state = STATE_GENERATE;
      end

      STATE_INC_0: begin
        next_state = STATE_INC_1; // 1st increment cycle
      end

      STATE_INC_1: begin
        next_state = STATE_GENERATE; // 2nd increment cycle
      end

      STATE_GENERATE: begin
        // Stay done until start is deasserted and reasserted
        if (!start)
          next_state = STATE_IDLE;
        else
          next_state = STATE_GENERATE;
      end

      default: begin
        next_state = STATE_IDLE;
      end
    endcase
  end

endmodule