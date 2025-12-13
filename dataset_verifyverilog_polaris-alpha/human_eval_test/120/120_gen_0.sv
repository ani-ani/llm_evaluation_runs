module top_k_sorted(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] arr_size,
  input  [2:0] k_val,
  input  signed [11:0] arr_data [7:0],
  output reg [95:0] result,
  output reg        done,
  output            valid
);

  // Internal storage
  reg signed [11:0] data_reg [7:0];
  reg [2:0]         size_reg;
  reg [2:0]         k_reg;

  // Sorting array
  reg signed [11:0] sort_arr [7:0];

  // Pipeline counter (0-15) for fixed latency
  reg [4:0] cycle_cnt;
  reg       busy;

  assign valid = done;

  integer i, j;

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      result    <= 96'd0;
      done      <= 1'b0;
      busy      <= 1'b0;
      cycle_cnt <= 5'd0;
      size_reg  <= 3'd0;
      k_reg     <= 3'd0;
      for (i = 0; i < 8; i = i + 1) begin
        data_reg[i] <= 12'sd0;
        sort_arr[i] <= 12'sd0;
      end
    end else begin
      // Default done low except when asserted at specific cycle
      done <= 1'b0;

      // Start pulse handling (only when not busy)
      if (start && !busy) begin
        busy      <= 1'b1;
        cycle_cnt <= 5'd0;

        // Capture configuration
        size_reg <= (arr_size == 3'd0) ? 3'd1 : arr_size; // safety: min size 1
        k_reg    <= (k_val   == 3'd0) ? 3'd1 : k_val;    // safety: min k 1

        // Capture input array
        for (i = 0; i < 8; i = i + 1) begin
          data_reg[i] <= arr_data[i];
          sort_arr[i] <= arr_data[i];
        end
      end else if (busy) begin
        // Fixed-latency pipeline: 16 cycles total
        cycle_cnt <= cycle_cnt + 5'd1;

        // Perform in-place bubble sort (always on first size_reg elements)
        // Signed comparisons
        for (i = 0; i < 7; i = i + 1) begin
          for (j = i + 1; j < 8; j = j + 1) begin
            if ((i < size_reg) && (j < size_reg)) begin
              if (sort_arr[i] > sort_arr[j]) begin
                // swap
                reg signed [11:0] tmp;
                tmp          = sort_arr[i];
                sort_arr[i]  = sort_arr[j];
                sort_arr[j]  = tmp;
              end
            end
          end
        end

        // At cycle 15 (16th cycle, counting from 0), generate result and assert done
        if (cycle_cnt == 5'd15) begin
          // Build result with top-k smallest (ascending) left-aligned
          // Unused positions filled with 0
          reg [95:0] next_result;
          reg [2:0]  eff_k;
          integer    idx;

          // Ensure k_reg <= size_reg (as required), clamp just in case
          if (k_reg <= size_reg)
            eff_k = k_reg;
          else
            eff_k = size_reg;

          // Initialize result to 0
          next_result = 96'd0;

          // Pack sorted top-k into result[12*idx +: 12]
          for (idx = 0; idx < 8; idx = idx + 1) begin
            if (idx < eff_k)
              next_result[12*idx +: 12] = sort_arr[idx];
            else
              next_result[12*idx +: 12] = 12'sd0;
          end

          result <= next_result;
          done   <= 1'b1;
          busy   <= 1'b0;
        end
      end
    end
  end

endmodule