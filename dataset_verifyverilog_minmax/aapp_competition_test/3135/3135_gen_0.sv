module signed_binary_converter(
  input clk,
  input rst_n,
  input start,
  input [7:0] bin_in, // Binary input (MSB first)
  output reg [15:0] signed_out, // Packed output (2 bits per digit: 00='+', 01='-', 10='0')
  output reg done
);

  // Internal state
  typedef enum logic [1:0] {IDLE = 2'b00, PROCESSING = 2'b01, DONE = 2'b10} state_t;
  state_t state, next_state;

  // Iteration control
  reg [3:0] idx;        // 0..7 (current bit index: LSB first)
  reg [3:0] next_idx;

  // Carry and output packing
  reg carry;            // 1-bit carry
  reg carry_next;
  reg [1:0] digit;      // 2-bit encoded digit: 2'b00='+', 2'b01='-', 2'b10='0'
  reg [1:0] digit_next;
  integer j;            // Output digit position accumulator

  // Precompute look-ahead for greedy minimal non-zero selection
  // next_lookahead = (i < 7) ? bin_in[6-i] : 1'b0; // bit i+1 (LSB-first), 1'b0 past MSB
  wire next_lookahead = (idx < 4'd7) ? bin_in[6 - idx] : 1'b0;

  // Determine digit and next carry using greedy choice:
  // Prefer '0' when possible (keeps non-zero count minimal), otherwise '+' or '-'.
  // Tie-breaker order: '+' < '-' < '0' (lexicographic per spec).
  always_comb begin
    // Defaults (avoid latches)
    digit_next = 2'b10; // '0'
    carry_next = 1'b0;
    if (carry == 1'b0) begin
      // current_bit = bin_in[7-idx]
      if (bin_in[7 - idx] == 1'b0) begin
        // 0 + 0 -> '0', carry 0
        digit_next = 2'b10; // '0'
        carry_next = 1'b0;
      end else begin
        // 1 + 0 -> if next is 0 use '0' (carry 0), else '+' (carry 1)
        if (next_lookahead == 1'b0) begin
          digit_next = 2'b10; // '0'
          carry_next = 1'b0;
        end else begin
          digit_next = 2'b00; // '+'
          carry_next = 1'b1;
        end
      end
    end else begin
      // carry == 1
      if (bin_in[7 - idx] == 1'b0) begin
        // 0 + 1 -> if next is 1 use '-' (carry 1), else '0' (carry 1)
        if (next_lookahead == 1'b1) begin
          digit_next = 2'b01; // '-'
          carry_next = 1'b1;
        end else begin
          digit_next = 2'b10; // '0'
          carry_next = 1'b1;
        end
      end else begin
        // 1 + 1 -> '+', carry 1
        digit_next = 2'b00; // '+'
        carry_next = 1'b1;
      end
    end
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      idx   <= 4'd0;
      carry <= 1'b0;
      signed_out <= 16'd0;
      done  <= 1'b0;
    end else begin
      state     <= next_state;
      idx       <= next_idx;
      carry     <= carry_next;
      done      <= 1'b0; // default; set in DONE state explicitly
    end
  end

  // Next-state and datapath
  always_comb begin
    // defaults
    next_state = state;
    next_idx   = idx;
    digit      = 2'b10; // default '0' (for simulation completeness)

    case (state)
      IDLE: begin
        next_idx = 4'd0;
        if (start) begin
          next_state = PROCESSING;
        end
      end

      PROCESSING: begin
        // Compute digit for current idx (LSB-first)
        digit = digit_next;

        // Pack digit into signed_out at the correct position (MSB-first in the field)
        // Digit 0 (MSB) goes to bits [15:14], Digit 1 to [13:12], ... Digit 7 to [1:0]
        j = 7 - idx; // 0..7 mapped to MSB..LSB within 2-bit groups
        signed_out[(j*2) +: 2] = digit;

        // Prepare next index and carry
        next_idx = idx + 1;

        if (idx == 4'd7) begin
          next_state = DONE;
        end else begin
          next_state = PROCESSING;
        end
      end

      DONE: begin
        // Hold result valid for one cycle
        next_state = IDLE;
        // done will be asserted in the clock edge of DONE state
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Assert done in the DONE state
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else begin
      if (state == DONE) begin
        done <= 1'b1;
      end
    end
  end

endmodule
