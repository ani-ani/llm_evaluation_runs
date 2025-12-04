module quote_extractor(
  input  clk,
  input  rst_n,
  input  start,
  input  [63:0][7:0] text_input,
  output reg [7:0][15:0][7:0] extracted_strings,
  output reg [2:0] string_count,
  output reg done
);

  // State encoding
  typedef enum logic [0:0] {IDLE = 1'b0, CAPTURING = 1'b1} state_t;
  state_t state;

  // Index for input bytes (0..63)
  reg [5:0] idx;

  // Per-string character index (0..16, we store only when <16)
  reg [4:0] char_idx;

  // Internal string index (0..7) as int; mapped to 3-bit output
  reg [2:0] str_idx;

  // Latched view of start to detect the cycle to begin processing
  reg processing;

  // Current input character
  wire [7:0] curr_char = text_input[idx];

  // Synchronous logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state             <= IDLE;
      idx               <= 6'd0;
      char_idx          <= 5'd0;
      str_idx           <= 3'd0;
      string_count      <= 3'd0;
      done              <= 1'b0;
      processing        <= 1'b0;
      extracted_strings <= '{default:8'd0};
    end else begin
      // Default stay values
      done <= 1'b0;

      // Start processing on start assertion when not already processing
      if (start && !processing) begin
        processing        <= 1'b1;
        state             <= IDLE;
        idx               <= 6'd0;
        char_idx          <= 5'd0;
        str_idx           <= 3'd0;
        string_count      <= 3'd0;
        extracted_strings <= '{default:8'd0};
      end else if (processing && !done) begin
        // Process one character per cycle

        // Handle quote detection and state transitions
        if (curr_char == 8'h22) begin // '"'
          if (state == IDLE) begin
            // Starting a new quoted region, only if capacity available
            if (string_count < 3'd8) begin
              state    <= CAPTURING;
              char_idx <= 5'd0;
              // str_idx already points to next slot (string_count)
            end
            // If no capacity, ignore further quotes; will terminate at end
          end else begin
            // Closing quote
            state <= IDLE;
            if (string_count < 3'd8) begin
              // We just finished one string; count it
              string_count <= string_count + 3'd1;
              if (string_count < 3'd7) begin
                str_idx <= string_count + 3'd1;
              end
            end
            char_idx <= 5'd0;
          end
        end else begin
          // Non-quote character handling
          if (state == CAPTURING) begin
            // Store character if within 16-byte limit and capacity not exceeded
            if ((string_count < 3'd8) && (char_idx < 5'd16)) begin
              extracted_strings[str_idx][char_idx] <= curr_char;
              char_idx <= char_idx + 5'd1;
            end
            // If char_idx >=16, truncate (do nothing)
          end
        end

        // Advance input index or finish
        if (idx == 6'd63 || string_count == 3'd8) begin
          // If ended while still in CAPTURING without closing quote,
          // we do not increment string_count (incomplete segment)
          processing <= 1'b0;
          done       <= 1'b1;
        end else begin
          idx <= idx + 6'd1;
        end
      end
    end
  end

endmodule