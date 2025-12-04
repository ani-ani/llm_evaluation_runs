module snake_to_camel (
  input clk,
  input rst_n,
  input start,
  input [127:0] data_in,
  output reg [127:0] data_out,
  output reg done
);

  reg [3:0] cnt;                 // 0..15
  reg [3:0] cnt_next;
  reg state;                     // 0=idle, 1=processing
  reg state_next;
  reg [1:0] udsc_cnt;            // number of underscores seen so far (max 2)
  reg [1:0] udsc_cnt_next;
  reg capitalize_next;           // 1 -> capitalize this character
  reg capitalize_next_next;
  reg [7:0] buffer [0:15];       // 16-byte shift buffer (left-to-right)
  reg [7:0] buffer_next [0:15];

  integer i;

  // State transition logic
  always @(*) begin
    // Defaults
    cnt_next = cnt;
    state_next = state;
    udsc_cnt_next = udsc_cnt;
    capitalize_next_next = capitalize_next;
    for (i = 0; i < 16; i = i + 1) begin
      buffer_next[i] = buffer[i];
    end
    if (!rst_n) begin
      // Asynchronous reset handling below in sequential block.
    end else begin
      if (state == 1'b0) begin
        if (start) begin
          // Load new input at the start of cycle 0
          for (i = 0; i < 16; i = i + 1) begin
            buffer_next[i] = data_in[127 - 8*i -: 8];
          end
          cnt_next = 4'd0;
          state_next = 1'b1;
          udsc_cnt_next = 2'b0;
          capitalize_next_next = 1'b1; // Capitalize first character
        end else begin
          // Remain idle
          cnt_next = 4'd0;
          state_next = 1'b0;
          udsc_cnt_next = 2'b0;
          capitalize_next_next = 1'b0;
        end
      end else begin // processing
        // Shift buffer left by 1 byte, insert new byte from input at [15]
        for (i = 0; i < 15; i = i + 1) begin
          buffer_next[i] = buffer[i + 1];
        end
        buffer_next[15] = data_in[127 - 8*15 -: 8];

        cnt_next = cnt + 1'b1;
        if (cnt == 4'd15) begin
          state_next = 1'b0;
        end else begin
          state_next = 1'b1;
        end

        // Update capitalization logic based on current buffer[0]
        if (buffer[0] == 8'h5F && udsc_cnt < 2'd2) begin
          // Underscore -> skip, mark next character for capitalization (count this underscore)
          udsc_cnt_next = udsc_cnt + 1'b1;
          capitalize_next_next = 1'b1;
        end else begin
          // Normal character; consume capitalize_next flag
          udsc_cnt_next = udsc_cnt;
          capitalize_next_next = 1'b0;
        end
      end
    end
  end

  // Sequential block: state, counters, buffer, outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= 4'd0;
      state <= 1'b0;
      udsc_cnt <= 2'b0;
      capitalize_next <= 1'b0;
      done <= 1'b0;
      data_out <= 128'b0;
      for (i = 0; i < 16; i = i + 1) begin
        buffer[i] <= 8'b0;
      end
    end else begin
      // Update state and buffer
      cnt <= cnt_next;
      state <= state_next;
      udsc_cnt <= udsc_cnt_next;
      capitalize_next <= capitalize_next_next;
      for (i = 0; i < 16; i = i + 1) begin
        buffer[i] <= buffer_next[i];
      end

      // Output assembly (valid only in the last cycle of processing)
      if (state_next == 1'b1) begin
        // During processing, assemble data_out byte-by-byte using current buffer[0]
        if (cnt < 4'd16) begin
          if (buffer[0] == 8'h5F) begin
            // Skip underscores
            data_out <= {data_out[119:0], 8'b0}; // shift left, insert 0
          end else begin
            // Capitalize rule + keep non-letters unchanged
            if (capitalize_next && buffer[0] >= 8'h61 && buffer[0] <= 8'h7A) begin
              // lowercase -> uppercase
              data_out <= {data_out[119:0], buffer[0] - 8'h20};
            end else begin
              data_out <= {data_out[119:0], buffer[0]};
            end
          end
        end
        done <= 1'b0;
      end else begin
        // When finishing (at cycle 16), done asserts and data_out already contains the result
        done <= 1'b1;
      end
    end
  end
endmodule
