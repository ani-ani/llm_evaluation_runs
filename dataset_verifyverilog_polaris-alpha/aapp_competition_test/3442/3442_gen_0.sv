module sheldon_checker(
  input clk,
  input rst_n,
  input start,
  input [15:0] num,
  output reg done,
  output reg is_sheldon
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE        = 3'd0,
    FIRST_RUN_1 = 3'd1,
    MEASURE_0   = 3'd2,
    MEASURE_1   = 3'd3,
    CHECK       = 3'd4,
    DONE        = 3'd5
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [15:0] num_reg;          // latched input
  reg [4:0]  bit_idx;          // 0..16 for controlled stepping
  reg [4:0]  N;                // run length for '1's
  reg [4:0]  M;                // run length for '0's (0 if no 0-run exists)
  reg        N_valid;          // at least one 1 found
  reg        M_valid;          // 0-run measured
  reg        pattern_ok;       // internal validity flag
  reg        expect_one;       // expected bit value for current run in CHECK
  reg [4:0]  run_count;        // count within current run

  // Bit access helper
  wire cur_bit = num_reg[15 - bit_idx];

  // Next-state and control logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = FIRST_RUN_1;
      end

      FIRST_RUN_1: begin
        // After we've stepped all 16 bits, move to CHECK (or MEASURE_0/MEASURE_1 inside seq logic)
        if (bit_idx == 5'd16)
          next_state = CHECK;
        else
          next_state = FIRST_RUN_1; // transitions refined by seq logic via state updates
      end

      MEASURE_0: begin
        if (bit_idx == 5'd16)
          next_state = CHECK;
        else
          next_state = MEASURE_0; // refined in seq always
      end

      MEASURE_1: begin
        if (bit_idx == 5'd16)
          next_state = CHECK;
        else
          next_state = MEASURE_1; // refined in seq always
      end

      CHECK: begin
        if (bit_idx == 5'd16)
          next_state = DONE;
        else
          next_state = CHECK; // step through remaining bits
      end

      DONE: begin
        // Stay in DONE until next start, then restart
        if (start)
          next_state = FIRST_RUN_1;
        else
          next_state = DONE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic: state, counters, and pattern evaluation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      num_reg     <= 16'd0;
      bit_idx     <= 5'd0;
      N           <= 5'd0;
      M           <= 5'd0;
      N_valid     <= 1'b0;
      M_valid     <= 1'b0;
      pattern_ok  <= 1'b0;
      expect_one  <= 1'b0;
      run_count   <= 5'd0;
      done        <= 1'b0;
      is_sheldon  <= 1'b0;
    end else begin
      state <= next_state;

      // Default: keep outputs unless changed in states
      done <= 1'b0;

      case (state)
        IDLE: begin
          // Wait for start, clear internal regs
          if (start) begin
            num_reg     <= num;
            bit_idx     <= 5'd0;
            N           <= 5'd0;
            M           <= 5'd0;
            N_valid     <= 1'b0;
            M_valid     <= 1'b0;
            pattern_ok  <= 1'b1;  // assume valid until disproved
            expect_one  <= 1'b1;  // will search for first 1-run
            run_count   <= 5'd0;
            is_sheldon  <= 1'b0;
          end
        end

        // FIRST_RUN_1: skip leading zeros, then count 1's for N
        FIRST_RUN_1: begin
          if (bit_idx < 5'd16) begin
            if (!N_valid) begin
              // Still skipping leading zeros or starting first 1-run
              if (cur_bit == 1'b1) begin
                // Found first 1 of first run
                N_valid    <= 1'b1;
                N          <= 5'd1;
                run_count  <= 5'd1;
              end
              // else: still in leading zeros, N not valid yet
              bit_idx <= bit_idx + 5'd1;
            end else begin
              // Already in first 1-run, keep counting until 0 or end
              if (cur_bit == 1'b1) begin
                N         <= N + 5'd1;
                run_count <= run_count + 5'd1;
                bit_idx   <= bit_idx + 5'd1;
              end else begin
                // First 0 after first 1-run: transition to MEASURE_0
                M_valid    <= 1'b0;
                M          <= 5'd0;
                run_count  <= 5'd1;   // count this first 0 in zero-run
                M          <= 5'd1;
                M_valid    <= 1'b1;
                bit_idx    <= bit_idx + 5'd1;
                state      <= MEASURE_0;
              end
            end
          end else begin
            // Reached end of bits in FIRST_RUN_1
            // Valid Sheldon only if we had at least one 1 and no contradiction
            if (N_valid && pattern_ok) begin
              // Special Sheldon case: only one run of 1's
              is_sheldon <= 1'b1;
            end else begin
              is_sheldon <= 1'b0;
            end
          end
        end

        // MEASURE_0: finish measuring the first 0-run (M), then decide next
        MEASURE_0: begin
          if (bit_idx < 5'd16) begin
            if (cur_bit == 1'b0) begin
              // Continue zero-run
              M         <= M + 5'd1;
              run_count <= run_count + 5'd1;
              bit_idx   <= bit_idx + 5'd1;
            end else begin
              // First 1 after 0-run: move to MEASURE_1 to verify N for next 1-run
              run_count  <= 5'd1; // count this first 1
              bit_idx    <= bit_idx + 5'd1;
              expect_one <= 1'b1;
              state      <= MEASURE_1;
            end
          end else begin
            // Ended exactly after 0-run; final run can be M zeros, allowed
            if (N_valid && M_valid && pattern_ok)
              is_sheldon <= 1'b1;
            else
              is_sheldon <= 1'b0;
          end
        end

        // MEASURE_1: we are in a 1-run that must match N
        MEASURE_1: begin
          if (bit_idx <= 5'd16) begin
            if (bit_idx == 5'd16) begin
              // At end, check run_count equals N
              if (run_count == N && pattern_ok)
                is_sheldon <= 1'b1;
              else begin
                pattern_ok <= 1'b0;
                is_sheldon <= 1'b0;
              end
            end else begin
              if (cur_bit == 1'b1) begin
                // Continue 1-run
                run_count <= run_count + 5'd1;
                bit_idx   <= bit_idx + 5'd1;
                // If run exceeds N, invalid
                if (run_count + 5'd1 > N) begin
                  pattern_ok <= 1'b0;
                end
              end else begin
                // Hit a 0: the 1-run ended, must equal N
                if (run_count == N && pattern_ok) begin
                  // Start next 0-run in CHECK (alternating phase)
                  expect_one <= 1'b0;      // next we expect zeros
                  run_count  <= 5'd1;      // count this first 0
                  bit_idx    <= bit_idx + 5'd1;
                  state      <= CHECK;
                end else begin
                  pattern_ok <= 1'b0;
                  bit_idx    <= bit_idx + 5'd1;
                  state      <= CHECK;
                end
              end
            end
          end
        end

        // CHECK: enforce alternating runs of N 1's and M 0's
        CHECK: begin
          if (bit_idx < 5'd16) begin
            if (!pattern_ok) begin
              // Still consume bits to honor 16-cycle timing
              bit_idx <= bit_idx + 5'd1;
            end else begin
              if (expect_one) begin
                // In a 1-run of expected length N
                if (cur_bit == 1'b1) begin
                  run_count <= run_count + 5'd1;
                  bit_idx   <= bit_idx + 5'd1;
                  if (run_count + 5'd1 > N)
                    pattern_ok <= 1'b0;
                end else begin
                  // 1-run ended; must be exactly N
                  if (run_count == N) begin
                    // Switch to 0-run
                    expect_one <= 1'b0;
                    run_count  <= 5'd1; // count this first 0
                    bit_idx    <= bit_idx + 5'd1;
                    // If M==0 (no 0-run defined) but we see 0s, invalid
                    if (!M_valid || 5'd1 != M)
                      pattern_ok <= 1'b0;
                  end else begin
                    pattern_ok <= 1'b0;
                    bit_idx    <= bit_idx + 5'd1;
                  end
                end
              end else begin
                // In a 0-run of expected length M
                if (cur_bit == 1'b0) begin
                  run_count <= run_count + 5'd1;
                  bit_idx   <= bit_idx + 5'd1;
                  if (!M_valid || run_count + 5'd1 > M)
                    pattern_ok <= 1'b0;
                end else begin
                  // 0-run ended; must be exactly M
                  if (M_valid && run_count == M) begin
                    // Switch to 1-run of N
                    expect_one <= 1'b1;
                    run_count  <= 5'd1; // count this first 1
                    bit_idx    <= bit_idx + 5'd1;
                    if (run_count != N) begin
                      // Because this new 1-run's first count must eventually hit N;
                      // immediate mismatch only if N==0 (shouldn't if N_valid)
                      if (!N_valid)
                        pattern_ok <= 1'b0;
                    end
                  end else begin
                    pattern_ok <= 1'b0;
                    bit_idx    <= bit_idx + 5'd1;
                  end
                end
              end
            end
          end
        end

        DONE: begin
          // Signal completion; sheldon flag already evaluated
          done <= 1'b1;
          // If a new start comes, reinitialize on next cycle via IDLE->FIRST_RUN_1
          if (start) begin
            num_reg     <= num;
            bit_idx     <= 5'd0;
            N           <= 5'd0;
            M           <= 5'd0;
            N_valid     <= 1'b0;
            M_valid     <= 1'b0;
            pattern_ok  <= 1'b1;
            expect_one  <= 1'b1;
            run_count   <= 5'd0;
            is_sheldon  <= 1'b0;
          end
        end

        default: begin
          // Safety fallback
          state       <= IDLE;
          done        <= 1'b0;
          is_sheldon  <= 1'b0;
          pattern_ok  <= 1'b0;
        end
      endcase

      // Final result latch when transitioning to DONE
      if (state == CHECK && next_state == DONE) begin
        // Final decision based on pattern_ok and validity of initial run
        if (pattern_ok && N_valid)
          is_sheldon <= 1'b1;
        else
          is_sheldon <= 1'b0;
      end

    end
  end

endmodule