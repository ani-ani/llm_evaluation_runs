module music_parser (
  input        clk,
  input        rst_n,
  input        start,
  input  [5:0] length,
  input  [255:0] music_string,
  output reg [2:0] beat,
  output reg       beat_valid,
  output reg       done
);

  // State encoding
  typedef enum logic [2:0] {
    S_IDLE       = 3'd0,
    S_CHECK_DONE = 3'd1,
    S_READ_CHAR  = 3'd2,
    S_OUTPUT     = 3'd3,
    S_ERROR      = 3'd4,
    S_FINISH     = 3'd5
  } state_t;

  state_t state, next_state;

  reg [5:0] idx;              // current character index (0-31)
  reg [7:0] cur_char;         // current character
  reg [7:0] next_char;        // lookahead character
  reg [2:0] beat_next;        // beat to output
  reg       have_token;       // indicates a valid token was parsed
  reg [5:0] length_latched;   // latch length on start

  // Extract byte from music_string
  function automatic [7:0] get_char;
    input [255:0] bus;
    input [5:0]   index;
    begin
      // Byte 0 is MSB [255:248], Byte 31 is LSB [7:0]
      get_char = bus[255 - index*8 -: 8];
    end
  endfunction

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= S_IDLE;
      idx            <= 6'd0;
      cur_char       <= 8'd0;
      next_char      <= 8'd0;
      beat           <= 3'd0;
      beat_valid     <= 1'b0;
      done           <= 1'b0;
      beat_next      <= 3'd0;
      have_token     <= 1'b0;
      length_latched <= 6'd0;
    end else begin
      state      <= next_state;
      beat_valid <= 1'b0;    // default low each cycle; asserted only in S_OUTPUT
      done       <= 1'b0;    // asserted only when finishing/error

      case (state)
        S_IDLE: begin
          if (start) begin
            length_latched <= length;
            idx            <= 6'd0;
          end
        end

        S_CHECK_DONE: begin
          // nothing; decision in next_state
        end

        S_READ_CHAR: begin
          cur_char  <= get_char(music_string, idx);
          if (idx + 6'd1 < length_latched)
            next_char <= get_char(music_string, idx + 6'd1);
          else
            next_char <= 8'd0;
        end

        S_OUTPUT: begin
          // Output the beat for exactly one cycle
          beat       <= beat_next;
          beat_valid <= 1'b1;
          // Advance index based on token length
          if (have_token) begin
            // if two-char token (o| or .|), we increment by 2, else by 1
            if ((cur_char == 8'h6F && next_char == 8'h7C) ||
                (cur_char == 8'h2E && next_char == 8'h7C)) begin
              idx <= idx + 6'd2;
            end else begin
              idx <= idx + 6'd1;
            end
          end
        end

        S_ERROR: begin
          done <= 1'b1; // immediate done on error, no beat_valid
        end

        S_FINISH: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Combinational next-state and token decode
  always @* begin
    next_state = state;
    beat_next  = 3'd0;
    have_token = 1'b0;

    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_CHECK_DONE;
      end

      S_CHECK_DONE: begin
        if (length_latched == 6'd0) begin
          next_state = S_FINISH; // empty string
        end else if (idx >= length_latched) begin
          next_state = S_FINISH; // done
        end else begin
          next_state = S_READ_CHAR;
        end
      end

      S_READ_CHAR: begin
        // After latching characters, decide on meaning next cycle
        // Decision combinationally here based on cur_char/next_char from previous cycle
        // But we must assume they are valid from prior cycle; so S_READ_CHAR is used
        // as the state where we interpret already-latched values.

        // Skip spaces
        if (cur_char == 8'h20) begin
          // Space: consume one char and move on
          if (idx + 6'd1 >= length_latched)
            next_state = S_FINISH;
          else
            next_state = S_READ_CHAR;
        end else if (cur_char == 8'h6F) begin
          // 'o' : could be 'o|' (2 beats) or 'o' alone (4 beats)
          if (next_char == 8'h7C && (idx + 6'd1) < length_latched) begin
            // 'o|' token => 2 beats
            beat_next  = 3'd2;
            have_token = 1'b1;
            next_state = S_OUTPUT;
          end else begin
            // 'o' alone => 4 beats
            beat_next  = 3'd4;
            have_token = 1'b1;
            next_state = S_OUTPUT;
          end
        end else if (cur_char == 8'h2E) begin
          // '.' must be followed by '|' to be valid '.|' => 1 beat
          if (next_char == 8'h7C && (idx + 6'd1) < length_latched) begin
            beat_next  = 3'd1;
            have_token = 1'b1;
            next_state = S_OUTPUT;
          end else begin
            // invalid sequence
            next_state = S_ERROR;
          end
        end else if (cur_char == 8'h7C) begin
          // Lone '|' is invalid
          next_state = S_ERROR;
        end else begin
          // Any other character is invalid token sequence
          next_state = S_ERROR;
        end
      end

      S_OUTPUT: begin
        // After outputting, either continue or finish
        if (idx >= length_latched)
          next_state = S_FINISH;
        else
          next_state = S_READ_CHAR;
      end

      S_ERROR: begin
        next_state = S_IDLE; // go idle after signaling done
      end

      S_FINISH: begin
        next_state = S_IDLE; // go idle after signaling done
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule