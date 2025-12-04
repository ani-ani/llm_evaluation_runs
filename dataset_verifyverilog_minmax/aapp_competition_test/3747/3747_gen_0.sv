module bulbasaur_counter(
  input clk, // clock signal
  input rst_n, // active-low synchronous reset
  input start, // pulse high to begin processing
  input [5:0] str_len, // input string length (max 64)
  input [7:0] char_in, // current ASCII character input (requires valid_char=1)
  input valid_char, // high when char_in is valid
  output reg [7:0] bulbasaur_count, // number of "Bulbasaur" formations
  output reg done // high when computation complete
);

  // State machine
  typedef enum logic [1:0] { IDLE = 2'b00, READING = 2'b01, MIN1 = 2'b10, MIN2 = 2'b11 } state_t;
  state_t state, next_state;

  // Character counters for "Bulbasaur"
  reg [7:0] cntB, cntu, cntl, cntb, cnta, cnts, cntr;
  reg [7:0] chars_seen; // number of characters processed (gated by valid_char)
  reg [5:0] captured_len; // snapshot of str_len at start
  reg start_d;
  wire start_pulse = start && !start_d; // detect rising edge of start

  // Next-state logic for FSM and datapath
  always @(*) begin
    // Defaults
    next_state = state;
    done = 1'b0;

    unique case (state)
      IDLE: begin
        if (start_pulse) begin
          next_state = READING;
        end
      end

      READING: begin
        if ((chars_seen + (valid_char ? 1 : 0)) >= captured_len) begin
          next_state = MIN1;
        end
      end

      MIN1: begin
        // One cycle to compute min
        next_state = MIN2;
      end

      MIN2: begin
        // One cycle to register result and pulse done
        done = 1'b1;
        next_state = IDLE;
      end
    endcase
  end

  // State register and datapath update
  always @(posedge clk) begin
    start_d <= start;

    if (!rst_n) begin
      state <= IDLE;
      bulbasaur_count <= 8'h0;
      cntB <= 8'h0; cntu <= 8'h0; cntl <= 8'h0; cntb <= 8'h0;
      cnta <= 8'h0; cnts <= 8'h0; cntr <= 8'h0;
      chars_seen <= 8'h0;
      captured_len <= 6'h0;
    end else begin
      // Update FSM state
      state <= next_state;

      // Initialize on start pulse
      if (start_pulse) begin
        cntB <= 8'h0; cntu <= 8'h0; cntl <= 8'h0; cntb <= 8'h0;
        cnta <= 8'h0; cnts <= 8'h0; cntr <= 8'h0;
        chars_seen <= 8'h0;
        captured_len <= str_len; // snapshot length
      end

      // Character processing while reading
      if (state == READING && valid_char) begin
        // Increment appropriate counters if char matches (case-sensitive)
        case (char_in)
          "B": cntB <= cntB + 1;
          "u": cntu <= cntu + 1;
          "l": cntl <= cntl + 1;
          "b": cntb <= cntb + 1;
          "a": cnta <= cnta + 1;
          "s": cnts <= cnts + 1;
          "r": cntr <= cntr + 1;
          default: ; // no increment for other characters
        endcase
        chars_seen <= chars_seen + 1;
      end

      // Compute min(B, u/2, l, b, a/2, s, r)
      if (state == MIN1) begin
        bulbasaur_count <= (cntB < (cntu >> 1) ? cntB : (cntu >> 1));
        bulbasaur_count <= (state_min2_temp(bulbasaur_count, cntl) ? bulbasaur_count : cntl);
        bulbasaur_count <= (state_min2_temp(bulbasaur_count, cntb) ? bulbasaur_count : cntb);
        bulbasaur_count <= (state_min2_temp(bulbasaur_count, (cnta >> 1)) ? bulbasaur_count : (cnta >> 1));
        bulbasaur_count <= (state_min2_temp(bulbasaur_count, cnts) ? bulbasaur_count : cnts);
        bulbasaur_count <= (state_min2_temp(bulbasaur_count, cntr) ? bulbasaur_count : cntr);
      end
    end
  end

  // Helper function to compute min between registered value and a new candidate
  function state_min2_temp(input [7:0] current, input [7:0] candidate);
    state_min2_temp = (current < candidate);
  endfunction

endmodule
