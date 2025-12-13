module first_non_repeat (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [7:0]  str [7:0],
  output logic [7:0]  result,
  output logic        done
);

  // Frequency table: 256 entries of 4-bit counters
  logic [3:0] freq [255:0];

  // Shift register to store character order
  logic [7:0] char_shift [7:0];

  // FSM state and index counters
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    PASS1 = 2'b01,
    PASS2 = 2'b10,
    DONE  = 2'b11
  } state_t;

  state_t state, next_state;
  logic [3:0] idx;       // 0..8
  logic [3:0] pass2_idx; // 0..8

  // Synchronous state and control
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      idx        <= 4'd0;
      pass2_idx  <= 4'd0;
      result     <= 8'd0;
      done       <= 1'b0;
      // Clear frequency table
      integer fi;
      for (fi = 0; fi < 256; fi = fi + 1) begin
        freq[fi] <= 4'd0;
      end
      // Clear shift register
      integer si;
      for (si = 0; si < 8; si = si + 1) begin
        char_shift[si] <= 8'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          result    <= 8'd0;
          idx       <= 4'd0;
          pass2_idx <= 4'd0;
          if (start) begin
            // Initialize freq to zero when starting
            integer i0;
            for (i0 = 0; i0 < 256; i0 = i0 + 1) begin
              freq[i0] <= 4'd0;
            end
            // Load characters into shift register (order preservation)
            integer j0;
            for (j0 = 0; j0 < 8; j0 = j0 + 1) begin
              char_shift[j0] <= str[j0];
            end
          end
        end

        PASS1: begin
          // First pass: count frequencies for 8 cycles
          if (idx < 4'd8) begin
            // Increment frequency for current character (saturate at 4'hF just in case)
            logic [7:0] c;
            c = char_shift[idx];
            if (freq[c] != 4'hF) begin
              freq[c] <= freq[c] + 4'd1;
            end
            idx <= idx + 4'd1;
          end
        end

        PASS2: begin
          // Second pass: find first character with count == 1
          if (pass2_idx < 4'd8) begin
            logic [7:0] c2;
            c2 = char_shift[pass2_idx];
            if ((result == 8'd0) && (freq[c2] == 4'd1)) begin
              result <= c2;
            end
            pass2_idx <= pass2_idx + 4'd1;
          end
        end

        DONE: begin
          // Hold result and done high until next start or reset
          done <= 1'b1;
          if (start) begin
            // Prepare for a new operation on next cycle
            result    <= 8'd0;
            done      <= 1'b0;
            idx       <= 4'd0;
            pass2_idx <= 4'd0;
            // Clear frequencies
            integer i1;
            for (i1 = 0; i1 < 256; i1 = i1 + 1) begin
              freq[i1] <= 4'd0;
            end
            // Load new characters
            integer j1;
            for (j1 = 0; j1 < 8; j1 = j1 + 1) begin
              char_shift[j1] <= str[j1];
            end
          end
        end

        default: begin
          // Should not occur
          idx       <= 4'd0;
          pass2_idx <= 4'd0;
          done      <= 1'b0;
          result    <= 8'd0;
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
          next_state = PASS1;
      end

      PASS1: begin
        if (idx == 4'd8)
          next_state = PASS2;
      end

      PASS2: begin
        if (pass2_idx == 4'd8)
          next_state = DONE;
      end

      DONE: begin
        if (start)
          next_state = PASS1;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule