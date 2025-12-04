module closest_vowel_finder(
  input  logic              clk,
  input  logic              rst_n,
  input  logic              start,
  input  logic [15:0][7:0]  word,
  input  logic [3:0]        length,
  output logic [7:0]        result,
  output logic              done
);

  // Internal signals
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    BUSY  = 2'b01,
    DONE  = 2'b10
  } state_t;

  state_t          state, next_state;
  logic [7:0]      best_vowel;
  logic [3:0]      cycle_cnt;
  logic            start_d;
  logic            start_pulse;
  logic [7:0]      w[15:0];
  logic [3:0]      len_reg;

  // Capture inputs at start pulse to avoid changes during processing
  integer i;

  // Start pulse generation (one-cycle pulse on rising edge of start)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end

  assign start_pulse = start & ~start_d;

  // Input latching on start pulse
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      len_reg <= 4'd0;
      for (i = 0; i < 16; i = i + 1) begin
        w[i] <= 8'd0;
      end
    end else if (start_pulse && state == IDLE) begin
      len_reg <= length;
      for (i = 0; i < 16; i = i + 1) begin
        w[i] <= word[i];
      end
    end
  end

  // Vowel and consonant helpers
  function automatic logic is_vowel(input logic [7:0] c);
    case (c)
      8'h41, // 'A'
      8'h45, // 'E'
      8'h49, // 'I'
      8'h4F, // 'O'
      8'h55, // 'U'
      8'h61, // 'a'
      8'h65, // 'e'
      8'h69, // 'i'
      8'h6F, // 'o'
      8'h75: // 'u'
        is_vowel = 1'b1;
      default:
        is_vowel = 1'b0;
    endcase
  endfunction

  function automatic logic is_letter(input logic [7:0] c);
    if ((c >= 8'h41 && c <= 8'h5A) || (c >= 8'h61 && c <= 8'h7A))
      is_letter = 1'b1;
    else
      is_letter = 1'b0;
  endfunction

  function automatic logic is_consonant(input logic [7:0] c);
    if (is_letter(c) && !is_vowel(c))
      is_consonant = 1'b1;
    else
      is_consonant = 1'b0;
  endfunction

  // Check for qualifying vowel at index i (1 <= i <= len_reg-2)
  function automatic logic is_qualifying_vowel(
    input logic [3:0]       idx,
    input logic [7:0]       word_arr[15:0],
    input logic [3:0]       l
  );
    logic in_range;
    in_range = (l >= 4'd3) && (idx > 0) && (idx < (l - 1));
    if (!in_range) begin
      is_qualifying_vowel = 1'b0;
    end else begin
      is_qualifying_vowel = is_vowel(word_arr[idx]) &&
                            is_consonant(word_arr[idx-1]) &&
                            is_consonant(word_arr[idx+1]);
    end
  endfunction

  // State machine next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse)
          next_state = BUSY;
      end
      BUSY: begin
        if (cycle_cnt == 4'd15)
          next_state = DONE;
      end
      DONE: begin
        // Return to IDLE when start pulse occurs again
        if (start_pulse)
          next_state = BUSY;
        else if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic: state, counters, and search
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      cycle_cnt  <= 4'd0;
      best_vowel <= 8'd0;
      result     <= 8'd0;
      done       <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done       <= 1'b0;
          result     <= 8'd0;
          best_vowel <= 8'd0;
          cycle_cnt  <= 4'd0;
        end

        BUSY: begin
          done <= 1'b0;

          // Perform one step of the search per cycle.
          // We scan from index (len_reg-2) down to 1.
          if (cycle_cnt < 4'd15) begin
            logic [4:0] offset;
            logic [4:0] idx_calc;
            offset   = cycle_cnt;
            idx_calc = (len_reg >= 2) ? ({1'b0,len_reg} - 5'd2) - offset : 5'd0;

            if (idx_calc[4:0] >= 5'd1 && idx_calc[4:0] <= 5'd14) begin
              if (is_qualifying_vowel(idx_calc[3:0], w, len_reg)) begin
                if (best_vowel == 8'd0)
                  best_vowel <= w[idx_calc[3:0]];
              end
            end

            cycle_cnt <= cycle_cnt + 4'd1;
          end else begin
            cycle_cnt <= cycle_cnt; // hold
          end
        end

        DONE: begin
          // Latch result and assert done
          result <= (best_vowel != 8'd0) ? best_vowel : 8'd0;
          done   <= 1'b1;
          // Hold cycle_cnt and best_vowel until next start
        end

        default: begin
          state      <= IDLE;
          cycle_cnt  <= 4'd0;
          best_vowel <= 8'd0;
          result     <= 8'd0;
          done       <= 1'b0;
        end
      endcase
    end
  end

endmodule