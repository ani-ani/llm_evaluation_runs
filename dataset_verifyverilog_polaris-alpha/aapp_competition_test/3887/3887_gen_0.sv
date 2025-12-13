module rebus_solver(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_terms,
  input [15:0] n,
  input [15:0] sign_pattern,
  output reg [15:0] solution [0:15],
  output reg possible,
  output reg done
);

  // Internal registers
  reg [4:0]  idx;
  reg [15:0] min_sum;
  reg [16:0] diff;          // one extra bit for sign during computation
  reg        state;         // 0 = IDLE, 1 = RUN
  reg [3:0]  terms_latched;
  reg [15:0] n_latched;
  reg [15:0] sign_latched;

  integer i;

  // Main sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous reset: clear all outputs and internal state
      possible      <= 1'b0;
      done          <= 1'b0;
      state         <= 1'b0;
      idx           <= 5'd0;
      min_sum       <= 16'd0;
      diff          <= 17'd0;
      terms_latched <= 4'd0;
      n_latched     <= 16'd0;
      sign_latched  <= 16'd0;
      for (i = 0; i < 16; i = i + 1) begin
        solution[i] <= 16'd0;
      end
    end else begin
      case (state)
        1'b0: begin // IDLE
          done     <= 1'b0;
          possible <= 1'b0;

          if (start) begin
            // Latch inputs
            terms_latched <= (num_terms == 4'd0) ? 4'd0 : num_terms;
            n_latched     <= n;
            sign_latched  <= sign_pattern;

            // Initialize
            min_sum <= 16'd0;
            diff    <= 17'd0;
            idx     <= 5'd0;

            // Clear solution outputs
            for (i = 0; i < 16; i = i + 1) begin
              solution[i] <= 16'd0;
            end

            state <= 1'b1; // move to RUN
          end
        end

        1'b1: begin // RUN
          // Phase 1: compute min_sum and base solution (term = 1 or -1)
          if (idx < terms_latched) begin
            // Set base value = 1 for all active terms
            solution[idx] <= 16'd1;

            // Accumulate min_sum based on sign
            if (sign_latched[idx]) begin
              // positive term: +1
              min_sum <= min_sum + 16'd1;
            end else begin
              // negative term: -1
              min_sum <= min_sum - 16'd1;
            end

            idx <= idx + 5'd1;
          end else if (idx == terms_latched) begin
            // All terms initialized: compute diff = n - min_sum
            // Use signed arithmetic via 17-bit container
            diff <= {1'b0, n_latched} - {{1{min_sum[15]}}, min_sum};
            idx  <= idx + 5'd1; // move to next phase marker
          end else if (idx > terms_latched && idx < (terms_latched + 5'd1 + 5'd16)) begin
            // Phase 2: distribute diff over up to 16 cycles (one per term)
            // Use a local index for distribution separate from idx progress
            // dist_idx: 0..terms_latched-1 linked to cycles after diff calc
            reg [4:0] dist_idx;
            dist_idx = idx - (terms_latched + 5'd1);

            if (dist_idx < terms_latched) begin
              // Only operate while there is remaining diff to distribute
              if (diff != 17'd0) begin
                // Compute current term max additional contribution
                // For positive term: contribution = (val - 1)
                // For negative term: contribution = -(val - 1)
                // Each term value is limited to [1 .. n_latched]
                reg [15:0] cur_val;
                reg [15:0] max_inc;
                reg [16:0] needed;
                cur_val = solution[dist_idx];

                if (sign_latched[dist_idx]) begin
                  // Positive term: we can increase up to n_latched
                  if (cur_val < n_latched) begin
                    max_inc = n_latched - cur_val;
                    // We want to move diff toward zero
                    if (diff > 17'd0) begin
                      needed = (diff[16:0] < {1'b0,max_inc}) ? diff : {1'b0,max_inc};
                      solution[dist_idx] <= cur_val + needed[15:0];
                      diff <= diff - needed;
                    end
                  end
                end else begin
                  // Negative term: making it larger makes sum smaller (more negative)
                  // contribution to total is -(val), so increasing val moves sum by -1 each step
                  if (cur_val < n_latched) begin
                    max_inc = n_latched - cur_val;
                    if (diff < 17'd0) begin
                      // We need to reduce diff (negative) toward zero by subtracting negative increments
                      // Each +1 to val changes sum by -1 => diff increases by +1
                      // So we can use up to -diff steps
                      needed = ((-diff) < {1'b0,max_inc}) ? (-diff) : {1'b0,max_inc};
                      solution[dist_idx] <= cur_val + needed[15:0];
                      diff <= diff + needed; // since each step adds +1 to diff
                    end
                  end
                end
              end
            end

            idx <= idx + 5'd1;

            // After enough cycles, or if diff already zero and we've passed all terms, we can finish
            if ((idx >= (terms_latched + 5'd1 + terms_latched)) || (diff == 17'd0 && dist_idx >= (terms_latched-1))) begin
              // Finalize on next cycle
            end
          end else begin
            // Finalization state within RUN
            if (diff == 17'd0 && terms_latched != 4'd0) begin
              possible <= 1'b1;
            end else begin
              possible <= 1'b0;
            end
            done  <= 1'b1;
            state <= 1'b0; // go back to IDLE
          end
        end

        default: begin
          state <= 1'b0;
        end
      endcase
    end
  end

endmodule