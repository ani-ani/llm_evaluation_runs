module perm_run_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [3:0] k,
    input [31:0] p,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam STATE_IDLE = 3'd0;
    localparam STATE_SETUP = 3'd1;
    localparam STATE_PROCESSING = 3'd2;
    localparam STATE_DONE = 3'd3;

    // Processing Sub-states
    localparam P_READ_MEM = 3'd0;
    localparam P_CHECK_ZERO = 3'd1;
    localparam P_LOOP_ELEM = 3'd2;
    localparam P_COMPUTE_NEW = 3'd3;
    localparam P_UPDATE_MEM = 3'd4;
    localparam P_NEXT_ITER = 3'd5;
    localparam P_SUM_READ = 3'd6;
    localparam P_SUM_ACC = 3'd7;

    // Registers for state machine
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] proc_state;
    reg [2:0] next_proc_state;

    // DP Iteration Registers
    reg [15:0] mask;
    reg [15:0] next_mask;
    reg [4:0] last;
    reg [4:0] next_last;
    reg [2:0] run_len;
    reg [2:0] next_run_len;
    reg [4:0] try_elem;
    reg [4:0] next_try_elem;
    reg [15:0] full_mask_reg;

    // Computation Registers
    reg [31:0] current_val; // Holds value of dp[mask][last][run_len] or Accumulator
    reg [31:0] next_current_val;
    reg [31:0] temp_update_val; // Holds old value of dp[new_mask][new_last][new_run]
    reg [31:0] next_temp_update_val;

    // Temp storage for new state coordinates during update
    reg [15:0] new_mask_val;
    reg [4:0] new_last_val;
    reg [2:0] new_run_val;

    // Memory Array
    // We declare a large array.
    // Max depth: 65536 masks * 17 last * 5 run = 5,570,560 entries.
    // This is large (176 Mbits). To make it synthesizable for typical targets (e.g. smaller FPGAs) or simulation,
    // we declare it as a `reg` array. Synthesis tools will optimize or fail if resources are insufficient.
    // We will use a flattened memory model.
    // NOTE: If synthesis fails due to memory size, reduce N or use external RAM.
    // We limit the size to the maximum possible needed.

    reg [31:0] dp_mem [0:5570559]; // 5.5M entries

    // Combinational Logic for Next State and Control
    always @(*) begin
        next_state = state;
        next_proc_state = proc_state;
        next_mask = mask;
        next_last = last;
        next_run_len = run_len;
        next_try_elem = try_elem;
        next_current_val = current_val;
        next_temp_update_val = temp_update_val;

        // Default RAM Write signals (0 = no write)
        // We will perform writes inside the procedural block or set flags.
        // To keep it simple, we will handle RAM write in the sequential block based on flags.
        // But since we need to read `dp_mem` combinationaly for the algorithm to proceed,
        // we will use combinational reads.

        case (state)
            STATE_IDLE: begin
                if (start) next_state = STATE_SETUP;
            end

            STATE_SETUP: begin
                // Initialize dp[0][0][0] = 1
                // We will trigger a write here. In seq block, we detect state==SETUP and write.
                // Transition to PROCESSING
                next_mask = 0;
                next_last = 0;
                next_run_len = 1; // Start from run_len 1
                next_proc_state = P_READ_MEM;
                next_state = STATE_PROCESSING;
            end

            STATE_PROCESSING: begin
                case (proc_state)
                    P_READ_MEM: begin
                        // Check loop termination
                        if (mask >= (1 << n)) begin
                            // Switch to Summation Phase
                            next_proc_state = P_SUM_READ;
                            next_mask = (1 << n) - 1; // Full mask
                            next_last = 0;
                            next_run_len = 1;
                            next_current_val = 0; // Accumulator for sum
                        end else begin
                            // Read `dp[mask][last][run_len]` combinationaly
                            // Transition to check
                            next_proc_state = P_CHECK_ZERO;
                        end
                    end

                    P_CHECK_ZERO: begin
                        // We need the read value now.
                        // Calculate address
                        // stride_mask = (n+1)*(k+1)
                        // stride_last = (k+1)
                        // We do this calculation in the comb block using wires or directly.
                        // To avoid recomputing everywhere, we can use wires or just compute inline.
                        // Let's use an index variable for clarity.

                        // Read value logic:
                        // current_val = dp_mem[ index(mask, last, run_len) ];
                        // Since `dp_mem` is an array, we can't assign it to `current_val` directly in `always @(*)` if it's blocking.
                        // But we need to read it. We will use a temporary wire for reading.
                        // However, Verilog arrays can be read in comb logic.
                        // We will perform the read and check in the seq block or just assume data is available.
                        // To fix the timing: We will calculate the index and read in the `always @(*)` block.

                        // Let's assume we have a helper function or just calculate it.
                        // We need to read `dp_mem` here to check if it's zero.
                        // `dp_mem` is a reg array. Reading it in comb logic is okay.

                        // We need to compute the index for `dp_mem` here.
                        // index = mask * (n+1)*(k+1) + last * (k+1) + run_len
                        // Note: Multiplication of inputs is allowed in comb logic.

                        if (dp_mem[ mask * ((n+1)*(k+1)) + last * (k+1) + run_len ] == 0) begin
                            next_proc_state = P_NEXT_ITER;
                        end else begin
                            // Latch the value for processing
                            next_current_val = dp_mem[ mask * ((n+1)*(k+1)) + last * (k+1) + run_len ];
                            next_try_elem = 0;
                            next_proc_state = P_LOOP_ELEM;
                        end
                    end

                    P_LOOP_ELEM: begin
                        if (try_elem < n) begin
                            if (mask[try_elem]) begin
                                // Element already used
                                next_try_elem = try_elem + 1;
                            end else begin
                                // Element free, try to add
                                next_proc_state = P_COMPUTE_NEW;
                            end
                        end else begin
                            next_proc_state = P_NEXT_ITER;
                        end
                    end

                    P_COMPUTE_NEW: begin
                        // Calculate new state
                        // new_mask = mask | (1 << try_elem)
                        // new_last = try_elem
                        // new_run:
                        //   if mask == 0 -> 1
                        //   else if |try_elem - last| == 1 -> run_len + 1
                        //   else -> 1
                        // Check new_run <= k

                        // We compute values and store them in temp registers
                        // We use `new_mask_val`, `new_last_val`, `new_run_val` registers defined earlier.

                        // Logic:
                        // Compute new_run_val
                        reg [2:0] calc_run;
                        if (mask == 0) calc_run = 1;
                        else if ((try_elem == last + 1) || (try_elem == last - 1)) calc_run = run_len + 1;
                        else calc_run = 1;

                        if (calc_run <= k) begin
                            // Valid transition
                            new_mask_val = mask | (1 << try_elem);
                            new_last_val = try_elem;
                            new_run_val = calc_run;

                            // Now we need to update dp[new_mask][new_last][new_run] += current_val
                            // First, read the OLD value of the destination to add to it.
                            // But `dp_mem` is read combinationally.
                            // Let's transition to P_UPDATE_MEM where we perform the read and write.
                            // In P_UPDATE_MEM, we will read `dp_mem[dest_addr]`, add `current_val`, and write back.
                            next_proc_state = P_UPDATE_MEM;
                        end else begin
                            // Invalid run length, skip
                            next_try_elem = try_elem + 1;
                            next_proc_state = P_LOOP_ELEM;
                        end
                    end

                    P_UPDATE_MEM: begin
                        // Perform Read-Modify-Write on destination
                        // Dest Index = new_mask_val * ((n+1)*(k+1)) + new_last_val * (k+1) + new_run_val
                        // We assume `dp_mem` can be read combinationally.
                        // We also need to write to it.
                        // In the sequential block below, we will handle the write.
                        // Here, we just transition.
                        // However, we need to ensure `current_val` (source) and the destination value are added.
                        // Since `dp_mem` read is combinational, we can compute the result here,
                        // but we need to write it.

                        // Let's move to next element.
                        next_try_elem = try_elem + 1;
                        next_proc_state = P_LOOP_ELEM;
                        // Note: The actual RAM update is triggered by state P_UPDATE_MEM in the sequential block.
                    end

                    P_NEXT_ITER: begin
                        // Increment (run, last, mask)
                        if (run_len < k) begin
                            next_run_len = run_len + 1;
                            next_proc_state = P_READ_MEM;
                        end else begin
                            next_run_len = 1;
                            if (last < n) begin
                                next_last = last + 1;
                                next_proc_state = P_READ_MEM;
                            end else begin
                                next_last = 0;
                                next_mask = mask + 1;
                                next_proc_state = P_READ_MEM;
                            end
                        end
                    end

                    P_SUM_READ: begin
                        // Read dp[full_mask][last][run] for summation
                        // Transition to accumulate
                        next_proc_state = P_SUM_ACC;
                    end

                    P_SUM_ACC: begin
                        // Accumulate sum
                        // Read value from dp_mem combinationaly
                        // index = full_mask_reg * ((n+1)*(k+1)) + last * (k+1) + run_len
                        // We need to add to current_val (which holds the sum).
                        // Let's compute next sum: (current_val + dp_mem[index]) % p
                        // We will perform the modulo in the seq block to avoid huge comb paths.
                        // Or we can do it here. Let's do it here for simplicity, but it's a large adder/multiplier.
                        // Actually, the prompt asks for "32-bit multiplication and addition". We only need addition for sum.

                        // We need to calculate the index again.
                        // We will compute the addition in the sequential block to pipeline it.
                        // So we just transition and update pointers.

                        // Update Pointers:
                        if (run_len < k) begin
                            next_run_len = run_len + 1;
                        end else begin
                            next_run_len = 1;
                            if (last < n) begin
                                next_last = last + 1;
                            end else begin
                                // Done Summing
                                next_state = STATE_DONE;
                            end
                        end

                        // Transition to read next (unless done)
                        if (next_state != STATE_DONE) next_proc_state = P_SUM_READ;
                    end
                endcase
            end

            STATE_DONE: begin
                if (!start) next_state = STATE_IDLE;
            end
        endcase
    end

    // Sequential Logic for RAM Access, State Updates, and Calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            done <= 0;
            result <= 0;
        end else begin
            state <= next_state;
            proc_state <= next_proc_state;
            mask <= next_mask;
            last <= next_last;
            run_len <= next_run_len;
            try_elem <= next_try_elem;
            current_val <= next_current_val;

            // RAM Write Logic
            // We must be careful not to overwrite data we need to read.
            // Since we use combinational reads from `dp_mem`, writing to it in the same cycle
            // depends on how the tool infers the RAM (Read-Before-Write or Write-Before-Read).
            // To be safe, we assume synchronous read (data available next cycle) OR we rely on the fact
            // that `dp_mem` is large and we don't read the address we are writing to in the same cycle
            // (because we iterate `mask` and `new_mask` > `mask`).
            // However, `dp[new_mask]` accumulation might happen multiple times.
            // If we write `dp[A]` and then later in the same `mask` loop we need to read `dp[A]` to add `dp[B]`,
            // combinational read will give the OLD value if we write non-blocking `dp[A] <= ...`.
            // If we write blocking `dp[A] = ...`, it updates immediately.
            // For standard inference, we use non-blocking.

            // Write to `dp_mem` in `STATE_SETUP`
            if (state == STATE_SETUP) begin
                dp_mem[0] <= 1;
            end

            // Write to `dp_mem` in `STATE_PROCESSING`
            if (state == STATE_PROCESSING && proc_state == P_UPDATE_MEM) begin
                // Perform: dp[new_mask][new_last][new_run] += current_val
                // Address calculation: new_mask_val * ((n+1)*(k+1)) + new_last_val * (k+1) + new_run_val
                // We use non-blocking assignment.
                // Since `dp_mem` is read combinationally in the `always @(*)` block, the `always @(*)` block
                // uses the OLD value of `dp_mem` (pre-write) for its calculation of the *next* state,
                // which is correct for accumulation.
                dp_mem[ new_mask_val * ((n+1)*(k+1)) + new_last_val * (k+1) + new_run_val ]
                    <= (dp_mem[ new_mask_val * ((n+1)*(k+1)) + new_last_val * (k+1) + new_run_val ] + current_val) % p;
            end

            // Summation Accumulation
            if (state == STATE_PROCESSING && proc_state == P_SUM_ACC) begin
                // Read `dp[full_mask][last][run_len]`
                // Note: Since `dp_mem` is large and we read it combinationally in the `always @(*)` block,
                // we might need to latch the read data here if we are pipelining.
                // However, `P_SUM_ACC` assumes the data is available.
                // Let's read it here to be safe (synchronous read style).
                // But `dp_mem` is a `reg` array. Reading it in a clocked block is synchronous.
                // So we should read it here.
                // But we need the address. The address is determined by `full_mask_reg`, `last`, `run_len`.
                // We can calculate it here.

                // Calculate Sum Index
                // full_mask_reg * ((n+1)*(k+1)) + last * (k+1) + run_len
                result <= (result + dp_mem[ full_mask_reg * ((n+1)*(k+1)) + last * (k+1) + run_len ]) % p;
                // Note: `result` is reused as accumulator here.
                // We reset `result` to 0 in STATE_SETUP or when entering summation.
                // In the comb logic, when we transition to P_SUM_READ, we set `next_current_val = 0`. 
                // But `current_val` is used for DP values. Let's use `result` for the final sum accumulation.
                // We need to reset `result` when entering summation.
            end

            // Handling Accumulator Reset
            if (state == STATE_PROCESSING && next_proc_state == P_SUM_READ && proc_state != P_SUM_READ) begin
                // Just switched to summation
                result <= 0;
            end

            // Done flag
            if (state == STATE_DONE) begin
                done <= 1;
            end else begin
                done <= 0;
            end
        end
    end

endmodule