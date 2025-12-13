module snake_to_camel (
  input        clk,
  input        rst_n,
  input        start,
  input  [79:0] snake_str,
  input  [3:0] length,
  output reg [79:0] camel_str,
  output reg   done
);

  typedef enum logic [1:0] {
    IDLE       = 2'b00,
    PROCESSING = 2'b01,
    DONE       = 2'b10
  } state_t;

  state_t state, next_state;

  reg [3:0] in_idx;         // 0..9 input index (characters)
  reg [3:0] out_idx;        // 0..9 output index (result chars)
  reg       capitalize_next;

  wire [7:0] current_char;

  // Extract current input character; snake_str[79:72] is index 0, down to [7:0] index 9
  assign current_char = snake_str[79 - (in_idx*8) -: 8];

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= IDLE;
      camel_str        <= 80'b0;
      done             <= 1'b0;
      in_idx           <= 4'd0;
      out_idx          <= 4'd0;
      capitalize_next  <= 1'b1; // First character should be capitalized
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            camel_str       <= 80'b0;    // Clear output on new start
            in_idx          <= 4'd0;
            out_idx         <= 4'd0;
            capitalize_next <= 1'b1;    // Capitalize first non-underscore
          end
        end

        PROCESSING: begin
          done <= 1'b0;

          if (in_idx < 4'd10 && in_idx < length) begin
            if (current_char == 8'h5F) begin
              // Underscore: do not emit, just set capitalize flag for next character
              capitalize_next <= 1'b1;
            end else begin
              // Non-underscore character: possibly capitalize and emit
              reg [7:0] out_char;
              out_char = current_char;

              if (capitalize_next) begin
                // Capitalize if in 'a'-'z'
                if (current_char >= 8'h61 && current_char <= 8'h7A)
                  out_char = current_char - 8'd32;
              end

              // Write output character at out_idx
              if (out_idx < 4'd10) begin
                camel_str[79 - (out_idx*8) -: 8] <= out_char;
                out_idx <= out_idx + 4'd1;
              end

              capitalize_next <= 1'b0;
            end

            in_idx <= in_idx + 4'd1;
          end else begin
            // Either processed 'length' chars or reached 10 cycles
            // Ensure remaining bytes are zero-padded
            if (out_idx < 4'd10) begin
              integer k;
              for (k = out_idx; k < 10; k = k + 1) begin
                camel_str[79 - (k*8) -: 8] <= 8'h00;
              end
            end
          end
        end

        DONE: begin
          // Pulse done high in DONE state
          done <= 1'b1;
        end

        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

  // Next-state logic: fixed 10-cycle processing from start
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
      end

      PROCESSING: begin
        // Stay in PROCESSING for 10 cycles after start (in_idx 0..9), then go DONE
        // We rely on in_idx reaching 10 as the indicator
        if (in_idx >= 4'd10)
          next_state = DONE;
        else
          next_state = PROCESSING;
      end

      DONE: begin
        // One-cycle done pulse, then back to IDLE
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule