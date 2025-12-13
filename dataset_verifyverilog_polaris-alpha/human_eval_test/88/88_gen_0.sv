module smart_sort(
  input              clk,
  input              rst_n,
  input              start,
  input      [7:0]   array_in [0:7],
  input      [2:0]   num_elements,
  output reg [7:0]   sorted_array [0:7],
  output reg         done
);

  // Internal registers
  reg [7:0]  work_array [0:7];
  reg [2:0]  n_reg;                 // latched num_elements (1-8)
  reg        order_asc;             // 1: ascending, 0: descending
  reg [5:0]  total_steps;           // N*(N-1)/2
  reg [5:0]  step_cnt;              // remaining comparison steps
  reg        busy;                  // sorting in progress

  // Bubble sort index tracking
  reg [2:0]  i_idx;                 // outer loop index
  reg [2:0]  j_idx;                 // inner loop index

  // Control for start edge
  reg start_d;
  wire start_pulse = start & ~start_d;

  // Sum wires
  reg [8:0] sum;                    // 9-bit to avoid overflow

  integer k;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous reset
      done      <= 1'b0;
      busy      <= 1'b0;
      n_reg     <= 3'd0;
      order_asc <= 1'b0;
      total_steps <= 6'd0;
      step_cnt  <= 6'd0;
      i_idx     <= 3'd0;
      j_idx     <= 3'd0;
      start_d   <= 1'b0;
      sum       <= 9'd0;
      for (k = 0; k < 8; k = k + 1) begin
        work_array[k]   <= 8'd0;
        sorted_array[k] <= 8'd0;
      end
    end else begin
      // Register start to form pulse
      start_d <= start;

      if (start_pulse && !busy) begin
        // Latch number of elements (ensure at least 1)
        n_reg <= (num_elements == 3'd0) ? 3'd1 : num_elements;

        // Copy input array into work_array
        for (k = 0; k < 8; k = k + 1) begin
          work_array[k] <= array_in[k];
        end

        // Compute sum = array_in[0] + array_in[num_elements-1]
        // If num_elements==0 (should not per spec), using forced 1 above
        sum <= array_in[0] + array_in[((num_elements == 3'd0) ? 3'd1 : num_elements) - 1];

        // Initialize control (order_asc assigned next cycle after sum valid)
        busy      <= 1'b1;
        done      <= 1'b0;
        i_idx     <= 3'd0;
        j_idx     <= 3'd0;
        step_cnt  <= 6'd0;
        total_steps <= 6'd0;
      end else if (busy) begin
        // If total_steps is zero, it means we are in the cycle right after start
        // when 'sum' became valid; set ordering, total_steps, and begin sorting.
        if (total_steps == 6'd0) begin
          // Determine ordering from sum LSB
          order_asc <= sum[0]; // 1: ascending if sum is ODD; 0: descending if EVEN

          // Compute total_steps = N*(N-1)/2
          // Using n_reg (already latched), safe for 1-8.
          total_steps <= (n_reg * (n_reg - 1)) >> 1;
          step_cnt    <= (n_reg * (n_reg - 1)) >> 1;

          // Initialize indices
          i_idx <= 3'd0;
          j_idx <= 3'd0;

          // Handle trivial case N<=1: complete immediately
          if (n_reg <= 3'd1) begin
            // Directly output work_array (already input copy)
            for (k = 0; k < 8; k = k + 1) begin
              sorted_array[k] <= work_array[k];
            end
            done      <= 1'b1;
            busy      <= 1'b0;
          end
        end else if (step_cnt != 6'd0) begin
          // Perform one bubble compare/swap step per cycle

          // Only operate when both j_idx and j_idx+1 are within valid range
          if (j_idx < (n_reg - 1)) begin
            // Compare work_array[j_idx] and work_array[j_idx+1]
            if (order_asc) begin
              // Ascending: swap if left > right
              if (work_array[j_idx] > work_array[j_idx + 1]) begin
                {work_array[j_idx], work_array[j_idx + 1]} <= {work_array[j_idx + 1], work_array[j_idx]};
              end
            end else begin
              // Descending: swap if left < right
              if (work_array[j_idx] < work_array[j_idx + 1]) begin
                {work_array[j_idx], work_array[j_idx + 1]} <= {work_array[j_idx + 1], work_array[j_idx]};
              end
            end

            // Move inner index
            j_idx <= j_idx + 3'd1;
          end else begin
            // End of inner pass for current i_idx
            j_idx <= 3'd0;
            i_idx <= i_idx + 3'd1;
          end

          // Decrement remaining steps
          step_cnt <= step_cnt - 6'd1;

          // When this was the last step, next cycle we should finish
          if (step_cnt == 6'd1) begin
            // Sorting will be complete after this operation
            // Copy results to outputs and assert done
            for (k = 0; k < 8; k = k + 1) begin
              sorted_array[k] <= work_array[k];
            end
            done <= 1'b1;
            busy <= 1'b0;
          end
        end else begin
          // Safety: if step_cnt == 0 while busy and not handled, finish
          for (k = 0; k < 8; k = k + 1) begin
            sorted_array[k] <= work_array[k];
          end
          done <= 1'b1;
          busy <= 1'b0;
        end
      end else begin
        // Idle state: ensure done remains stable until next start
        // No changes required here
      end
    end
  end

endmodule