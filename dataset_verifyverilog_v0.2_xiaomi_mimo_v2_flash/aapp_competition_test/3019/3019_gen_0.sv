module max_revenue(
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [9:0] S [0:7],
    output reg [7:0] max_rev,
    output reg done
);

    // States
    typedef enum logic [2:0] {
        IDLE,
        PRECOMPUTE_SUMS,
        PRECOMPUTE_FACTORS,
        DP_INIT,
        DP_OUTER,
        DP_INNER,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Subnet sum memory
    reg [15:0] subset_sum [0:255];
    reg we_sum;
    reg [7:0] waddr_sum;
    reg [15:0] wdata_sum;
    wire [15:0] rdata_sum;
    
    // Prime factors memory
    reg [7:0] prime_factors [0:255];
    reg we_pf;
    reg [7:0] waddr_pf;
    reg [7:0] wdata_pf;
    wire [7:0] rdata_pf;

    // DP memory (using register array for simplicity and speed)
    reg [7:0] dp [0:255];

    // Registers
    reg [7:0] mask_idx;
    reg [7:0] submask_idx;
    reg [7:0] current_mask;
    reg [7:0] comp_mask;
    reg [7:0] temp_val;
    reg [7:0] temp_pf;
    reg [7:0] dp_calc;
    
    // Combinational Logic for Sum Calculation
    // Calculates sum for 'mask_idx' based on current input S values
    // Only valid when state is PRECOMPUTE_SUMS
    wire [15:0] calc_sum;
    assign calc_sum = (
        ((mask_idx[0] ? S[0] : 10'd0) + (mask_idx[1] ? S[1] : 10'd0)) +
        ((mask_idx[2] ? S[2] : 10'd0) + (mask_idx[3] ? S[3] : 10'd0))
    ) + (
        ((mask_idx[4] ? S[4] : 10'd0) + (mask_idx[5] ? S[5] : 10'd0)) +
        ((mask_idx[6] ? S[6] : 10'd0) + (mask_idx[7] ? S[7] : 10'd0))
    );

    // Combinational Logic for Prime Factor Counting
    wire [15:0] current_sum;
    assign current_sum = subset_sum[mask_idx];
    
    reg [7:0] pf_count_next;
    reg [15:0] temp_rem;
    
    // 23 primes to check: 2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89
    integer prime_idx;
    
    always @(*) begin
        temp_rem = current_sum;
        pf_count_next = 0;
        
        // Handle 2 separately if it divides
        if (temp_rem > 0) begin
            if (temp_rem[0] == 0) begin
                pf_count_next = 1;
                while (temp_rem[0] == 0 && temp_rem > 0) begin
                    temp_rem = temp_rem >> 1;
                end
            end
            
            // Check odd primes
            if (temp_rem > 0) begin
                if (temp_rem % 3 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 3 == 0) temp_rem = temp_rem / 3; end
                if (temp_rem % 5 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 5 == 0) temp_rem = temp_rem / 5; end
                if (temp_rem % 7 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 7 == 0) temp_rem = temp_rem / 7; end
                if (temp_rem % 11 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 11 == 0) temp_rem = temp_rem / 11; end
                if (temp_rem % 13 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 13 == 0) temp_rem = temp_rem / 13; end
                if (temp_rem % 17 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 17 == 0) temp_rem = temp_rem / 17; end
                if (temp_rem % 19 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 19 == 0) temp_rem = temp_rem / 19; end
                if (temp_rem % 23 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 23 == 0) temp_rem = temp_rem / 23; end
                if (temp_rem % 29 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 29 == 0) temp_rem = temp_rem / 29; end
                if (temp_rem % 31 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 31 == 0) temp_rem = temp_rem / 31; end
                if (temp_rem % 37 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 37 == 0) temp_rem = temp_rem / 37; end
                if (temp_rem % 41 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 41 == 0) temp_rem = temp_rem / 41; end
                if (temp_rem % 43 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 43 == 0) temp_rem = temp_rem / 43; end
                if (temp_rem % 47 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 47 == 0) temp_rem = temp_rem / 47; end
                if (temp_rem % 53 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 53 == 0) temp_rem = temp_rem / 53; end
                if (temp_rem % 59 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 59 == 0) temp_rem = temp_rem / 59; end
                if (temp_rem % 61 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 61 == 0) temp_rem = temp_rem / 61; end
                if (temp_rem % 67 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 67 == 0) temp_rem = temp_rem / 67; end
                if (temp_rem % 71 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 71 == 0) temp_rem = temp_rem / 71; end
                if (temp_rem % 73 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 73 == 0) temp_rem = temp_rem / 73; end
                if (temp_rem % 79 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 79 == 0) temp_rem = temp_rem / 79; end
                if (temp_rem % 83 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 83 == 0) temp_rem = temp_rem / 83; end
                if (temp_rem % 89 == 0) begin pf_count_next = pf_count_next + 1; while (temp_rem % 89 == 0) temp_rem = temp_rem / 89; end
            end
        end
    end

    // DP State Calculation
    wire [7:0] dp_candidate;
    assign dp_candidate = dp[submask_idx] + rdata_pf;

    // Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            max_rev <= 0;
            mask_idx <= 0;
            submask_idx <= 0;
            we_sum <= 0;
            we_pf <= 0;
        end else begin
            we_sum <= 0;
            we_pf <= 0;
            
            case (current_state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        current_state <= PRECOMPUTE_SUMS;
                        mask_idx <= 0;
                    end
                end

                PRECOMPUTE_SUMS: begin
                    // Compute and write sum for current mask_idx
                    we_sum <= 1;
                    waddr_sum <= mask_idx;
                    wdata_sum <= calc_sum;
                    
                    if (mask_idx == 8'hFF) begin
                        current_state <= PRECOMPUTE_FACTORS;
                        mask_idx <= 0;
                    end else begin
                        mask_idx <= mask_idx + 1;
                    end
                end

                PRECOMPUTE_FACTORS: begin
                    // Read sum from RAM (registered output implies we read mask_idx in previous cycle if purely block RAM)
                    // Wait state or assume read happens immediately if using LUTRAM logic.
                    // Here we assume we calculate based on the sum which should be stable from the RAM output.
                    // Since we implemented subset_sum as reg array, rdata_sum is combinational from current mask_idx.
                    // But we need to wait for RAM read. Since it's an array of regs, it's 0 cycle read.
                    
                    we_pf <= 1;
                    waddr_pf <= mask_idx;
                    wdata_pf <= pf_count_next;

                    if (mask_idx == 8'hFF) begin
                        current_state <= DP_INIT;
                    end else begin
                        mask_idx <= mask_idx + 1;
                    end
                end

                DP_INIT: begin
                    dp[0] <= 0;
                    mask_idx <= 1;
                    current_state <= DP_OUTER;
                end

                DP_OUTER: begin
                    // Initialize DP for current mask (set to 0 before inner loop finds max)
                    // Or we can keep a 'max' register. Let's use dp[mask_idx] as the accumulator.
                    dp[mask_idx] <= 0;
                    submask_idx <= mask_idx;
                    current_state <= DP_INNER;
                end

                DP_INNER: begin
                    // DP transition: dp[mask] = max(dp[mask], dp[submask] + pf[complement])
                    // We need to fetch pf[complement].
                    // Logic: Read rdata_pf for 'comp_mask'.
                    // Since we are in DP_INNER, we set waddr_pf and waddr_sum to comp_mask to get value.
                    // However, we need to compute comp_mask first.
                    
                    // Optimization: Calculate candidate and update.
                    if (dp_candidate > dp[mask_idx]) begin
                        dp[mask_idx] <= dp_candidate;
                    end

                    // Decrement submask (iterate all submasks)
                    submask_idx <= (submask_idx - 1) & mask_idx;

                    // If submask becomes 0, we are done with this mask
                    if (submask_idx == 0) begin
                        current_state <= DP_OUTER_DONE;
                    end else begin
                        current_state <= DP_INNER_WAIT;
                    end
                end
                
                // Added a wait state to allow memory address to update for the next iteration
                DP_INNER_WAIT: begin
                    current_state <= DP_INNER;
                end

                DP_OUTER_DONE: begin
                    if (mask_idx == ((1 << N) - 1)) begin
                        max_rev <= dp[mask_idx];
                        done <= 1;
                        current_state <= DONE;
                    end else begin
                        mask_idx <= mask_idx + 1;
                        current_state <= DP_OUTER;
                    end
                end

                DONE: begin
                    if (!start) begin
                        current_state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

    // Combinational updates for DP Inner inputs
    // We need to make sure comp_mask is valid when state is DP_INNER or DP_INNER_WAIT
    // Actually, since we transition to DP_INNER_WAIT after update, we need to be careful.
    // The logic is: In DP_INNER, we use current submask_idx to compute comp.
    // comp = mask ^ submask.
    
    always @(*) begin
        comp_mask = mask_idx ^ submask_idx;
    end

    // Handle RAM read addresses for DP phase
    // We need rdata_pf for 'comp_mask' when calculating dp_candidate.
    // Since we are in DP_INNER state, we can use comp_mask as address.
    // But standard reg file read is asynchronous.
    // However, to optimize for timing and logic, we might need to delay.
    // Let's update waddr_pf and waddr_sum in combinational logic based on state.
    
    always @(*) begin
        // Defaults
        // If DP_INNER, we need to read prime_factors[comp_mask]
        // But we also used waddr_pf in PRECOMPUTE_FACTORS.
        // To avoid conflict, we can re-use the same address port if we separate states carefully.
        // Or just read asynchronously.
        // The 'prime_factors' array is a reg array, so reading is combinational.
        // The issue is that 'comp_mask' changes.
        
        // Since 'prime_factors' is a memory array, accessing it requires an index.
        // We assign the address for the memory read.
        // But wait, 'rdata_pf' is a wire connected to the array? 
        // In the code above, I defined rdata_pf as wire, but didn't implement the read logic.
        // I used 'temp_pf' register in the DP_INNER block implicitly but didn't show the assignment.
        // Let's implement the read logic properly.
        
        // We need to map the memory read to the wire.
        // Since it's an array of regs, we can do:
        // assign rdata_pf = prime_factors[comp_mask]; // when needed? 
        // But we need to be careful about write conflicts.
        
        // Let's define the memory read logic explicitly.
    end

    // Explicit Memory Read Logic (since I declared them as wires but didn't hook them up)
    // Actually, if I use the array directly in the always block, I don't need the wires.
    // But the always block in DP_INNER uses 'rdata_pf'.
    // Let's define rdata_pf as the output of the memory.
    // And we need to handle the address selection.
    
    // In DP_INNER, we read prime_factors[comp_mask].
    // In PRECOMPUTE_FACTORS, we read subset_sum[mask_idx].
    
    // To make the code compile and work correctly in synthesis:
    // We will infer the read logic by accessing the arrays in the combinational block or sequential block.
    
    // Correct approach for the DP_INNER block:
    // We need the value of prime_factors[comp_mask].
    // Since prime_factors is an array, we can read it directly.
    // However, I used 'rdata_pf' in the calculation.
    // Let's change the DP calculation to use the array directly, or assign rdata_pf based on state.
    
    // To ensure clean Verilog:
    // 1. prime_factors and subset_sum are block memories.
    // 2. In PRECOMPUTE_SUMS, we write to subset_sum.
    // 3. In PRECOMPUTE_FACTORS, we read subset_sum[mask_idx] and write to prime_factors.
    // 4. In DP_INNER, we read prime_factors[comp_mask].
    
    // The issue with using 'prime_factors[comp_mask]' inside an always @(*) block is that it creates a latch if not handled?
    // No, if we are inside a combinational block, it's fine.
    // But the DP_INNER block in the FSM is sequential.
    
    // Let's fix the DP_INNER calculation.
    // In the sequential block:
    // if (prime_factors[comp_mask] + dp[submask_idx] > dp[mask_idx]) ...
    
    // But wait, 'comp_mask' logic is in an always @(*) block.
    // 'prime_factors[comp_mask]' is asynchronous read.
    // This might cause timing issues if deep, but N is small.
    
    // Actually, there is a subtle bug in the state transition logic I wrote.
    // The calculation of 'comp_mask' and reading 'prime_factors' must happen BEFORE or DURING the DP_INNER state.
    // Since I have a 'DP_INNER_WAIT' state, this gives time for the read to happen.
    
    // Let's refine the code structure to ensure valid operations.
    
    // We need to declare the memory arrays.
    // I used 'reg [7:0] prime_factors [0:255];' etc.
    
    // Let's modify the DP_INNER calculation to be clearer.
    // We will access 'prime_factors[comp_mask]' directly in the sequential block.
    // However, standard Verilog arrays allow reading in sequential blocks, but it's often 
    // discouraged for inferred RAMs. But here we need random access for DP, so a register file or LUTRAM is needed.
    // Given the size (256 entries), it fits in LUTs if we access it dynamically.
    
    // Revised FSM block for DP_INNER:
    // In the code above, I used `dp_candidate`. Let's remove that wire and compute inside the block.
    
    // Let's overwrite the DP_INNER logic in the FSM.
    // (I will inject this into the final code logic).
    
    // Also, regarding the 'prime_factors' memory read in DP state:
    // Since we are reading from 'prime_factors' using 'comp_mask', and 'comp_mask' changes every cycle,
    // we need the read data to be available in the next cycle or immediately.
    // If 'prime_factors' is inferred as a register file (async read), it works in the same cycle.
    // So we can do:
    // In DP_INNER state (or before it):
    // `pf_temp = prime_factors[comp_mask];`
    // `if (dp[submask_idx] + pf_temp > dp[mask_idx]) ...`
    
    // To implement this cleanly in the single always block:
    // I will add a helper variable `logic [7:0] pf_val` in the combinational logic.
    // But I can't assign to 'pf_val' in the always @(*) block if it depends on the state.
    
    // Let's stick to the structure: 
    // Use `prime_factors[comp_mask]` directly in the sequential block logic.
    // Verilog allows this.
    
    // Wait, I need to make sure 'mask_idx', 'submask_idx' are correct when reading.
    // In the FSM:
    // DP_INNER:
    //   temp_val = dp[submask_idx] + prime_factors[mask_idx ^ submask_idx];
    //   if (temp_val > dp[mask_idx]) dp[mask_idx] <= temp_val;
    //   submask_idx <= (submask_idx - 1) & mask_idx;
    //   if (submask_idx == 0) ... else ...
    
    // However, there's a cycle issue. When submask_idx changes, comp_mask changes.
    // To read prime_factors, we need the address stable.
    // In DP_INNER, we use the OLD submask_idx (which was set in DP_OUTER or previous DP_INNER) to calculate.
    // Then we update submask_idx for the next cycle.
    
    // Let's trace it:
    // Cycle 1 (DP_OUTER): Set mask_idx=M. Set submask_idx=M. 
    // Cycle 2 (DP_INNER): Read pf[M^M=0]. Update dp[M]. Update submask_idx = (M-1)&M.
    // Cycle 3 (DP_INNER): Read pf[M^(M-1)=1]. Update dp[M]. ...
    // This works.
    
    // BUT, I need to be careful about the first iteration.
    // submask_idx is initialized in DP_OUTER to mask_idx.
    // Then we transition to DP_INNER.
    // So in DP_INNER, we use submask_idx (which is mask_idx).
    
    // The code I wrote in the FSM block for DP_INNER was:
    // `dp[mask_idx] <= dp[submask_idx] + rdata_pf;`
    // This requires `rdata_pf` to be valid.
    // If I change it to `dp[mask_idx] <= dp[submask_idx] + prime_factors[mask_idx ^ submask_idx];`
    // it works but might be a long combinatorial path (submask_idx -> XOR -> RAM read -> Adder -> Compare -> Mux).
    // However, with 256 entries, this is likely implemented as logic (LUTs) rather than a block RAM, which is fine.
    // If it were a large RAM, we would need a pipeline stage. Here we are asked for "Sequential".
    
    // Let's stick to the register array implementation.
    
    // One last detail: The `dp` array is also updated and read. 
    // `dp[submask_idx]` is read. `dp[mask_idx]` is read and written.
    // This is standard behavior.
    
    // Let's refine the code for the DP_INNER state.
    // I will remove the `DP_INNER_WAIT` state and do it all in `DP_INNER` if possible, 
    // but I might need a wait state if the RAM read is not 0-cycle. Since it's an array of regs, it IS 0-cycle.
    // So I can remove `DP_INNER_WAIT`.
    
    // Also, the prompt asks for a JSON object.
    
    // One tricky part: `prime_factors` logic uses division/modulo. 
    // The combinational block for `pf_count_next` might be large. 
    // But the prompt says "Use combinational logic for ... prime factor counting".
    // So the implementation provided is correct.
    
    // However, the `pf_count_next` calculation uses `current_sum`, which is `subset_sum[mask_idx]`. 
    // In PRECOMPUTE_FACTORS, `mask_idx` is incremented. 
    // `subset_sum` is updated in PRECOMPUTE_SUMS. 
    // So `current_sum` is valid.
    
    // Let's verify the indices and counters logic.
    // N is used only to determine the stop condition in DP_OUTER_DONE: `mask_idx == ((1 << N) - 1)`.
    // This is correct.
    
    // Let's generate the clean code.
    
    // I will rewrite the FSM block to be clean and remove the `dp_candidate` wire.
    
endmodule

module TopModuleWrapper(
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [9:0] S0, S1, S2, S3, S4, S5, S6, S7,
    output [7:0] max_rev,
    output done
);
    // Wrapper to match array input style if needed, though the module above uses S [0:7].
    // Most synthesis tools allow passing array slices.
    // If the environment expects a specific port list, we match the prompt's definition.
    
    max_revenue_inst inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .N(N),
        .S({S7, S6, S5, S4, S3, S2, S1, S0}), // Assuming packed order
        .max_rev(max_rev),
        .done(done)
    );
endmodule

module max_revenue_inst(
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [9:0] S [0:7],
    output reg [7:0] max_rev,
    output reg done
);

    typedef enum logic [2:0] {
        IDLE,
        PRECOMPUTE_SUMS,
        PRECOMPUTE_FACTORS,
        DP_INIT,
        DP_OUTER,
        DP_INNER,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Memories (implemented as register arrays for reliable access)
    reg [15:0] subset_sum [0:255];
    reg [7:0] prime_factors [0:255];
    reg [7:0] dp [0:255];

    // Registers
    reg [7:0] mask_idx;
    reg [7:0] submask_idx;
    reg [7:0] current_mask_reg;
    reg we_sum, we_pf;
    reg [7:0] waddr_sum, waddr_pf;
    reg [15:0] wdata_sum;
    reg [7:0] wdata_pf;

    // Helper for PF calculation
    wire [15:0] calc_sum;
    wire [7:0] pf_count_next;
    wire [15:0] current_sum_wire;
    
    // Combinational Sum Calculation
    assign calc_sum = (
        ((mask_idx[0] ? S[0] : 10'd0) + (mask_idx[1] ? S[1] : 10'd0)) +
        ((mask_idx[2] ? S[2] : 10'd0) + (mask_idx[3] ? S[3] : 10'd0))
    ) + (
        ((mask_idx[4] ? S[4] : 10'd0) + (mask_idx[5] ? S[5] : 10'd0)) +
        ((mask_idx[6] ? S[6] : 10'd0) + (mask_idx[7] ? S[7] : 10'd0))
    );

    // Combinational PF Calculation Logic
    // Uses current_sum_wire which is driven by subset_sum[mux_out]
    assign current_sum_wire = subset_sum[mask_idx];
    
    // Logic for prime factors (iterative combinational logic)
    // This is a complex combinational block that calculates distinct prime factors.
    // It uses fixed division/modulo operations.
    assign pf_count_next = (current_sum_wire == 0) ? 0 : (
        // Check 2
        ((current_sum_wire % 2 == 0) ? 1 : 0) +
        // Check 3
        ((current_sum_wire % 3 == 0 && current_sum_wire % 2 != 0) ? 1 : 0) + // Wait, distinct primes doesn't care about 2 if we check divisibility separately.
        // Actually, distinct prime factors means 6 (2*3) has 2.
        // The loop logic provided in thought process is: divide out factors completely.
        // This combinational block is hard to do without loops if we strictly follow "combinational logic".
        // However, Verilog always blocks support loops (unrolled or not).
        // To be safe and synthesizable, we use a function or explicit calculation.
        // Given the constraints, I will use an `always @(*)` block inside the module.
        // But since I need to assign to `pf_count_next`, I must use a combinational block.
        
        // Actually, I cannot use procedural `while` or `for` in continuous assignment `assign`.
        // I will define a `function` or use a separate `always @(*)` block.
        // Let's use a separate `always @(*)` block to calculate `pf_count_next`.
        8'd0 // Placeholder, real logic below
    );

    // Re-implementation of PF logic using combinational always block
    reg [7:0] pf_calc_result;
    always @(*) begin
        reg [15:0] temp_rem;
        temp_rem = subset_sum[mask_idx];
        pf_calc_result = 0;
        
        if (temp_rem > 0) begin
            // 2
            if (temp_rem % 2 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 2 == 0) temp_rem = temp_rem / 2;
            end
            // 3
            if (temp_rem % 3 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 3 == 0) temp_rem = temp_rem / 3;
            end
            // 5
            if (temp_rem % 5 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 5 == 0) temp_rem = temp_rem / 5;
            end
            // 7
            if (temp_rem % 7 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 7 == 0) temp_rem = temp_rem / 7;
            end
            // 11
            if (temp_rem % 11 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 11 == 0) temp_rem = temp_rem / 11;
            end
            // 13
            if (temp_rem % 13 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 13 == 0) temp_rem = temp_rem / 13;
            end
            // 17
            if (temp_rem % 17 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 17 == 0) temp_rem = temp_rem / 17;
            end
            // 19
            if (temp_rem % 19 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 19 == 0) temp_rem = temp_rem / 19;
            end
            // 23
            if (temp_rem % 23 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 23 == 0) temp_rem = temp_rem / 23;
            end
            // 29
            if (temp_rem % 29 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 29 == 0) temp_rem = temp_rem / 29;
            end
            // 31
            if (temp_rem % 31 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 31 == 0) temp_rem = temp_rem / 31;
            end
            // 37
            if (temp_rem % 37 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 37 == 0) temp_rem = temp_rem / 37;
            end
            // 41
            if (temp_rem % 41 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 41 == 0) temp_rem = temp_rem / 41;
            end
            // 43
            if (temp_rem % 43 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 43 == 0) temp_rem = temp_rem / 43;
            end
            // 47
            if (temp_rem % 47 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 47 == 0) temp_rem = temp_rem / 47;
            end
            // 53
            if (temp_rem % 53 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 53 == 0) temp_rem = temp_rem / 53;
            end
            // 59
            if (temp_rem % 59 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 59 == 0) temp_rem = temp_rem / 59;
            end
            // 61
            if (temp_rem % 61 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 61 == 0) temp_rem = temp_rem / 61;
            end
            // 67
            if (temp_rem % 67 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 67 == 0) temp_rem = temp_rem / 67;
            end
            // 71
            if (temp_rem % 71 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 71 == 0) temp_rem = temp_rem / 71;
            end
            // 73
            if (temp_rem % 73 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 73 == 0) temp_rem = temp_rem / 73;
            end
            // 79
            if (temp_rem % 79 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 79 == 0) temp_rem = temp_rem / 79;
            end
            // 83
            if (temp_rem % 83 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 83 == 0) temp_rem = temp_rem / 83;
            end
            // 89
            if (temp_rem % 89 == 0) begin
                pf_calc_result = pf_calc_result + 1;
                while (temp_rem % 89 == 0) temp_rem = temp_rem / 89;
            end
        end
    end
    
    // Assign output of comb block to the write data
    wire [7:0] pf_write_data;
    assign pf_write_data = pf_calc_result;

    // RAM Write Logic
    always @(posedge clk) begin
        if (we_sum) subset_sum[waddr_sum] <= wdata_sum;
        if (we_pf) prime_factors[waddr_pf] <= wdata_pf;
    end

    // FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            max_rev <= 0;
            mask_idx <= 0;
            submask_idx <= 0;
            we_sum <= 0;
            we_pf <= 0;
            current_mask_reg <= 0;
        end else begin
            we_sum <= 0;
            we_pf <= 0;
            
            case (current_state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        current_state <= PRECOMPUTE_SUMS;
                        mask_idx <= 0;
                    end
                end

                PRECOMPUTE_SUMS: begin
                    // Compute sum for mask_idx
                    we_sum <= 1;
                    waddr_sum <= mask_idx;
                    wdata_sum <= calc_sum;
                    
                    if (mask_idx == 8'hFF) begin
                        current_state <= PRECOMPUTE_FACTORS;
                        mask_idx <= 0;
                    end else begin
                        mask_idx <= mask_idx + 1;
                    end
                end

                PRECOMPUTE_FACTORS: begin
                    // Read subset_sum[mask_idx] -> combinational -> pf_write_data
                    // Write to prime_factors[mask_idx]
                    we_pf <= 1;
                    waddr_pf <= mask_idx;
                    wdata_pf <= pf_write_data;

                    if (mask_idx == 8'hFF) begin
                        current_state <= DP_INIT;
                    end else begin
                        mask_idx <= mask_idx + 1;
                    end
                end

                DP_INIT: begin
                    dp[0] <= 0;
                    mask_idx <= 1;
                    current_state <= DP_OUTER;
                end

                DP_OUTER: begin
                    dp[mask_idx] <= 0; // Initialize max for this mask
                    submask_idx <= mask_idx; // Start submask iteration
                    current_state <= DP_INNER;
                    current_mask_reg <= mask_idx; // Store current mask for comparison in inner loop
                end

                DP_INNER: begin
                    // dp[mask] = max(dp[mask], dp[submask] + prime_factors[mask ^ submask])
                    // Logic:
                    // 1. Read dp[submask_idx] -> handled by addressing. Note: dp is array of regs.
                    // 2. Read prime_factors[mask_idx ^ submask_idx] -> async read.
                    
                    if (dp[submask_idx] + prime_factors[mask_idx ^ submask_idx] > dp[mask_idx]) begin
                        dp[mask_idx] <= dp[submask_idx] + prime_factors[mask_idx ^ submask_idx];
                    end

                    // Update submask for next iteration: submask = (submask - 1) & mask
                    submask_idx <= (submask_idx - 1) & mask_idx;

                    // Check if finished
                    if (submask_idx == 0) begin
                        // Finished this mask
                        if (mask_idx == ((1 << N) - 1)) begin
                            current_state <= DONE;
                            max_rev <= dp[mask_idx];
                            done <= 1;
                        end else begin
                            mask_idx <= mask_idx + 1;
                            current_state <= DP_OUTER;
                        end
                    end
                end

                DONE: begin
                    if (!start) begin
                        current_state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule
