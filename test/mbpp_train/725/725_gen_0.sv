module quote_extractor(
  input  wire        clk,
  input  wire        rst_n,
  input  wire        start,
  input  wire [127:0] text,
  output reg  [127:0] results,
  output reg  [1:0]  valid
);

  // FSM state encoding
  typedef enum logic [1:0] {
    IDLE      = 2'b00,
    SCANNING  = 2'b01,
    IN_QUOTE  = 2'b10
  } state_t;

  state_t state, next_state;

  // Counters and control
  reg [4:0]  idx;              // 0..16 (17 cycles: 16 chars + 1 extra)
  reg        in_quote;
  reg [1:0]  quote_count;      // number of completed quoted strings (0..2)

  // Per-string write positions (byte indices within 64-bit regions)
  reg [2:0]  pos0;             // 0..7
  reg [2:0]  pos1;             // 0..7

  // Extract current byte based on idx (byte 0 is LSB text[7:0])
  wire [7:0] curr_byte;
  assign curr_byte = text[8*idx +: 8];

  // State register and sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      idx         <= 5'd0;
      in_quote    <= 1'b0;
      quote_count <= 2'd0;
      pos0        <= 3'd0;
      pos1        <= 3'd0;
      results     <= 128'd0;
      valid       <= 2'b00;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (start) begin
            // Initialize for new scan
            idx         <= 5'd0;
            in_quote    <= 1'b0;
            quote_count <= 2'd0;
            pos0        <= 3'd0;
            pos1        <= 3'd0;
            results     <= 128'd0;
            valid       <= 2'b00;
          end
        end

        SCANNING: begin
          if (idx < 5'd16) begin
            // Process one character per cycle
            if (curr_byte == 8'h22) begin
              // Opening quote found
              if (!in_quote && quote_count < 2) begin
                in_quote <= 1'b1;
              end
            end
            idx <= idx + 5'd1;
          end
        end

        IN_QUOTE: begin
          if (idx < 5'd16) begin
            if (curr_byte == 8'h22) begin
              // Closing quote
              in_quote    <= 1'b0;
              quote_count <= (quote_count < 2) ? (quote_count + 2'd1) : quote_count;
            end else begin
              // Store character into appropriate result buffer if space remains
              if (quote_count == 2'd0) begin
                if (pos0 < 3'd8) begin
                  results[8*pos0 +: 8] <= curr_byte;
                  pos0 <= pos0 + 3'd1;
                end
              end else if (quote_count == 2'd1) begin
                if (pos1 < 3'd8) begin
                  results[64 + 8*pos1 +: 8] <= curr_byte;
                  pos1 <= pos1 + 3'd1;
                end
              end
            end
            idx <= idx + 5'd1;
          end
        end

        default: begin
          // Should not occur; safe defaults
          state <= IDLE;
        end
      endcase

      // After 16 characters processed, finalize valid bits in the 17th cycle
      if (idx == 5'd16) begin
        valid[0] <= (pos0 != 3'd0); // First string valid if any char captured
        valid[1] <= (pos1 != 3'd0); // Second string valid if any char captured
      end
    end
  end

  // Next-state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = SCANNING;
      end

      SCANNING: begin
        if (idx >= 5'd16) begin
          next_state = IDLE; // Done after 17th cycle (handled in seq logic)
        end else if (curr_byte == 8'h22 && !in_quote && quote_count < 2) begin
          next_state = IN_QUOTE;
        end
      end

      IN_QUOTE: begin
        if (idx >= 5'd16) begin
          next_state = IDLE; // Done after processing
        end else if (curr_byte == 8'h22) begin
          // Closing quote -> go back to scanning
          next_state = SCANNING;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule