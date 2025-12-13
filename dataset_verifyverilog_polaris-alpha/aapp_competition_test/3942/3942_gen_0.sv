module balanced_paren_replace (
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] char [7:0],
  output reg valid,
  output reg error,
  output reg [3:0] replace_counts [7:0]
);

  // Internal registers
  reg [3:0] cycle_cnt;           // 0..8
  reg [3:0] hash_count;          // number of '#' seen (max 8)
  reg [7:0] balance;             // can hold up to 8 safely
  reg any_hash;                  // flag indicating at least one '#'
  reg processing;                // indicates we are processing a transaction
  reg [2:0] last_hash_idx;       // index (0..7) of last '#'

  integer i;

  // Synchronous logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid        <= 1'b0;
      error        <= 1'b0;
      cycle_cnt    <= 4'd0;
      hash_count   <= 4'd0;
      balance      <= 8'd0;
      any_hash     <= 1'b0;
      processing   <= 1'b0;
      last_hash_idx<= 3'd0;
      for (i = 0; i < 8; i = i + 1) begin
        replace_counts[i] <= 4'd0;
      end
    end else begin
      // Default outputs each cycle
      valid <= 1'b0;

      if (!processing) begin
        // Wait for start
        if (start) begin
          // Initialize for new processing
          processing    <= 1'b1;
          cycle_cnt     <= 4'd0;
          hash_count    <= 4'd0;
          balance       <= 8'd0;
          any_hash      <= 1'b0;
          error         <= 1'b0;
          last_hash_idx <= 3'd0;
          for (i = 0; i < 8; i = i + 1) begin
            replace_counts[i] <= 4'd0;
          end
        end
      end else begin
        // Processing active
        if (cycle_cnt < 4'd8) begin
          // Read current character
          case (char[cycle_cnt])
            8'd40: begin // '('
              balance <= balance + 8'd1;
            end
            8'd41: begin // ')'
              if (balance == 0) begin
                error   <= 1'b1;
              end else begin
                balance <= balance - 8'd1;
              end
            end
            8'd35: begin // '#'
              any_hash      <= 1'b1;
              hash_count    <= hash_count + 4'd1;
              last_hash_idx <= cycle_cnt[2:0];
              // Tentatively decrement by 1 for this '#'
              if (balance == 0) begin
                error   <= 1'b1;
              end else begin
                balance <= balance - 8'd1;
              end
              // For all but last, we fix to 1 later, but we model as -1 now
            end
            default: begin
              // Non-specified characters: no effect
            end
          endcase

          // Check immediate negative balance condition
          if (char[cycle_cnt] == 8'd41 || char[cycle_cnt] == 8'd35) begin
            if (balance == 0 && (char[cycle_cnt] == 8'd41 || char[cycle_cnt] == 8'd35)) begin
              // Already set error above; guard redundant logic
            end
          end

          cycle_cnt <= cycle_cnt + 4'd1;
        end else if (cycle_cnt == 4'd8) begin
          // Finalization cycle (9th cycle from start)
          // balance currently = ("(" count) - ")" count) - (1 per '#')
          if (error) begin
            // Already invalid
            valid      <= 1'b1;
            processing <= 1'b0;
            // replace_counts remain 0
          end else begin
            if (!any_hash) begin
              // No '#': valid only if final balance is zero
              if (balance != 0) begin
                error <= 1'b1;
              end
              // replace_counts already 0
              valid      <= 1'b1;
              processing <= 1'b0;
            end else begin
              // There is at least one '#'
              // Compute total extra to assign to last '#'
              // Let b = current balance.
              // Each non-last '#' was counted as -1 already and is fixed.
              // Need final total balance 0, so last '#' gets (1 + b).
              // Because we subtracted 1 for last '#' already, add 'balance' back.
              if (balance[7]) begin
                // Negative (should not happen if guarded earlier), treat as error
                error <= 1'b1;
                valid <= 1'b1;
                processing <= 1'b0;
              end else begin
                // Full replacement count for last '#'
                // base 1 (already modeled) + remaining balance
                // This may exceed 4 bits, so saturate at 4'hF if needed
                reg [7:0] full_cnt;
                full_cnt = 8'd1 + balance;

                // Assign counts: all earlier '#' get 1, last gets full_cnt
                // First, clear all
                for (i = 0; i < 8; i = i + 1) begin
                  replace_counts[i] <= 4'd0;
                end

                // Walk chars and assign 1 to each '#'
                integer j;
                integer seen_hash;
                seen_hash = 0;
                for (j = 0; j < 8; j = j + 1) begin
                  if (char[j] == 8'd35) begin
                    if (j[2:0] == last_hash_idx) begin
                      // Last '#': assign full_cnt
                      if (full_cnt > 8'd15) begin
                        replace_counts[j] <= 4'hF;
                      end else begin
                        replace_counts[j] <= full_cnt[3:0];
                      end
                    end else begin
                      // Earlier '#': assign 1
                      replace_counts[j] <= 4'd1;
                    end
                    seen_hash = seen_hash + 1;
                  end
                end

                // Validate that with this assignment overall balance is zero
                // We know from construction: new_balance = balance - 1 + full_cnt = 0
                // But if balance was invalid (e.g., too large), we rely on this check:
                if (full_cnt == 0) begin
                  // Cannot assign zero to last '#'
                  error <= 1'b1;
                end else begin
                  error <= 1'b0;
                end

                valid      <= 1'b1;
                processing <= 1'b0;
              end
            end
          end

          cycle_cnt <= 4'd9; // stay here until next start
        end else begin
          // Idle after completion, wait for next start pulse
          if (start && !processing) begin
            // This path is mostly redundant due to processing flag gating
          end
        end
      end
    end
  end

endmodule