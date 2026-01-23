module wordz_matcher (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input valid_in,
  output reg match,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SCANNING,
    COMPLETE
  } state_t;

  state_t state;
  reg [3:0] char_count;
  reg in_word;
  reg has_z;
  reg match_found;

  // Character classification
  function logic is_alphanumeric(input [7:0] c);
    return (c >= 8'h41 && c <= 8'h5A) || // A-Z
           (c >= 8'h61 && c <= 8'h7A) || // a-z
           (c >= 8'h30 && c <= 8'h39) || // 0-9
           (c == 8'h5F);                // _
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      char_count <= 0;
      in_word <= 0;
      has_z <= 0;
      match_found <= 0;
      match <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SCANNING;
            char_count <= 0;
            in_word <= 0;
            has_z <= 0;
            match_found <= 0;
            match <= 0;
            done <= 0;
          end
        end

        SCANNING: begin
          if (valid_in) begin
            // Check for 'z' or 'Z'
            if (char_in == 8'h7A || char_in == 8'h5A) begin
              has_z <= 1;
            end

            // Word boundary detection
            if (is_alphanumeric(char_in)) begin
              in_word <= 1;
            end else begin
              if (in_word) begin
                // End of word - check if we had 'z'
                if (has_z) begin
                  match_found <= 1;
                  match <= 1;
                end
                in_word <= 0;
                has_z <= 0;
              end
            end

            // Increment character count
            char_count <= char_count + 1;

            // Check if we've processed 16 characters
            if (char_count == 15) begin
              state <= COMPLETE;
              done <= 1;
              // Final word check if we're still in a word
              if (in_word && has_z) begin
                match_found <= 1;
                match <= 1;
              end
            end
          end
        end

        COMPLETE: begin
          // Stay in complete state until reset
          done <= 1;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule