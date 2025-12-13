module int_base_converter(
  input        clk,
  input        rst_n,
  input        start,
  input  [7:0] x,
  input  [3:0] base,
  output reg [31:0] digits,
  output reg       valid
);

  // State encoding
  typedef enum logic [1:0] {
    S_IDLE   = 2'b00,
    S_DIV    = 2'b01,
    S_REVERSE= 2'b10,
    S_DONE   = 2'b11
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [7:0]  current_val;
  reg [3:0]  current_base;
  reg [3:0]  rem_buf [0:7];      // up to 8 digits (base 2..9, 0-255)
  reg [3:0]  rem_count;          // number of valid digits stored (1..8), 0 means none yet
  reg [3:0]  div_iter;           // division iteration counter
  reg [3:0]  rev_iter;           // reversal iteration counter
  reg        start_d;

  // Start pulse detection
  wire start_pulse = start & ~start_d;

  // Sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      digits       <= 32'd0;
      valid        <= 1'b0;
      current_val  <= 8'd0;
      current_base <= 4'd0;
      rem_count    <= 4'd0;
      div_iter     <= 4'd0;
      rev_iter     <= 4'd0;
      start_d      <= 1'b0;
    end else begin
      start_d <= start;
      state   <= next_state;

      case (state)
        S_IDLE: begin
          valid   <= 1'b0;
          digits  <= digits; // hold
          if (start_pulse && (base >= 4'd2) && (base <= 4'd9)) begin
            current_val  <= x;
            current_base <= base;
            rem_count    <= 4'd0;
            div_iter     <= 4'd0;
            rev_iter     <= 4'd0;
          end
        end

        S_DIV: begin
          // Perform successive division; one division per cycle
          if (div_iter == 4'd0) begin
            // First cycle after entering S_DIV; handle x == 0 case immediately
            if (current_val == 8'd0) begin
              // Represent zero: single zero digit
              rem_buf[0] <= 4'd0;
              rem_count  <= 4'd1;
              div_iter   <= 4'd8; // force completion
            end else begin
              // Normal path will be handled in following cycles
              // fall through to iterative logic below for next cycles
            end
          end

          if (div_iter < 4'd8) begin
            if (!(div_iter == 4'd0 && current_val == 8'd0)) begin
              // Only run division steps when not the special zero shortcut just set
              reg [7:0] q;
              reg [3:0] r;
              q = current_val / current_base;
              r = current_val % current_base;
              rem_buf[rem_count] <= r;
              rem_count          <= rem_count + 4'd1;
              current_val        <= q;
            end
            div_iter <= div_iter + 4'd1;
          end
        end

        S_REVERSE: begin
          // Build the 8-digit output, left-aligned, one digit per cycle
          // Total cycles: up to 8
          if (rev_iter < 4'd8) begin
            reg [3:0] src_digit;
            reg [3:0] out_digit;

            // source index (from rem_buf), reversing order
            // valid only when rev_iter < rem_count
            if (rev_iter < rem_count)
              src_digit = rem_buf[rem_count - 1 - rev_iter];
            else
              src_digit = 4'd0;

            // pad leading zeros when rev_iter < (8 - rem_count)
            if (rev_iter < (4'd8 - rem_count))
              out_digit = 4'd0;
            else
              out_digit = src_digit;

            // place digit at [31:28], [27:24], ..., [3:0]
            digits[31 - rev_iter*4 -: 4] <= out_digit;

            rev_iter <= rev_iter + 4'd1;
          end
        end

        S_DONE: begin
          valid <= 1'b1;
        end

        default: begin
          // Should not occur; safe defaults
          valid <= 1'b0;
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start_pulse && (base >= 4'd2) && (base <= 4'd9))
          next_state = S_DIV;
      end

      S_DIV: begin
        // After up to 8 division cycles, move to reverse
        if (div_iter >= 4'd8)
          next_state = S_REVERSE;
      end

      S_REVERSE: begin
        // After 8 reversal/output cycles, move to done
        if (rev_iter >= 4'd8)
          next_state = S_DONE;
      end

      S_DONE: begin
        // Wait for start pulse to start new conversion
        if (start_pulse && (base >= 4'd2) && (base <= 4'd9))
          next_state = S_DIV;
        else if (!start_pulse)
          next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

endmodule