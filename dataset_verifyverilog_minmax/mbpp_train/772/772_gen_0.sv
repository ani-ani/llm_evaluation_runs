module word_length_filter (
  input  clk,
  input  rst_n,
  input  start,
  input  [255:0] str_in,
  input  [2:0]   K,
  output reg [255:0] str_out,
  output reg       done
);

  typedef enum logic [2:0] { IDLE=3'd0, PARSE=3'd1, COMPARE=3'd2, BUILD_OUT=3'd3, DONE=3'd4 } state_t;

  // Internal state
  state_t state, next_state;
  logic [7:0] in_bytes [0:31];     // Local view of input bytes: in_bytes[0] is first character of str_in
  logic [7:0] out_bytes [0:31];    // Output bytes accumulator
  logic [5:0] out_len;             // Number of valid bytes in out_bytes (0..32)

  logic [4:0] pos;                 // Input scan position (0..31)
  logic [4:0] cur_wlen;            // Current word length in bytes
  logic [2:0] word_count;          // Count of words seen in current input (max 8)
  logic       cur_word_valid;      // Indicates we are currently inside a valid word

  logic [2:0] words_done;          // Words fully processed/built for this input
  logic [3:0] cycle_in_word;       // 0: PARSE, 1: COMPARE, 2+: BUILD_OUT cycles

  function [31:0] byte_to_bits(input [7:0] b);
    // Replicate byte across 32 bits to preserve byte order when assigned to [255:0]
    byte_to_bits = {24'b0, b};
  endfunction

  // Convert 32 bytes (8-bit each) to a packed 256-bit vector, preserving byte order (byte 0 at MSBs)
  function [255:0] bytes_to_packed(input [7:0] bytes [0:31]);
    integer i;
    for (i = 0; i < 32; i = i + 1) begin
      bytes_to_packed[i*8 +: 8] = bytes[i];
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      pos          <= 5'd0;
      cur_wlen     <= 5'd0;
      word_count   <= 3'd0;
      cur_word_valid <= 1'b0;
      words_done   <= 3'd0;
      cycle_in_word<= 4'd0;
      out_len      <= 6'd0;
      done         <= 1'b0;
      str_out      <= 256'b0;
    end else begin
      // Defaults (combinational-like behavior within the FF)
      next_state   <= state;
      pos          <= pos;
      cur_wlen     <= cur_wlen;
      word_count   <= word_count;
      cur_word_valid <= cur_word_valid;
      words_done   <= words_done;
      cycle_in_word<= cycle_in_word;
      out_len      <= out_len;
      done         <= 1'b0;
      str_out      <= 256'b0;

      case (state)
        IDLE: begin
          if (start) begin
            // Initialize for a new run
            // Latch input into local byte array (byte 0 is first char of str_in)
            in_bytes[0]  <= str_in[7:0];
            in_bytes[1]  <= str_in[15:8];
            in_bytes[2]  <= str_in[23:16];
            in_bytes[3]  <= str_in[31:24];
            in_bytes[4]  <= str_in[39:32];
            in_bytes[5]  <= str_in[47:40];
            in_bytes[6]  <= str_in[55:48];
            in_bytes[7]  <= str_in[63:56];
            in_bytes[8]  <= str_in[71:64];
            in_bytes[9]  <= str_in[79:72];
            in_bytes[10] <= str_in[87:80];
            in_bytes[11] <= str_in[95:88];
            in_bytes[12] <= str_in[103:96];
            in_bytes[13] <= str_in[111:104];
            in_bytes[14] <= str_in[119:112];
            in_bytes[15] <= str_in[127:120];
            in_bytes[16] <= str_in[135:128];
            in_bytes[17] <= str_in[143:136];
            in_bytes[18] <= str_in[151:144];
            in_bytes[19] <= str_in[159:152];
            in_bytes[20] <= str_in[167:160];
            in_bytes[21] <= str_in[175:168];
            in_bytes[22] <= str_in[183:176];
            in_bytes[23] <= str_in[191:184];
            in_bytes[24] <= str_in[199:192];
            in_bytes[25] <= str_in[207:200];
            in_bytes[26] <= str_in[215:208];
            in_bytes[27] <= str_in[223:216];
            in_bytes[28] <= str_in[231:224];
            in_bytes[29] <= str_in[239:232];
            in_bytes[30] <= str_in[247:240];
            in_bytes[31] <= str_in[255:248];

            out_len      <= 6'd0;
            pos          <= 5'd0;
            cur_wlen     <= 5'd0;
            cur_word_valid <= 1'b0;
            word_count   <= 3'd0;
            words_done   <= 3'd0;
            cycle_in_word<= 4'd0;
            next_state   <= PARSE;
          end
        end

        PARSE: begin
          // Cycle 0 of 2 per word
          if (pos < 32) begin
            if (in_bytes[pos] == 8'h20) begin
              // Space: advance until next non-space or end
              pos <= pos + 1;
            end else begin
              // Start of a word: count its length (up to 8)
              cur_wlen <= 5'd0;
              cur_word_valid <= 1'b1;
              cycle_in_word <= 4'd0; // this cycle is PARSE, next will be COMPARE
              next_state <= COMPARE;
            end
          end else begin
            // No more characters: finalize if we have produced any words
            next_state <= DONE;
          end
        end

        COMPARE: begin
          // Cycle 1 of 2 per word: measure word length and increment word count
          if (cur_word_valid) begin
            integer i;
            logic [4:0] wlen;
            wlen = 5'd0;
            for (i = 0; i < 8; i++) begin
              if ((pos + i) < 32 && in_bytes[pos + i] != 8'h20) wlen = wlen + 1;
              else break;
            end
            cur_wlen <= wlen;
            word_count <= word_count + 1;
            cycle_in_word <= 4'd1; // Next cycles will be BUILD_OUT
            next_state <= BUILD_OUT;
          end else begin
            // Should not happen, but safe fallback
            next_state <= DONE;
          end
        end

        BUILD_OUT: begin
          // Remaining cycles to append bytes of the word if kept; single space will be added on first append
          if (cur_word_valid) begin
            if (cur_wlen > 0) begin
              // Append up to 8 bytes of the word
              integer i, j;
              j = out_len; // current output length
              for (i = 0; i < 8; i = i + 1) begin
                if (i < cur_wlen && (pos + i) < 32) begin
                  // Insert single space only if this is the first appended word in the output
                  if (j == 0) begin
                    out_bytes[j] <= 8'h20; // space
                    j = j + 1;
                  end else begin
                    // If previous char is not already a space, ensure single spacing
                    if (out_bytes[j-1] != 8'h20) begin
                      out_bytes[j] <= 8'h20; // space before word if not already spaced
                      j = j + 1;
                    end
                  end
                  out_bytes[j] <= in_bytes[pos + i];
                  j = j + 1;
                end
              end
              out_len <= j;
            end
            // Advance input position past the processed word (or up to 8 bytes)
            if (pos + cur_wlen < 32) begin
              pos <= pos + cur_wlen;
            end else begin
              pos <= 5'd32;
            end
            words_done <= words_done + 1;
            cycle_in_word <= cycle_in_word + 1;
            next_state <= PARSE; // proceed to next word
          end else begin
            next_state <= PARSE;
          end
        end

        DONE: begin
          // Set done for one cycle, output is ready (after up to 2 cycles/word -> 16 cycles max for 8 words)
          str_out <= bytes_to_packed(out_bytes);
          done <= 1'b1;
          next_state <= IDLE;
        end

        default: next_state <= IDLE;
      endcase
    end
  end

  // Update state
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

endmodule
