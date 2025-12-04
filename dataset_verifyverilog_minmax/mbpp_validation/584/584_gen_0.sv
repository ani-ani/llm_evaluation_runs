module adverb_finder(
  input clk,
  input rst_n,
  input start,
  input [511:0] text,
  output reg [5:0] start_pos,
  output reg [5:0] end_pos,
  output reg [31:0] found_word,
  output reg valid,
  output reg done
);

  typedef enum logic [1:0] {IDLE=2'b00, SCAN=2'b01, DONE=2'b10} state_t;
  state_t state;

  integer i;
  integer wstart;         // start index of current word (-1 if not in a word)
  logic [15:0] last2;     // last two bytes (little-endian)
  logic is_letter;
  logic [7:0] byte_at_idx;

  function is_letter_fn(input [7:0] b);
    // ASCII letters only (A-Z, a-z)
    is_letter_fn = ((b >= "A") && (b <= "Z")) || ((b >= "a") && (b <= "z"));
  endfunction

  always_comb begin
    is_letter = is_letter_fn(byte_at_idx);
    last2 = {byte_at_idx, 8'b0} | {8'b0, byte_at_idx}; // not used; kept for clarity
  end

  // Byte extraction: 8 bits per character, index 0 -> LSB of text[7:0]
  always_comb begin
    byte_at_idx = text[i*8 +: 8];
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      wstart <= -1;
      start_pos <= 6'd0;
      end_pos <= 6'd0;
      found_word <= 32'd0;
      valid <= 1'b0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SCAN;
            i <= 0;
            wstart <= -1;
            start_pos <= 6'd0;
            end_pos <= 6'd0;
            found_word <= 32'd0;
            valid <= 1'b0;
            done <= 1'b0;
          end else begin
            done <= 1'b0; // ensure done is low in IDLE unless a prior start completed
            valid <= 1'b0;
          end
        end

        SCAN: begin
          // Defaults for this cycle
          valid <= 1'b0;
          done <= 1'b0;

          // Character and category
          byte_at_idx = text[i*8 +: 8];
          is_letter = ((byte_at_idx >= "A") && (byte_at_idx <= "Z")) ||
                      ((byte_at_idx >= "a") && (byte_at_idx <= "z"));

          // Word start tracking: non-letter -> letter transition
          if (wstart == -1) begin
            if (is_letter) wstart <= i;
          end

          // Check for "ly" ending at current position (need at least 2 chars in word)
          if (wstart >= 0 && i >= (wstart + 1) && byte_at_idx == "y" &&
              (i > 0) && (text[(i-1)*8 +: 8] == "l")) begin

            // Capture result when word boundary after 'ly' or end of input
            if (!is_letter || i == 63) begin
              start_pos <= wstart[5:0];
              end_pos <= (i + 1)[5:0];   // end position + 1 as required
              // Pack up to first 4 characters of the found word into found_word (MSB-first)
              if ((i - wstart + 1) >= 4) begin
                found_word <= {
                  text[wstart*8 +: 8],
                  text[(wstart+1)*8 +: 8],
                  text[(wstart+2)*8 +: 8],
                  text[(wstart+3)*8 +: 8]
                };
              end else if ((i - wstart + 1) == 3) begin
                found_word <= {
                  8'd0,
                  text[wstart*8 +: 8],
                  text[(wstart+1)*8 +: 8],
                  text[(wstart+2)*8 +: 8]
                };
              end else if ((i - wstart + 1) == 2) begin
                found_word <= {
                  16'd0,
                  text[wstart*8 +: 8],
                  text[(wstart+1)*8 +: 8]
                };
              end else begin
                found_word <= {24'd0, text[wstart*8 +: 8]};
              end
              valid <= 1'b1;
              done <= 1'b1;
              state <= DONE;
              i <= 0;
              wstart <= -1;
            end
          end

          // Advance index
          i <= i + 1;

          // Word end reset (non-letter encountered while in a word)
          if (!is_letter) begin
            wstart <= -1;
          end

          // Complete scan: no match found within 64 characters
          if (i == 63) begin // committed to processing char 63 this cycle
            if (!(valid && done)) begin // if not already found
              valid <= 1'b0;
              done <= 1'b1;
              state <= DONE;
            end
            i <= 0;
            wstart <= -1;
          end
        end

        DONE: begin
          // Hold outputs until next start or reset
          if (start) begin
            // Start a new scan immediately
            state <= SCAN;
            i <= 0;
            wstart <= -1;
            start_pos <= 6'd0;
            end_pos <= 6'd0;
            found_word <= 32'd0;
            valid <= 1'b0;
            done <= 1'b0;
          end else begin
            done <= 1'b1;
            valid <= valid; // latch last valid result
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
