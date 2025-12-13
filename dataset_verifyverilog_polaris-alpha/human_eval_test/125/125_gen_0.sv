module word_splitter(
  input  clk,
  input  rst_n,
  input  start,
  input  [127:0] text_in,
  output reg [4:0] result,
  output reg       done
);

  // Internal registers
  reg [3:0]   idx;            // 0..15
  reg [4:0]   splitter_cnt;   // count of spaces/commas
  reg [4:0]   odd_lower_cnt;  // count of lowercase letters with odd (ch - 'a')
  reg         splitter_seen;  // flag if any splitter found
  reg [127:0] text_latched;   // latched input text
  reg         busy;           // processing flag

  // Current character extraction
  wire [7:0] cur_char = text_latched[127 - idx*8 -: 8];

  // Detect splitter: space(0x20) or comma(0x2C)
  wire is_splitter = (cur_char == 8'h20) || (cur_char == 8'h2C);

  // Detect lowercase a-z
  wire is_lowercase = (cur_char >= 8'h61) && (cur_char <= 8'h7A);

  // (ch - 'a') is odd if bit0 of (cur_char - 8'h61) is 1
  wire odd_pos = (cur_char[0] ^ 1'b1); // Equivalent to (cur_char - 'a')[0]
  // Explanation: (cur_char - 0x61)[0] = cur_char[0] ^ 1, since 0x61 is odd.
  // So odd_pos is 1 when (cur_char - 'a') LSB == 1.

  wire count_odd_lower = is_lowercase && odd_pos;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      idx           <= 4'd0;
      splitter_cnt  <= 5'd0;
      odd_lower_cnt <= 5'd0;
      splitter_seen <= 1'b0;
      text_latched  <= 128'd0;
      busy          <= 1'b0;
      result        <= 5'd0;
      done          <= 1'b0;
    end else begin
      done <= 1'b0; // default

      if (start && !busy) begin
        // Latch input and initialize for new operation
        text_latched  <= text_in;
        idx           <= 4'd0;
        splitter_cnt  <= 5'd0;
        odd_lower_cnt <= 5'd0;
        splitter_seen <= 1'b0;
        busy          <= 1'b1;
      end else if (busy) begin
        // Process one character per cycle for 16 cycles

        // Update splitter related counters
        if (is_splitter)
          splitter_cnt <= splitter_cnt + 5'd1;

        // Track if any splitter has been seen
        if (is_splitter)
          splitter_seen <= 1'b1;

        // Update odd-lowercase counter
        if (count_odd_lower)
          odd_lower_cnt <= odd_lower_cnt + 5'd1;

        // Advance index
        if (idx == 4'd15) begin
          // Completed 16 characters; compute result next
          busy   <= 1'b0;

          // Choose result based on presence of splitters
          if (splitter_seen)
            result <= splitter_cnt + 5'd1; // words = splitters + 1
          else
            result <= odd_lower_cnt;

          done <= 1'b1; // Assert for this cycle (17th cycle after start)
        end else begin
          idx <= idx + 4'd1;
        end
      end
    end
  end

endmodule