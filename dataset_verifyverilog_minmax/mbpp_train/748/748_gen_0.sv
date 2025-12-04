module space_inserter (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in [0:15],
  input [3:0] length,
  output reg [7:0] char_out [0:31],
  output reg [4:0] out_length,
  output reg done
);

  // State machine
  typedef enum logic {IDLE = 1'b0, RUN = 1'b1} state_t;
  state_t state, next_state;

  // Indices and control
  reg [4:0] in_idx;   // 0..15
  reg [4:0] out_idx;  // 0..31
  reg prev_was_space; // 1 if previous output char was a space

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      in_idx <= 5'd0;
      out_idx <= 5'd0;
      out_length <= 5'd0;
      done <= 1'b0;
      prev_was_space <= 1'b1; // treat as space so no leading space is inserted
      // Initialize output to all spaces (0x20)
      for (int j = 0; j < 32; j++) char_out[j] <= 8'h20;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          in_idx <= 5'd0;
          out_idx <= 5'd0;
          out_length <= 5'd0;
          done <= 1'b0;
          prev_was_space <= 1'b1; // reset flag for new run
          for (int j = 0; j < 32; j++) char_out[j] <= 8'h20; // unused positions = space
        end

        RUN: begin
          if (in_idx < length) begin
            // Current input char
            reg [7:0] c;
            c = char_in[in_idx];

            // Check conditions
            // Capital letter: A-Z -> ASCII 65..90
            // Previous was space: prev_was_space indicates preceding output char was a space
            if ( (c >= 8'd65 && c <= 8'd90) && !prev_was_space ) begin
              // Insert space before current char if room in output
              if (out_idx < 5'd31) begin
                char_out[out_idx] <= 8'd32; // space
                out_idx <= out_idx + 1;
              end
              // Output current char if room
              if (out_idx < 5'd31) begin
                char_out[out_idx] <= c;
                out_idx <= out_idx + 1;
                prev_was_space <= 1'b1; // we just wrote a space before c, so prev is space
              end else begin
                // No space to write current char; keep prev_was_space as is
                prev_was_space <= prev_was_space; // no change
              end
            end else begin
              // Output current char if room
              if (out_idx < 5'd31) begin
                char_out[out_idx] <= c;
                out_idx <= out_idx + 1;
                prev_was_space <= (c == 8'd32); // true if just wrote a space
              end else begin
                prev_was_space <= (c == 8'd32); // true if char is a space
              end
            end

            in_idx <= in_idx + 1;
            done <= 1'b0; // still processing
            out_length <= out_length; // keep until end

          end else begin
            // Finished processing all input chars
            done <= 1'b1;
            out_length <= out_idx;
            // prev_was_space stays as-is; not needed after done
          end
        end

        default: begin
          // Should not occur; keep safe values
          done <= done;
          out_length <= out_length;
        end
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: next_state = start ? RUN : IDLE;
      RUN: begin
        if (in_idx >= length) next_state = IDLE;
        else next_state = RUN;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule
