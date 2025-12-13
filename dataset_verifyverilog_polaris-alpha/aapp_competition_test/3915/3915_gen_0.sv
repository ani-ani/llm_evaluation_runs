module prime_palindrome_compare(
  input              clk,
  input              rst_n,
  input      [15:0]  p,
  input      [15:0]  q,
  input              start,
  output reg [9:0]   result,
  output reg         done
);

  // State encodings
  localparam IDLE     = 2'd0;
  localparam RUN      = 2'd1;
  localparam WAIT_MEM = 2'd2;
  localparam DONE     = 2'd3;

  reg [1:0] state, next_state;

  // Counters and registers
  reg [9:0] n_cnt;                // 1..1000
  reg [9:0] n_eval;               // delayed n for evaluation (after BRAM read)
  reg [9:0] prime_cnt;            // π(n)
  reg [9:0] rub_cnt;              // rub(n)

  // Edge detection for start
  reg start_d;
  wire start_pulse;

  // Prime ROM / BRAM (1-based index: 1..1000). 0 = non-prime, 1 = prime.
  // Implemented as synchronous read memory to infer block RAM.
  reg [0:0] prime_mem [0:999];
  reg       prime_d;              // registered prime flag (for n_cnt)

  // Multipliers for condition: prime_cnt*q <= rub_cnt*p
  // Use wider widths to avoid overflow: max π(1000) < 200, rub(1000) <= 1000
  // 16-bit * 10-bit -> 26-bit is sufficient; use a bit more for safety.
  reg [25:0] left_val;            // π(n_eval) * q
  reg [25:0] right_val;           // rub(n_eval) * p

  // Detect palindromes
  function automatic is_palindrome_10;
    input [9:0] val;
    reg [3:0] d0,d1,d2,d3;
    begin
      if (val < 10) begin
        is_palindrome_10 = 1'b1;
      end else if (val < 100) begin
        d0 = val % 10;
        d1 = val / 10;
        is_palindrome_10 = (d0 == d1);
      end else if (val < 1000) begin
        d0 = val % 10;
        d1 = (val / 10) % 10;
        d2 = (val / 100) % 10;
        is_palindrome_10 = (d0 == d2);
      end else begin
        // For n up to 1000, this only hits when val == 1000
        // 1000 is not a palindrome in base 10
        is_palindrome_10 = 1'b0;
      end
    end
  endfunction

  // Start pulse detection
  assign start_pulse = start & ~start_d;

  // Prime memory initialization (Sieve precomputed constants)
  // Index 0 corresponds to n=1, index 999 to n=1000.
  // 1 if index+1 is prime, else 0.
  // Note: This is static initialization; synthesis tools should map to ROM/BRAM.
  integer i_init;
  initial begin
    // Default all to 0
    for (i_init = 0; i_init < 1000; i_init = i_init + 1) begin
      prime_mem[i_init] = 1'b0;
    end
    // List of primes up to 1000
    prime_mem[1-1]   = 1'b0; // 1
    prime_mem[2-1]   = 1'b1;
    prime_mem[3-1]   = 1'b1;
    prime_mem[5-1]   = 1'b1;
    prime_mem[7-1]   = 1'b1;
    prime_mem[11-1]  = 1'b1;
    prime_mem[13-1]  = 1'b1;
    prime_mem[17-1]  = 1'b1;
    prime_mem[19-1]  = 1'b1;
    prime_mem[23-1]  = 1'b1;
    prime_mem[29-1]  = 1'b1;
    prime_mem[31-1]  = 1'b1;
    prime_mem[37-1]  = 1'b1;
    prime_mem[41-1]  = 1'b1;
    prime_mem[43-1]  = 1'b1;
    prime_mem[47-1]  = 1'b1;
    prime_mem[53-1]  = 1'b1;
    prime_mem[59-1]  = 1'b1;
    prime_mem[61-1]  = 1'b1;
    prime_mem[67-1]  = 1'b1;
    prime_mem[71-1]  = 1'b1;
    prime_mem[73-1]  = 1'b1;
    prime_mem[79-1]  = 1'b1;
    prime_mem[83-1]  = 1'b1;
    prime_mem[89-1]  = 1'b1;
    prime_mem[97-1]  = 1'b1;
    prime_mem[101-1] = 1'b1;
    prime_mem[103-1] = 1'b1;
    prime_mem[107-1] = 1'b1;
    prime_mem[109-1] = 1'b1;
    prime_mem[113-1] = 1'b1;
    prime_mem[127-1] = 1'b1;
    prime_mem[131-1] = 1'b1;
    prime_mem[137-1] = 1'b1;
    prime_mem[139-1] = 1'b1;
    prime_mem[149-1] = 1'b1;
    prime_mem[151-1] = 1'b1;
    prime_mem[157-1] = 1'b1;
    prime_mem[163-1] = 1'b1;
    prime_mem[167-1] = 1'b1;
    prime_mem[173-1] = 1'b1;
    prime_mem[179-1] = 1'b1;
    prime_mem[181-1] = 1'b1;
    prime_mem[191-1] = 1'b1;
    prime_mem[193-1] = 1'b1;
    prime_mem[197-1] = 1'b1;
    prime_mem[199-1] = 1'b1;
    prime_mem[211-1] = 1'b1;
    prime_mem[223-1] = 1'b1;
    prime_mem[227-1] = 1'b1;
    prime_mem[229-1] = 1'b1;
    prime_mem[233-1] = 1'b1;
    prime_mem[239-1] = 1'b1;
    prime_mem[241-1] = 1'b1;
    prime_mem[251-1] = 1'b1;
    prime_mem[257-1] = 1'b1;
    prime_mem[263-1] = 1'b1;
    prime_mem[269-1] = 1'b1;
    prime_mem[271-1] = 1'b1;
    prime_mem[277-1] = 1'b1;
    prime_mem[281-1] = 1'b1;
    prime_mem[283-1] = 1'b1;
    prime_mem[293-1] = 1'b1;
    prime_mem[307-1] = 1'b1;
    prime_mem[311-1] = 1'b1;
    prime_mem[313-1] = 1'b1;
    prime_mem[317-1] = 1'b1;
    prime_mem[331-1] = 1'b1;
    prime_mem[337-1] = 1'b1;
    prime_mem[347-1] = 1'b1;
    prime_mem[349-1] = 1'b1;
    prime_mem[353-1] = 1'b1;
    prime_mem[359-1] = 1'b1;
    prime_mem[367-1] = 1'b1;
    prime_mem[373-1] = 1'b1;
    prime_mem[379-1] = 1'b1;
    prime_mem[383-1] = 1'b1;
    prime_mem[389-1] = 1'b1;
    prime_mem[397-1] = 1'b1;
    prime_mem[401-1] = 1'b1;
    prime_mem[409-1] = 1'b1;
    prime_mem[419-1] = 1'b1;
    prime_mem[421-1] = 1'b1;
    prime_mem[431-1] = 1'b1;
    prime_mem[433-1] = 1'b1;
    prime_mem[439-1] = 1'b1;
    prime_mem[443-1] = 1'b1;
    prime_mem[449-1] = 1'b1;
    prime_mem[457-1] = 1'b1;
    prime_mem[461-1] = 1'b1;
    prime_mem[463-1] = 1'b1;
    prime_mem[467-1] = 1'b1;
    prime_mem[479-1] = 1'b1;
    prime_mem[487-1] = 1'b1;
    prime_mem[491-1] = 1'b1;
    prime_mem[499-1] = 1'b1;
    prime_mem[503-1] = 1'b1;
    prime_mem[509-1] = 1'b1;
    prime_mem[521-1] = 1'b1;
    prime_mem[523-1] = 1'b1;
    prime_mem[541-1] = 1'b1;
    prime_mem[547-1] = 1'b1;
    prime_mem[557-1] = 1'b1;
    prime_mem[563-1] = 1'b1;
    prime_mem[569-1] = 1'b1;
    prime_mem[571-1] = 1'b1;
    prime_mem[577-1] = 1'b1;
    prime_mem[587-1] = 1'b1;
    prime_mem[593-1] = 1'b1;
    prime_mem[599-1] = 1'b1;
    prime_mem[601-1] = 1'b1;
    prime_mem[607-1] = 1'b1;
    prime_mem[613-1] = 1'b1;
    prime_mem[617-1] = 1'b1;
    prime_mem[619-1] = 1'b1;
    prime_mem[631-1] = 1'b1;
    prime_mem[641-1] = 1'b1;
    prime_mem[643-1] = 1'b1;
    prime_mem[647-1] = 1'b1;
    prime_mem[653-1] = 1'b1;
    prime_mem[659-1] = 1'b1;
    prime_mem[661-1] = 1'b1;
    prime_mem[673-1] = 1'b1;
    prime_mem[677-1] = 1'b1;
    prime_mem[683-1] = 1'b1;
    prime_mem[691-1] = 1'b1;
    prime_mem[701-1] = 1'b1;
    prime_mem[709-1] = 1'b1;
    prime_mem[719-1] = 1'b1;
    prime_mem[727-1] = 1'b1;
    prime_mem[733-1] = 1'b1;
    prime_mem[739-1] = 1'b1;
    prime_mem[743-1] = 1'b1;
    prime_mem[751-1] = 1'b1;
    prime_mem[757-1] = 1'b1;
    prime_mem[761-1] = 1'b1;
    prime_mem[769-1] = 1'b1;
    prime_mem[773-1] = 1'b1;
    prime_mem[787-1] = 1'b1;
    prime_mem[797-1] = 1'b1;
    prime_mem[809-1] = 1'b1;
    prime_mem[811-1] = 1'b1;
    prime_mem[821-1] = 1'b1;
    prime_mem[823-1] = 1'b1;
    prime_mem[827-1] = 1'b1;
    prime_mem[829-1] = 1'b1;
    prime_mem[839-1] = 1'b1;
    prime_mem[853-1] = 1'b1;
    prime_mem[857-1] = 1'b1;
    prime_mem[859-1] = 1'b1;
    prime_mem[863-1] = 1'b1;
    prime_mem[877-1] = 1'b1;
    prime_mem[881-1] = 1'b1;
    prime_mem[883-1] = 1'b1;
    prime_mem[887-1] = 1'b1;
    prime_mem[907-1] = 1'b1;
    prime_mem[911-1] = 1'b1;
    prime_mem[919-1] = 1'b1;
    prime_mem[929-1] = 1'b1;
    prime_mem[937-1] = 1'b1;
    prime_mem[941-1] = 1'b1;
    prime_mem[947-1] = 1'b1;
    prime_mem[953-1] = 1'b1;
    prime_mem[967-1] = 1'b1;
    prime_mem[971-1] = 1'b1;
    prime_mem[977-1] = 1'b1;
    prime_mem[983-1] = 1'b1;
    prime_mem[991-1] = 1'b1;
    prime_mem[997-1] = 1'b1;
  end

  // Synchronous prime_mem read to infer BRAM
  always @(posedge clk) begin
    if (!rst_n) begin
      prime_d <= 1'b0;
    end else begin
      if (state == RUN || state == WAIT_MEM) begin
        // read at address (n_cnt-1) during RUN, but use guard when n_cnt==0
        if (n_cnt != 10'd0 && n_cnt <= 10'd1000)
          prime_d <= prime_mem[n_cnt - 10'd1];
        else
          prime_d <= 1'b0;
      end else begin
        prime_d <= 1'b0;
      end
    end
  end

  // Sequential logic: state, counters, accumulators
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      start_d    <= 1'b0;
      n_cnt      <= 10'd0;
      n_eval     <= 10'd0;
      prime_cnt  <= 10'd0;
      rub_cnt    <= 10'd0;
      result     <= 10'd0;
      done       <= 1'b0;
      left_val   <= 26'd0;
      right_val  <= 26'd0;
    end else begin
      // capture delayed start
      start_d <= start;

      state <= next_state;

      // Default done low (1-cycle pulse when entering DONE)
      if (state != DONE)
        done <= 1'b0;

      case (state)
        IDLE: begin
          if (start_pulse) begin
            // Initialize for new run
            n_cnt     <= 10'd1;   // first n to evaluate
            n_eval    <= 10'd0;   // no valid eval yet
            prime_cnt <= 10'd0;
            rub_cnt   <= 10'd0;
            result    <= 10'd0;
          end
        end

        RUN: begin
          // In RUN, we have prime_d from previous n_cnt (or 0 for first), and
          // n_eval is previous n_cnt used for evaluation.

          // 1) Use prime_d and n_eval to update π and rub and result.
          if (n_eval != 10'd0 && n_eval <= 10'd1000) begin
            // update prime count
            if (prime_d)
              prime_cnt <= prime_cnt + 10'd1;

            // update rub count if palindrome
            if (is_palindrome_10(n_eval))
              rub_cnt <= rub_cnt + 10'd1;

            // 2) Evaluate inequality with updated counts (use combinational next below)
            // We'll compute left_val/right_val from current prime_cnt/rub_cnt
            // in parallel; comparison done below using current values.
            left_val  <= (prime_cnt + (prime_d ? 10'd1 : 10'd0)) * q;
            right_val <= (rub_cnt + (is_palindrome_10(n_eval) ? 10'd1 : 10'd0)) * p;

            if (left_val <= right_val)
              result <= n_eval;
          end

          // 3) Advance to next n and set n_eval for next cycle
          if (n_cnt < 10'd1000) begin
            n_eval <= n_cnt;          // n_cnt just used for BRAM read; will be eval'd next cycle
            n_cnt  <= n_cnt + 10'd1;  // increment for next BRAM address
          end else begin
            // At n_cnt == 1000, we will move to WAIT_MEM to finish last evaluation
            n_eval <= n_cnt;          // 1000 will be evaluated in WAIT_MEM
          end
        end

        WAIT_MEM: begin
          // Final cycle to account for last BRAM latency at n=1000.
          // prime_d now corresponds to n=1000, and n_eval holds 1000.
          if (n_eval != 10'd0 && n_eval <= 10'd1000) begin
            if (prime_d)
              prime_cnt <= prime_cnt + 10'd1;
            if (is_palindrome_10(n_eval))
              rub_cnt <= rub_cnt + 10'd1;

            left_val  <= (prime_cnt + (prime_d ? 10'd1 : 10'd0)) * q;
            right_val <= (rub_cnt + (is_palindrome_10(n_eval) ? 10'd1 : 10'd0)) * p;

            if (left_val <= right_val)
              result <= n_eval;
          end
        end

        DONE: begin
          // Assert done for this cycle
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse)
          next_state = RUN;
      end

      RUN: begin
        if (n_cnt == 10'd1000) begin
          // After issuing read for n=1000, go to WAIT_MEM to process it
          next_state = WAIT_MEM;
        end
      end

      WAIT_MEM: begin
        // One extra cycle to finish last evaluation
        next_state = DONE;
      end

      DONE: begin
        // Return to IDLE, wait for next start
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule
