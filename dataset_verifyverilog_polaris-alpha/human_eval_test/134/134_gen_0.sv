module last_char_checker(
  input  clk,
  input  rst_n,
  input  start,
  input  [15:0][7:0] txt,
  output reg result,
  output reg done
);

  // FSM states
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    RUN   = 2'b01,
    FINAL = 2'b10
  } state_t;

  state_t state, next_state;

  // Index for scanning characters 0..15
  reg [4:0] idx; // needs 5 bits to represent 0..16

  // Tracking flags for last non-space character
  reg last_char_is_letter;
  reg prev_char_was_space;

  // Internal wires
  wire [7:0] cur_char;
  wire       is_zero;
  wire       is_space;
  wire       is_letter;

  assign cur_char  = txt[idx];
  assign is_zero   = (cur_char == 8'h00);
  assign is_space  = (cur_char == 8'h20);
  assign is_letter = ((cur_char >= 8'h41 && cur_char <= 8'h5A) ||
                      (cur_char >= 8'h61 && cur_char <= 8'h7A));

  // Sequential state and index update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state              <= IDLE;
      idx                <= 5'd0;
      last_char_is_letter<= 1'b0;
      prev_char_was_space<= 1'b1; // start-of-string treated as space
      result             <= 1'b0;
      done               <= 1'b1;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done               <= 1'b1;
          result             <= result; // hold
          if (start) begin
            // Initialize for run
            idx                 <= 5'd0;
            last_char_is_letter <= 1'b0;
            prev_char_was_space <= 1'b1; // start-of-string
            done                <= 1'b0;
          end
        end

        RUN: begin
          done <= 1'b0;

          // Process current character at idx
          if (!is_zero && !is_space) begin
            // Non-space, non-zero: update last non-space char info
            last_char_is_letter <= is_letter;
          end

          if (is_zero || is_space) begin
            // These are considered as spaces for prev_char_was_space
            prev_char_was_space <= 1'b1;
          end else begin
            prev_char_was_space <= 1'b0;
          end

          // Advance index
          if (idx < 5'd15) begin
            idx <= idx + 5'd1;
          end else begin
            idx <= idx; // hold at last during transition to FINAL
          end
        end

        FINAL: begin
          // Latch result based on last tracked non-space character
          result <= (last_char_is_letter && prev_char_was_space);
          done   <= 1'b1;
        end

        default: begin
          state  <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = RUN;
        else
          next_state = IDLE;
      end

      RUN: begin
        if (idx == 5'd15)
          next_state = FINAL;
        else
          next_state = RUN;
      end

      FINAL: begin
        // Stay in FINAL until a new start arrives
        if (start)
          next_state = RUN;
        else
          next_state = FINAL;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule