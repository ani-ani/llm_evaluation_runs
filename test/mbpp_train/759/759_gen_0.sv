module decimal_checker(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] char_in,
  input  last_char,
  output reg valid,
  output reg done
);

  // State encoding
  localparam IDLE        = 3'd0;
  localparam INTEGER     = 3'd1;
  localparam DEC_POINT   = 3'd2;
  localparam DEC_DIGIT_1 = 3'd3;
  localparam DEC_DIGIT_2 = 3'd4;
  localparam INVALID     = 3'd5;

  reg [2:0] state, next_state;

  // Helper wires
  wire is_digit = (char_in >= "0") && (char_in <= "9");
  wire is_dot   = (char_in == ".");

  // Sequential state and output registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      valid <= 1'b0;
      done  <= 1'b0;
    end else begin
      state <= next_state;

      // done/valid asserted only in response to last_char (1-cycle latency)
      if (last_char) begin
        // Determine validity based on state reached at last_char cycle
        case (next_state)
          INTEGER,
          DEC_DIGIT_1,
          DEC_DIGIT_2: begin
            valid <= (next_state != INVALID);
          end
          default: begin
            valid <= 1'b0;
          end
        endcase
        done <= 1'b1;
      end else begin
        // Clear outputs when not completing
        done  <= 1'b0;
        valid <= 1'b0;
      end
    end
  end

  // Next-state logic
  always @* begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start) begin
          // Expect first character of number on same cycle as start
          if (is_digit) begin
            next_state = INTEGER;
          end else begin
            next_state = INVALID;
          end
        end
      end

      INTEGER: begin
        if (last_char) begin
          // End of input: already ensured digit-only so INTEGER is valid end
          next_state = INTEGER;
        end else if (is_digit) begin
          next_state = INTEGER;           // Continue integer digits
        end else if (is_dot) begin
          next_state = DEC_POINT;         // Single decimal point allowed
        end else begin
          next_state = INVALID;           // Non-digit/non-dot
        end
      end

      DEC_POINT: begin
        // Must be first fractional digit; cannot end here
        if (is_digit) begin
          next_state = DEC_DIGIT_1;
        end else begin
          next_state = INVALID;           // No digit after '.'
        end
      end

      DEC_DIGIT_1: begin
        if (last_char) begin
          // One fractional digit is allowed end
          if (is_digit) begin
            next_state = DEC_DIGIT_1;     // Remain; valid terminal state
          end else begin
            next_state = INVALID;
          end
        end else if (is_digit) {
          // Optional second fractional digit
          next_state = DEC_DIGIT_2;
        end else begin
          next_state = INVALID;           // Only digits allowed
        end
      end

      DEC_DIGIT_2: begin
        // Allow at most 2 fractional digits
        if (is_digit || is_dot) begin
          next_state = INVALID;           // Too many digits or extra '.'
        end else if (last_char) begin
          // End exactly after second fractional digit
          next_state = DEC_DIGIT_2;       // Valid terminal state
        end else begin
          next_state = INVALID;           // Any other char invalid
        end
      end

      INVALID: begin
        // Stay invalid until reset or new start (handled implicitly)
        if (start) begin
          // Allow restart from INVALID if desired
          if (is_digit) begin
            next_state = INTEGER;
          end else begin
            next_state = INVALID;
          end
        end
      end

      default: begin
        next_state = INVALID;
      end
    endcase
  end

endmodule