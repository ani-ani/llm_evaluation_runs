module photo_filter(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] heights [0:15],
  output reg valid,
  output reg processing
);

  // Internal storage for heights and parameters
  reg [15:0] heights_reg [0:15];
  reg [3:0]  n_reg;

  // Max-right array and running max for reverse scan
  reg [15:0] max_right [0:15];
  reg [15:0] cur_max_right;

  // For scanning i as 'me'
  reg [15:0] max_left;
  reg [3:0]  step_count;
  reg        found;

  // Pipeline: on start, latch inputs and initialize
  integer idx;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Async reset of main control
      processing     <= 1'b0;
      valid          <= 1'b0;
      found          <= 1'b0;
      step_count     <= 4'd0;
      n_reg          <= 4'd0;
      max_left       <= 16'd0;
      cur_max_right  <= 16'd0;
      for (idx = 0; idx < 16; idx = idx + 1) begin
        heights_reg[idx] <= 16'd0;
        max_right[idx]   <= 16'd0;
      end
    end else begin
      // Default hold
      valid <= valid;

      // Start pulse: load data and begin processing
      if (start && !processing) begin
        n_reg      <= n;
        for (idx = 0; idx < 16; idx = idx + 1) begin
          heights_reg[idx] <= heights[idx];
        end
        // Initialize reverse max computation
        if (n > 0) begin
          cur_max_right       <= 16'd0;
          max_right[15]       <= 16'd0; // unused when i >= n_reg
        end else begin
          cur_max_right       <= 16'd0;
        end
        // Initialize forward scan
        max_left   <= 16'd0;
        found      <= 1'b0;
        step_count <= 4'd0;
        processing <= 1'b1;
        valid      <= 1'b0;
      end else if (processing) begin
        // We have fixed 16 cycles of processing

        // 1) Reverse-scan to build max_right for indices within n_reg
        // Use mirrored index from end toward 0
        // step_count runs 0..15, so rev_idx runs from 15..0
        // Only meaningful for rev_idx < n_reg
        begin : gen_reverse
          reg [3:0] rev_idx;
          rev_idx = 4'd15 - step_count;

          if (rev_idx < n_reg) begin
            // For position rev_idx, max_right[rev_idx] is the maximum height to its right
            // cur_max_right always holds max of heights to the right of current rev_idx
            max_right[rev_idx] <= cur_max_right;
            // Update running max with current height for use by next (left) index
            if (heights_reg[rev_idx] > cur_max_right)
              cur_max_right <= heights_reg[rev_idx];
          end
        end

        // 2) Forward-scan: evaluate position i = step_count as 'me'
        begin : gen_forward
          reg [3:0] i;
          i = step_count;

          if (i < n_reg) begin
            // Check if there exists left taller (max_left > me)
            // and a right taller than both left max and me (max_right[i] > max_left)
            if (!found) begin
              if ((max_left > heights_reg[i]) && (max_right[i] > max_left)) begin
                found <= 1'b1;
              end
            end
            // Update max_left to include current position for next i
            if (heights_reg[i] > max_left)
              max_left <= heights_reg[i];
          end
        end

        // 3) Step control: 16 fixed cycles
        if (step_count == 4'd15) begin
          // Done after 16 cycles
          processing <= 1'b0;
          valid      <= found;
          step_count <= 4'd0;
        end else begin
          step_count <= step_count + 4'd1;
        end
      end
    end
  end

endmodule