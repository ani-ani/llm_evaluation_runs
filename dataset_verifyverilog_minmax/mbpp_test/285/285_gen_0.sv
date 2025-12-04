module ab_pattern_check (
  input clk,
  input rst_n,
  input start,
  input [63:0] str_in, // byte 7 = first character
  output reg match_found,
  output reg done
);

  // Number of bytes to process
  localparam BYTES = 8;
  localparam BYTE_W = 8;

  // ASCII constants
  localparam ASCII_A = 8'h61; // 'a'
  localparam ASCII_B = 8'h62; // 'b'

  // FSM states
  typedef enum logic [2:0] {
    IDLE      = 3'b000,
    CHECKING  = 3'b001,
    FOUND_A   = 3'b010,
    COUNT_B   = 3'b011,
    DONE      = 3'b100
  } state_t;
  state_t state, next_state;

  // Byte index: 7 -> 0 (byte 7 is first character)
  logic [$clog2(BYTES):0] byte_idx;
  logic [$clog2(BYTES):0] next_byte_idx;
  logic [1:0] b_count;      // 0..3
  logic [1:0] next_b_count;
  logic [7:0] cur_char;
  logic next_done;
  logic next_match_found;
  logic start_pulse;
  logic [$clog2(BYTES):0] total_bytes_minus_one;

  // Current character for the current byte index
  assign cur_char = str_in[byte_idx*BYTE_W +: BYTE_W];
  assign total_bytes_minus_one = BYTES - 1;

  // Edge detection for start (synchronous to clk)
  always_ff @(posedge clk) begin
    if (!rst_n) start_pulse <= 1'b0;
    else start_pulse <= start;
  end

  // State and control registers (synchronous, sequential)
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state        <= IDLE;
      byte_idx     <= total_bytes_minus_one;
      b_count      <= 2'b0;
      match_found  <= 1'b0;
      done         <= 1'b0;
    end else begin
      state        <= next_state;
      byte_idx     <= next_byte_idx;
      b_count      <= next_b_count;
      match_found  <= next_match_found;
      done         <= next_done;
    end
  end

  // Next-state logic (combinational)
  always_comb begin
    // Defaults
    next_state     = state;
    next_byte_idx  = byte_idx;
    next_b_count   = b_count;
    next_done      = 1'b0;
    next_match_found = 1'b0;

    // Default keep outputs during reset/IDLE
    if (state == IDLE) begin
      next_match_found = 1'b0;
      next_done        = 1'b0;
    end

    // Update match_found when found to keep it sticky until reset
    if (match_found) next_match_found = 1'b1;

    // FSM
    case (state)
      IDLE: begin
        // Outputs stay zero on reset/idle (handled above)
        if (start_pulse) begin
          next_state    = CHECKING;
          // Start from byte 7 (first character)
          next_byte_idx = total_bytes_minus_one;
          next_b_count  = 2'b0;
        end else begin
          next_state    = IDLE;
          next_byte_idx = total_bytes_minus_one;
          next_b_count  = 2'b0;
        end
      end

      CHECKING: begin
        if (cur_char == ASCII_A) begin
          // Move to FOUND_A and wait for first 'b' in next cycle
          next_state   = FOUND_A;
          next_b_count = 2'b0;
        end else begin
          // Continue searching; advance to next byte
          if (byte_idx == 1'b0) begin
            next_state    = DONE;
            next_byte_idx = 1'b0; // stay at last byte
          end else begin
            next_byte_idx = byte_idx - 1;
          end
        end
      end

      FOUND_A: begin
        if (cur_char == ASCII_B) begin
          next_state  = COUNT_B;
          next_b_count = 1; // first 'b' counted
        end else begin
          // Not followed by 'b' -> resume search from next character
          next_state   = CHECKING;
          next_b_count = 2'b0;
          if (byte_idx == 1'b0) begin
            next_state    = DONE;
            next_byte_idx = 1'b0;
          end else begin
            next_byte_idx = byte_idx - 1;
          end
        end
      end

      COUNT_B: begin
        if (cur_char == ASCII_B) begin
          // Continue counting 'b's up to 3
          next_b_count = (b_count < 2'd3) ? (b_count + 1'b1) : 2'd3;
          // Keep counting until a non-'b' or end
          if (byte_idx == 1'b0) begin
            // End of string while still counting 'b's
            next_state = DONE;
            // b_count already holds total; we will decide match in DONE
          end
        end else begin
          // Non-'b' encountered: decide outcome
          if ((b_count == 2'd2) || (b_count == 2'd3)) begin
            next_match_found = 1'b1;
            next_state       = DONE;
            // All bytes already processed when we get here
            next_byte_idx    = 1'b0;
          end else begin
            // Not enough 'b's -> resume search from the next char
            next_state   = CHECKING;
            next_b_count = 2'b0;
            if (byte_idx == 1'b0) begin
              next_state    = DONE;
              next_byte_idx = 1'b0;
            end else begin
              next_byte_idx = byte_idx - 1;
            end
          end
        end
      end

      DONE: begin
        // Completed after last byte; hold outputs for one cycle
        next_done  = 1'b1;
        next_state = IDLE;
      end

      default: begin
        next_state     = IDLE;
        next_byte_idx  = total_bytes_minus_one;
        next_b_count   = 2'b0;
        next_done      = 1'b0;
        next_match_found = 1'b0;
      end
    endcase
  end

endmodule
