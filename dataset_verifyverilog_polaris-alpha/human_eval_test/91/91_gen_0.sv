module boredom_counter (
  input        clk,
  input        rst_n,
  input        start,
  input  [3:0] str_len,
  input  [15:0][7:0] str_data,
  output reg [2:0] count,
  output reg       done
);

  // Internal registers
  reg [4:0] idx;                  // 0-16 (needs 5 bits)
  reg       in_sentence_start;    // 1 if next valid char is at sentence start

  // Delimiter detection function
  function automatic is_delim;
    input [7:0] ch;
    begin
      is_delim = (ch == 8'h2E) || // '.'
                 (ch == 8'h3F) || // '?'
                 (ch == 8'h21);   // '!'
    end
  endfunction

  // Synchronous logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count            <= 3'd0;
      done             <= 1'b0;
      idx              <= 5'd0;
      in_sentence_start<= 1'b1;   // Start of string considered sentence start
    end else begin
      if (start) begin
        // Initialize processing on start
        count            <= 3'd0;
        done             <= 1'b0;
        idx              <= 5'd0;
        in_sentence_start<= 1'b1;
      end else if (!done) begin
        // Process one character per cycle until 16 cycles are completed
        if (idx < 5'd16) begin
          // Only process if within declared string length
          if (idx < {1'b0,str_len}) begin
            // Fetch current character
            reg [7:0] ch;
            ch = str_data[idx];

            if (in_sentence_start) begin
              // Check for 'I' at sentence start
              if (ch == 8'h49) begin
                if (count != 3'd7)
                  count <= count + 3'd1;
              end
              // After first non-delimiter char, we are no longer at start
              if (!is_delim(ch)) begin
                in_sentence_start <= 1'b0;
              end
            end else begin
              // Track delimiters to mark next sentence start
              if (is_delim(ch)) begin
                in_sentence_start <= 1'b1;
              end
            end
          end

          // Increment index each cycle
          idx <= idx + 5'd1;
        end

        // After exactly 16 cycles, assert done
        if (idx == 5'd15) begin
          done <= 1'b1;
        end
      end
    end
  end

endmodule