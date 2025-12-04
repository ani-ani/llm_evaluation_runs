module max_aggregate (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [2:0]  student_id,
  input  logic [7:0]  marks,
  input  logic        last_entry,
  output logic [2:0]  max_id,
  output logic [10:0] max_score,
  output logic        done
);

  // Internal accumulators for 5 students (0-4), 11-bit to handle up to 8*255=2040
  logic [10:0] agg0, agg1, agg2, agg3, agg4;
  logic        processing;

  // Pipeline for last_entry to ensure result after accumulation
  logic last_entry_d1, last_entry_d2;

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      agg0        <= 11'd0;
      agg1        <= 11'd0;
      agg2        <= 11'd0;
      agg3        <= 11'd0;
      agg4        <= 11'd0;
      processing  <= 1'b0;
      last_entry_d1 <= 1'b0;
      last_entry_d2 <= 1'b0;
      max_id      <= 3'd0;
      max_score   <= 11'd0;
      done        <= 1'b0;
    end else begin
      // Default
      done <= 1'b0;

      // Track last_entry pipeline
      last_entry_d1 <= last_entry & processing;
      last_entry_d2 <= last_entry_d1;

      // Start signal: initialize and enter processing mode
      if (start) begin
        agg0        <= 11'd0;
        agg1        <= 11'd0;
        agg2        <= 11'd0;
        agg3        <= 11'd0;
        agg4        <= 11'd0;
        processing  <= 1'b1;
        last_entry_d1 <= 1'b0;
        last_entry_d2 <= 1'b0;
      end else if (processing) begin
        // Accumulate marks into corresponding student bucket
        // Each entry is captured and accumulated in the cycle it is observed
        case (student_id)
          3'd0: agg0 <= agg0 + marks;
          3'd1: agg1 <= agg1 + marks;
          3'd2: agg2 <= agg2 + marks;
          3'd3: agg3 <= agg3 + marks;
          3'd4: agg4 <= agg4 + marks;
          default: ; // Ignore invalid IDs
        endcase
      end

      // On the cycle after last_entry_d1 (i.e., last_entry_d2), compute max
      if (last_entry_d2 && processing) begin
        // Find maximum aggregate and corresponding ID
        logic [10:0] max_val;
        logic [2:0]  max_idx;

        max_val = agg0;
        max_idx = 3'd0;

        if (agg1 > max_val) begin
          max_val = agg1;
          max_idx = 3'd1;
        end
        if (agg2 > max_val) begin
          max_val = agg2;
          max_idx = 3'd2;
        end
        if (agg3 > max_val) begin
          max_val = agg3;
          max_idx = 3'd3;
        end
        if (agg4 > max_val) begin
          max_val = agg4;
          max_idx = 3'd4;
        end

        max_id    <= max_idx;
        max_score <= max_val;
        done      <= 1'b1; // Pulse done high for this cycle
        processing <= 1'b0; // Exit processing mode until next start
      end
    end
  end

endmodule