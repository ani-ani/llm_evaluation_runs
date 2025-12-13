module bracket_checker(
  input        clk,
  input        rst_n,
  input        start,
  input  [7:0] brackets,
  output reg   result,
  output reg   done
);

  reg [3:0]  idx;
  reg signed [4:0] counter; // can represent negative values
  reg        processing;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      idx        <= 4'd0;
      counter    <= 5'sd0;
      processing <= 1'b0;
      result     <= 1'b0;
      done       <= 1'b0;
    end else begin
      if (start && !processing && !done) begin
        // Start new operation
        processing <= 1'b1;
        idx        <= 4'd0;
        counter    <= 5'sd0;
        result     <= 1'b0;
        done       <= 1'b0;
      end else if (processing) begin
        // Process one character per cycle from MSB to LSB (left to right)
        if (brackets[7-idx] == 8'h28) begin
          // '('
          counter <= counter + 5'sd1;
        end else if (brackets[7-idx] == 8'h29) begin
          // ')'
          counter <= counter - 5'sd1;
        end

        // Check for early invalid (counter < 0)
        if ((brackets[7-idx] == 8'h29 && counter - 5'sd1 < 5'sd0) ||
            (brackets[7-idx] != 8'h29 && brackets[7-idx] != 8'h28 && counter < 5'sd0)) begin
          // If decrement causes negative, abort
          processing <= 1'b0;
          done       <= 1'b1;
          result     <= 1'b0;
        end else begin
          // Increment index and check completion
          if (idx == 4'd7) begin
            // Last character processed this cycle
            processing <= 1'b0;
            done       <= 1'b1;
            // Evaluate validity based on updated counter
            if (brackets[7-idx] == 8'h28)
              result <= (counter + 5'sd1 == 5'sd0);
            else if (brackets[7-idx] == 8'h29)
              result <= (counter - 5'sd1 == 5'sd0);
            else
              result <= (counter == 5'sd0);
          end else begin
            idx <= idx + 4'd1;
          end
        end
      end

      // Clear done when a new start is issued after completion
      if (start && done && !processing) begin
        done <= 1'b0;
      end
    end
  end

endmodule