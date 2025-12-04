module remove_parentheses(
  input        clk,
  input        rst_n,
  input        start,
  input  [127:0] str_in,
  output reg [127:0] str_out,
  output reg   done
);

  // State encoding
  localparam IDLE       = 1'b0;
  localparam PROCESSING = 1'b1;

  reg        state, next_state;
  reg        in_paren;          // 1 when currently skipping until first ')'
  reg [4:0]  in_idx;            // 0..15 for input characters
  reg [4:0]  out_idx;           // 0..16 for output write position

  wire [7:0] curr_char;

  // MSB-first: character 0 is bits [127:120], then [119:112], ... [7:0]
  assign curr_char = str_in[127 - in_idx*8 -: 8];

  // Next-state logic (combinational)
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
      end
      PROCESSING: begin
        // After processing 16 characters (in_idx == 16) go back to IDLE
        if (in_idx == 5'd16)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      in_paren <= 1'b0;
      in_idx   <= 5'd0;
      out_idx  <= 5'd0;
      str_out  <= 128'd0;
      done     <= 1'b0;
    end else begin
      state <= next_state;
      done  <= 1'b0; // default, will be set when processing completes

      case (state)
        IDLE: begin
          // Wait for start rising edge; on start, initialize processing
          if (start) begin
            in_paren <= 1'b0;
            in_idx   <= 5'd0;
            out_idx  <= 5'd0;
            str_out  <= 128'd0; // clear output (zero padding baseline)
          end
        end

        PROCESSING: begin
          if (in_idx < 5'd16) begin
            // Process current character
            if (!in_paren) begin
              // Not currently inside parentheses
              if (curr_char == 8'h28) begin
                // Found '(': enter paren skip mode; do not output it
                in_paren <= 1'b1;
              end else if (curr_char == 8'h29) begin
                // Found ')' while not in_paren: just skip it
                // in_paren remains 0
              end else begin
                // Normal character: copy to output if space remains
                if (out_idx < 5'd16) begin
                  // Place at MSB-first position corresponding to out_idx
                  str_out[127 - out_idx*8 -: 8] <= curr_char;
                  out_idx <= out_idx + 5'd1;
                end
              end
            end else begin
              // Currently skipping until first ')'
              if (curr_char == 8'h29) begin
                // Found closing ')': exit paren mode
                in_paren <= 1'b0;
              end
              // All characters including this ')' are skipped
            end

            // Advance input index
            in_idx <= in_idx + 5'd1;

            // If this was the 16th character (in_idx becomes 16 next), we are done next cycle
            if (in_idx == 5'd15) begin
              done <= 1'b1;
            end
          end else begin
            // Safety: if in_idx already 16, hold values (will transition to IDLE)
            done <= 1'b1;
          end
        end
      endcase
    end
  end

endmodule