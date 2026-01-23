module newman_conway(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 3'd0;
    localparam CHECK_BASE = 3'd1;
    localparam COMPUTE = 3'd2;
    localparam DONE = 3'd3;

    // Lookup table for P(1) through P(16)
    reg [4:0] p_table [0:15];
    // Tracks which value we're computing
    reg [4:0] current_n;
    // State machine state
    reg [2:0] state;

    // Temporary registers for computation indices
    reg [4:0] p_n_minus_1;
    reg [4:0] idx_calc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'b0;
            done <= 1'b0;
            current_n <= 5'b0;
            // Reset table values (optional but good practice)
            // p_table indices 0-15 will be initialized implicitly or explicitly
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_n <= n;
                        state <= CHECK_BASE;
                    end
                end

                CHECK_BASE: begin
                    if (current_n <= 5'd2) begin
                        // Edge case: n=1 or n=2, result is 1
                        result <= 5'd1;
                        done <= 1'b1;
                        state <= DONE;
                    end else begin
                        // Initialize base values in table
                        p_table[0] <= 5'd0; // Index 0 is unused (sequence starts at 1)
                        p_table[1] <= 5'd1;
                        p_table[2] <= 5'd1;
                        // Start computation from index 3
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Compute P(i) = P(P(i-1)) + P(i - P(i-1))
                    // We compute for index 3, then 4, etc., up to current_n
                    
                    // Step 1: Read P(i-1) where i is the next index to compute
                    // We track the index to compute. Since we are in a single-cycle FSM,
                    // we need to infer the current index. 
                    // Logic: We need to iterate. Let's use a temp register for the iteration index.
                    // However, to save registers, we can use the fact that we just entered COMPUTE.
                    // But we need to loop. 
                    
                    // Wait, to loop in FSM without an explicit counter register, we need to store state.
                    // But we need to compute sequentially. Let's use a separate index counter register.
                    // Or we can infer it based on which table entries exist. 
                    // Given the requirements, let's assume we can add a register `idx`.
                    // Actually, the prompt provided specific registers. 
                    // It mentioned `current_n` and `state`. 
                    // To compute multiple values, we need a loop counter or an index tracker.
                    // Let's interpret `current_n` as the *target* n, and use `p_table` filled state to track progress.
                    // But we can't read/write same cycle easily for a loop.
                    // Let's add a register `i` for the current iteration index, or use `current_n` cleverly.
                    // Let's use `current_n` to store the *target* and introduce `idx`.
                    // Wait, strict instruction: "Use these register declarations". 
                    // The prompt allows user defined registers within the scope? "Use these register declarations" implies these are the main ones.
                    // It doesn't explicitly forbid locals. But to be safe and efficient, let's infer the index from the content of `current_n` or use a dedicated counter.
                    // Actually, standard way: iterate `current_n` from 3 to target.
                    // But `current_n` holds the target. Let's rename `current_n` to `target_n` in logic or use `idx`.
                    // Let's add `idx` to track the iteration index.
                end
            endcase
        end
    end

    // Separated logic for the COMPUTE state to handle the 3-cycle latency pipeline required for calculation
    // or sequential calculation. The prompt asks for ~20 cycles. 
    // Let's use a proper counter for the index `i` since we need to iterate.
    
    // Re-declaring/Adding necessary logic variables inside the module
    reg [4:0] idx; // Current index being computed
    reg [2:0] compute_step; // To handle multi-cycle calculation within COMPUTE state
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'b0;
            done <= 1'b0;
            current_n <= 5'b0;
            idx <= 5'd0;
            compute_step <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_n <= n; // target n
                        state <= CHECK_BASE;
                        idx <= 5'd0;
                        compute_step <= 3'd0;
                    end
                end

                CHECK_BASE: begin
                    if (current_n <= 5'd2) begin
                        result <= 5'd1;
                        done <= 1'b1;
                        state <= DONE;
                    end else begin
                        p_table[1] <= 5'd1;
                        p_table[2] <= 5'd1;
                        // Start from 3
                        idx <= 5'd3;
                        state <= COMPUTE;
                        compute_step <= 3'd0;
                    end
                end

                COMPUTE: begin
                    // We need to compute P(idx). 
                    // P(idx) = P(P(idx-1)) + P(idx - P(idx-1))
                    // This requires reading P(idx-1) (known immediately) and then using that value as index.
                    // Let's break into cycles:
                    // Cycle 0: Read P(idx-1) -> val1. Read P(idx - val1) -> val2. (Requires sequential read or dual port? We have single port logic here but FPGA BRAM is dual port usually. Verilog behavioral implies async read for arrays if synthesizable as LUT/ROM. But here we write and read. Let's assume we can read previous values same cycle if we use logic, or add latency.)
                    // Since it's a sequence generator and we are iterating, we can register the intermediate values.
                    
                    // Let's implement a simple state within state or multi-cycle logic.
                    // But for simplicity in Verilog without explicit multi-cycle FSM states, let's assume we can do the calculation in one go if registers are available, but since we index into ourselves, we might need cycles.
                    // To be safe and synthesizable without complex dependencies:
                    // Step 0: Read P(idx-1). Let's call it p_prev.
                    // Step 1: Calculate index2 = idx - p_prev.
                    // Step 2: Read P(index2).
                    // Step 3: Add.
                    // Since we are in a loop, we can just do this sequentially per cycle of the main clock.
                    // i.e., compute one P(i) per clock cycle. 
                    // The prompt says "Latency: Result valid approximately 20 clock cycles".
                    // If we compute one per cycle, for n=16 we need ~14 cycles. So 1 cycle per P(i) is acceptable.
                    // However, reading P(P(idx-1)) means we read P(p_prev). 
                    // If we write P(i) and then read it later, we have a write-forwarding issue or we need to wait.
                    // But P(P(idx-1)) refers to a value P(k) where k < idx (since P(idx-1) < idx usually, P(n) < n for n>2).
                    // So P(P(idx-1)) is already computed and stored in p_table.
                    // So we can read it. 
                    // Can we read p_table[idx-1] and p_table[idx - p_table[idx-1]] in the same cycle?
                    // p_table is a reg array. In behavioral Verilog, you can do:
                    // val1 <= p_table[idx-1]; (This is a blocking assignment in combinational block, non-blocking in sequential).
                    // In a sequential block, non-blocking assignment schedules the read.
                    // We need the value of p_table[idx-1] to calculate the address for the second read.
                    // So we need at least 2 cycles: 1 to read p_prev, 2 to read p_prev2 and add.
                    // Let's use `compute_step` to manage this.
                    
                    if (compute_step == 3'd0) begin
                        // Read P(idx-1)
                        // Since idx starts at 3, idx-1 is 2, which is valid.
                        p_n_minus_1 <= p_table[idx - 1];
                        compute_step <= 3'd1;
                    end else if (compute_step == 3'd1) begin
                        // Read P(P(idx-1)) and P(idx - P(idx-1))
                        // p_n_minus_1 is now valid.
                        // We need two reads. We can combine them.
                        // Let's use a temporary register for the sum or just assign directly to table.
                        // To write to p_table[idx], we can't write and read in same cycle for synthesis usually if same index.
                        // But we are writing to idx and reading from < idx. So it's safe.
                        // p_table[idx] <= p_table[p_n_minus_1] + p_table[idx - p_n_minus_1];
                        // This is a single assignment. However, reading from p_table takes 0 time in simulation, 
                        // but physically it's a register output. 
                        // Let's try to do it in 1 cycle if possible for speed, but we need p_n_minus_1.
                        // Since we registered p_n_minus_1 in step 0, we can do the calculation now.
                        
                        p_table[idx] <= p_table[p_n_minus_1] + p_table[idx - p_n_minus_1];
                        
                        // Increment idx
                        if (idx < current_n) begin
                            idx <= idx + 1;
                            compute_step <= 3'd0; // Go back to step 0 for next iteration
                        end else begin
                            // Finished computation
                            result <= p_table[p_n_minus_1] + p_table[idx - p_n_minus_1]; // Or just read the written value next cycle, but let's output what we computed
                            done <= 1'b1;
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    if (!start) begin // Wait for start to go low
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule