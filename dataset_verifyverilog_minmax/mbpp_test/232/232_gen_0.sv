module top_n_finder(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [127:0] data,
  output reg [127:0] result,
  output reg done
);

  // Internal storage for top-N signed 8-bit values (descending order).
  // Index 0 holds the largest value.
  logic signed [7:0] cand [0:15];
  logic [3:0] count;    // Number of elements processed (0..16)
  logic started;        // Latch for one-shot start
  logic [3:0] i;        // Loop/index variable
  logic found;          // Indicator that a valid slot is found for insertion
  logic [3:0] j;        // Temporary indices
  logic signed [7:0] cur; // Current element being inserted
  logic [3:0] k;        // Packing loop index

  // Process always block (sequential, async reset)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset internal state and outputs
      for (i = 0; i < 16; i = i + 1) begin
        cand[i] <= 8'd0;
      end
      count <= 4'd0;
      started <= 1'b0;
      result <= 128'd0;
      done <= 1'b0;
    end else begin
      // One-shot start latch (no need to re-assert during the 16 cycles)
      if (start && !started) begin
        started <= 1'b1;
        // Initialize candidates to 0 (ensures top-n will be properly found and unused bytes will be zero)
        for (i = 0; i < 16; i = i + 1) begin
          cand[i] <= 8'd0;
        end
        count <= 4'd0;
        done <= 1'b0;
        result <= 128'd0;
      end

      if (started && (count < 4'd16)) begin
        // Extract the current element from data (LSB is elem0)
        cur <= data[8*count +: 8];
        found <= 1'b0;

        // Find where to insert cur among the top-n (descending). We only compare up to n-1.
        for (i = 0; i < 16; i = i + 1) begin
          if (!found) begin
            if (i < n) begin
              // Compare signed 8-bit values; allow ties to place newer value earlier
              if (cur > cand[i]) begin
                // Insert here and shift the rest to the right (towards larger indices)
                for (j = 4'd15; j > i; j = j - 1) begin
                  if (j > 4'd0) begin
                    cand[j] <= cand[j - 1];
                  end
                end
                cand[i] <= cur;
                found <= 1'b1;
              end
            end
          end
        end
        // If not found and we have less than n elements, the list is initialized with 0,
        // so the first n elements will fill in naturally (largest first among the first n).

        count <= count + 4'd1;
        done <= 1'b0;        // Still processing
        result <= result;    // Keep result stable until done
      end else if (started && (count == 4'd16)) begin
        // Finished: pack the top-n values into result (descending), LSB-aligned.
        for (k = 0; k < 16; k = k + 1) begin
          if (k < n) begin
            // Place cand[k] (largest at k=0) into byte k (LSB-aligned)
            result[8*k +: 8] <= cand[k];
          end else begin
            result[8*k +: 8] <= 8'd0; // Unused elements zeroed
          end
        end
        done <= 1'b1;
        // Hold done until a new start is issued; then the above reset-like init will clear it.
      end else begin
        // Waiting for start
        done <= done;
        result <= result;
      end
    end
  end
endmodule