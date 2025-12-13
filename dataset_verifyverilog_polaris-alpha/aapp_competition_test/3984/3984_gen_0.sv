module string_game_winner(
  input clk,
  input rst_n,
  input start,
  input [3:0] str_len,
  input [7:0] char_in,
  output reg [15:0] results,
  output reg done
);

  reg [3:0] count;
  reg [7:0] running_min;
  reg [3:0] latched_len;
  reg processing;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      results      <= 16'b0;
      done         <= 1'b0;
      count        <= 4'd0;
      running_min  <= 8'd122; // 'z'
      latched_len  <= 4'd0;
      processing   <= 1'b0;
    end else begin
      if (start) begin
        // Start new processing
        results      <= 16'b0;
        done         <= 1'b0;
        latched_len  <= str_len;
        count        <= 4'd0;
        running_min  <= 8'd122; // 'z'
        processing   <= 1'b1;
      end else if (processing) begin
        if (count < latched_len) begin
          // Determine winner for current index = count
          if ((count != 4'd0) && (char_in > running_min)) begin
            results[count] <= 1'b1; // Ann wins
          end else begin
            results[count] <= 1'b0; // Mike wins
          end

          // Update running minimum
          if (char_in < running_min) begin
            running_min <= char_in;
          end else begin
            running_min <= running_min;
          end

          // Increment counter
          count <= count + 4'd1;

          // Clear bits beyond latched_len-1 (ensure unused bits 0)
          // Existing zeros are preserved; no change required here.
        end

        // Check if processing is complete (str_len + 1 latency from start asserted)
        if (count >= latched_len) begin
          done       <= 1'b1;
          processing <= 1'b0;
        end
      end else begin
        // Hold results and done when not processing and not starting
        results     <= results;
        done        <= done;
        count       <= count;
        running_min <= running_min;
        latched_len <= latched_len;
        processing  <= processing;
      end
    end
  end

endmodule