module fruit_arrangement(
    input clk,
    input rst_n,
    input start,
    input [4:0] A,
    input [4:0] C,
    input [4:0] M,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    parameter MOD = 32'd1000000007;
    
    // State encoding
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam SUM = 3'b011;
    localparam DONE = 3'b100;

    // DP Memory signals
    // 4D array: dp[11][11][11][4]
    // Depth: 11*11*11*4 = 5324
    // Use 2D memory: addr = ((a*11 + c)*11 + m)*4 + last
    reg [31:0] dp [0:5323];
    reg [12:0] addr_wr; // 13 bits enough for 5324
    reg [31:0] data_wr;
    reg we;
    reg [12:0] addr_rd_1;
    reg [12:0] addr_rd_2;
    reg [12:0] addr_rd_3;
    wire [31:0] data_rd_1;
    wire [31:0] data_rd_2;
    wire [31:0] data_rd_3;
    
    // State machine variables
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Iterator variables
    reg [3:0] iter_a;
    reg [3:0] iter_c;
    reg [3:0] iter_m;
    reg [1:0] iter_last;
    
    // Valid flags for input
    reg valid_input;
    
    // Intermediate values for calculation
    reg [31:0] current_val;
    reg [31:0] temp_sum;
    
    // Completion flags
    reg compute_done;
    reg init_done;
    
    // Instantiate 3 async read ports for DP memory
    // Port 1: Read current state
    assign data_rd_1 = dp[addr_rd_1];
    // Port 2: Read target for apple
    assign data_rd_2 = dp[addr_rd_2];
    // Port 3: Read target for sum
    assign data_rd_3 = dp[addr_rd_3];

    // Helper task to calculate address
    // Function cannot be used with multi-dimensional array in some synthesizers easily
    // So we calculate manually in logic
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            we <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 0;
                    result <= 0;
                    if (start) begin
                        // Check validity
                        if (A > 0 && A <= 10 && C > 0 && C <= 10 && M > 0 && M <= 10) begin
                            valid_input <= 1;
                        end else begin
                            valid_input <= 0;
                        end
                    end
                end
                
                INIT: begin
                    // Reset memory loop
                    // We will use a counter to clear memory in IDLE->INIT or handle in INIT state
                    // Since we need to clear 5324 entries, it takes time. 
                    // We can do it sequentially in INIT state.
                    // We use iter_a, iter_c, iter_m, iter_last as counters here
                    if (!init_done) begin
                        // Logic handled in combinational block to set address and data
                        // Here we just perform the write
                        we <= 1;
                        data_wr <= (iter_a == 0 && iter_c == 0 && iter_m == 0 && iter_last == 0) ? 32'd1 : 32'd0;
                        // Increment counters logic in combinational block
                    end else begin
                        we <= 0;
                    end
                end
                
                COMPUTE: begin
                    // Read current state value
                    current_val <= data_rd_1;
                    // Prepare write for transitions (handled in combinational logic update below)
                    // We need to perform updates. 
                    // Since this is a single cycle update per state, we only update one target per cycle?
                    // No, standard DP needs accumulating. 
                    // To be efficient in hardware with 5324 states, we iterate and update specific neighbors.
                    // We iterate through (a, c, m, last). For each, we update neighbors if current_val > 0.
                    
                    // We will use the combinational block to calculate addresses for current and neighbors.
                    // We will write back accumulated value in the next cycle or same cycle?
                    // Since we read from 'current_val' register, we can write to 'data_wr' register.
                    // But we need to handle the accumulation with existing target value.
                    // This requires Read-Modify-Write. 
                    // Read target -> Add -> Write.
                    // We are already reading 3 ports. Port 2/3 are for targets.
                    
                    // Logic: if current_val > 0, calculate updates.
                    // Since we need to verify (iter_a, iter_c, iter_m, iter_last) satisfies A,C,M constraints.
                    if (compute_done) we <= 0;
                    else we <= 0; // Reset write enable, set only if needed in combo block
                end
                
                SUM: begin
                    // Summation happens in combinational logic
                    // Result is captured here
                    result <= temp_sum;
                    we <= 0;
                end
                
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Combinational Next State Logic and Control
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && valid_input) next_state = INIT;
                else next_state = IDLE;
            end
            
            INIT: begin
                if (init_done) next_state = COMPUTE;
                else next_state = INIT;
            end
            
            COMPUTE: begin
                if (compute_done) next_state = SUM;
                else next_state = COMPUTE;
            end
            
            SUM: next_state = DONE;
            
            DONE: next_state = DONE; // Stay here until reset
            
            default: next_state = IDLE;
        endcase
    end

    // Helper logic for address calculation and loops
    // We separate the control logic for counters to avoid complex sequential logic inside FSM
    // We will implement the counters as separate registers that run during specific states.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iter_a <= 0;
            iter_c <= 0;
            iter_m <= 0;
            iter_last <= 0;
            init_done <= 0;
            compute_done <= 0;
        end else begin
            // INIT Counter Logic (Linear scan to clear)
            if (state == INIT && !init_done) begin
                {iter_a, iter_c, iter_m, iter_last} <= {iter_a, iter_c, iter_m, iter_last} + 1;
                if ({iter_a, iter_c, iter_m, iter_last} == 13'd5323) begin // 11*11*11*4 - 1
                    init_done <= 1;
                end
            end else if (state == IDLE) begin
                {iter_a, iter_c, iter_m, iter_last} <= 0;
                init_done <= 0;
                compute_done <= 0;
            end

            // COMPUTE Counter Logic (Iterate all states)
            // Logic: iterate a 0..A, c 0..C, m 0..M, last 0..3
            if (state == COMPUTE && !compute_done) begin
                // Increment counters
                if (iter_last < 3) begin
                    iter_last <= iter_last + 1;
                end else begin
                    iter_last <= 0;
                    if (iter_m < M) begin
                        iter_m <= iter_m + 1;
                    end else begin
                        iter_m <= 0;
                        if (iter_c < C) begin
                            iter_c <= iter_c + 1;
                        end else begin
                            iter_c <= 0;
                            if (iter_a < A) begin
                                iter_a <= iter_a + 1;
                            end else begin
                                iter_a <= 0;
                                compute_done <= 1;
                            end
                        end
                    end
                end
            end else if (state != COMPUTE) begin
                iter_a <= 0;
                iter_c <= 0;
                iter_m <= 0;
                iter_last <= 0;
            end
        end
    end

    // Address Calculation Logic (Combinational)
    always @(*) begin
        // Calculate Address for Current State (Read Port 1)
        if (state == INIT) begin
            addr_rd_1 = {iter_a, iter_c, iter_m, iter_last}; // Using concat for index
            // Wait, concat a,c,m,last (3+3+3+2=11 bits). Max index 2047. Depth 5324. Need 13 bits.
            // Manual index calculation: 
            addr_rd_1 = ((iter_a * 11 + iter_c) * 11 + iter_m) * 4 + iter_last;
        end else if (state == COMPUTE) begin
            addr_rd_1 = ((iter_a * 11 + iter_c) * 11 + iter_m) * 4 + iter_last;
        end else begin
            addr_rd_1 = 0;
        end

        // Calculate Address for Transition Targets (Read Port 2 & 3) and Write Port
        // Default: keep old values
        addr_rd_2 = 0;
        addr_rd_3 = 0;
        addr_wr = 0;
        data_wr = 0;
        we = 0;

        if (state == INIT) begin
            we = 1;
            addr_wr = ((iter_a * 11 + iter_c) * 11 + iter_m) * 4 + iter_last;
            data_wr = (iter_a == 0 && iter_c == 0 && iter_m == 0 && iter_last == 0) ? 32'd1 : 32'd0;
        end 
        else if (state == COMPUTE && !compute_done) begin
            // We have current_val from previous cycle read (data_rd_1)
            if (current_val != 0) begin
                // Try transition to Apple (last=1)
                if (iter_last != 1 && iter_a < A) begin
                    // Calculate target address for Apple
                    addr_rd_2 = (((iter_a + 1) * 11 + iter_c) * 11 + iter_m) * 4 + 1;
                    // Since we need Read-Modify-Write, we need to write in THIS cycle? 
                    // But we only have 1 write port. We can only update 1 target per cycle if we rely on read value.
                    // However, 'current_val' is constant for this cycle.
                    // We can write to 'Apple' target.
                    // But we also need to check 'Cherry' and 'Mango'.
                    // Since we are in a loop, we can iterate 'iter_last' 0..3. 
                    // For each (a,c,m,l), we update 3 neighbors (if valid).
                    // We can unroll this. We have 3 read ports. We can read 3 targets at once.
                    // We need 3 write operations? No, only 1 write port.
                    // Workaround: It takes 3 clock cycles per state to update 3 targets? 
                    // Or: We just update one target per state iteration, and we iterate (a,c,m) 
                    // and 'last' as 0,1,2,3 to cover all. This effectively triples the loop count.
                    
                    // Let's optimize: We use a small internal state within COMPUTE.
                    // Since the prompt asks for "simple DP", let's use a slower but simpler method.
                    // We will use 3 cycles per (a,c,m) state. 
                    // We add a sub-state register: sub_comp_step [1:0].
                    
                    // To stick to the "3000 cycles" estimate (states 1331 * transitions 3 = ~4000), 
                    // we need to perform 1 update per cycle roughly.
                    // We can use 3 write cycles per (a,c,m,last) group.
                    // But 'last' is 0..3. Base case (0,0,0,0) updates 3.
                    // Actually, we can just treat the loops as iterating a, c, m.
                    // Inside, we check all 4 'last' types? 
                    // Let's just use the `iter_last` loop provided in the sequential block.
                    // When we are at (a,c,m,0), we don't update (base case usually? No, base is only (0,0,0,0)).
                    // For general (a,c,m,l), we read value at (a,c,m,l). 
                    // We update 3 neighbors.
                    // Since we have 1 write port, we need 3 cycles to update all 3 neighbors.
                    // We will introduce a `step` register for the COMPUTE state.
                end
            end
        end
        else if (state == SUM) begin
            // Read 3 values for final sum
            addr_rd_1 = ((A * 11 + C) * 11 + M) * 4 + 1; // Apple
            addr_rd_2 = ((A * 11 + C) * 11 + M) * 4 + 2; // Cherry
            addr_rd_3 = ((A * 11 + C) * 11 + M) * 4 + 3; // Mango
        end
    end

    // Revised Logic for COMPUTE to handle Read-Modify-Write with 1 write port
    // We will split COMPUTE into sub-cycles.
    // New register: reg [1:0] comp_step;
    reg [1:0] comp_step;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            comp_step <= 0;
        end else begin
            if (state == COMPUTE && !compute_done) begin
                comp_step <= comp_step + 1;
                if (comp_step == 2'd2) comp_step <= 0; // 0,1,2 cycles per valid update
            end else begin
                comp_step <= 0;
            end
        end
    end

    // Actual Control for Compute State
    always @(*) begin
        // Defaults
        we = 0;
        addr_wr = 0;
        data_wr = 0;
        // Read targets setup (already done in previous combinational block, but we refine here)
        // Note: We cannot change address read based on comp_step easily without causing read latency issues.
        // So, let's design it differently:
        // In cycle 0: Read current value (implicit in FSM - we used addr_rd_1)
        // In cycle 1: Calculate 3 targets, perform 1 update (if any), mark update index.
        // To keep it simple and working within constraints:
        // We iterate a, c, m. For each (a,c,m), we iterate last 0..3.
        // For each valid (a,c,m,last), we perform 3 updates.
        // To do 3 updates with 1 write port, we need 3 clock cycles (or a 3-stage pipeline inside the loop).
        
        if (state == COMPUTE && !compute_done && current_val != 0) begin
            // We have 'current_val' from (iter_a, iter_c, iter_m, iter_last).
            // We need to update neighbors.
            
            case (comp_step)
                2'd0: begin // Update Apple (if valid)
                    if (iter_last != 3'd1 && iter_a < A) begin
                        we = 1;
                        addr_wr = (((iter_a + 1) * 11 + iter_c) * 11 + iter_m) * 4 + 1;
                        // We need to read the existing value at addr_wr to add to it.
                        // But we have only read ports set up. 
                        // We need to mux the read data for the adder.
                        // Let's assume we handle the adder in sequential logic to simplify combinational paths.
                        // Actually, we should just perform the addition in sequential logic.
                        // So, we need to read target value, add current_val, write back.
                        // This implies we need a temp register to hold 'target_val + current_val'.
                        // Wait, we can't easily read the target value if we are also reading the current value.
                        // The prompt implies "All operations are combinational within the state machine cycles".
                        // This usually means "pseudo-combinational", i.e. state machine controls data path.
                        // Let's use a temporary register 'accum_val' which stores 'target + current'.
                        // We write 'accum_val' to memory.
                        // In step 0, we write 'current_val' to 'Apple' target address? No, we need existing + current.
                        // We need to fetch existing. 
                        // We can reconfigure read ports dynamically? 
                        // Since we need to read 'current' (at iter_a, iter_c, iter_m, iter_last) AND 'target' (to update).
                        // Port 1 is fixed to current state. Port 2 is target.
                        // But we need to read 'target' value to add.
                        // So in step 0, we set addr_rd_2 = Apple Target.
                        // In step 1, we perform add and write.
                        // This means we need 2 cycles per transition.
                        // This doubles the latency, but still fits (10^3 * 3 * 2 = 6000 cycles).
                        // Let's adopt this 2-cycle scheme.
                        
                        // Revised Plan for COMPUTE loop:
                        // Step 0 (even): Configure read port for Target. Wait.
                        // Step 1 (odd): Write back (Target + Current).
                        // Wait, we need 3 targets. 3 * 2 = 6 cycles per state. (1331 * 6 ~ 8000 cycles).
                        // Acceptable.
                        
                        // Let's implement the state logic.
                        // We need a way to know which target we are processing (Apple, Cherry, Mango).
                        // We can use a 2-bit target_select register.
                    end
                end
            endcase
        end
    end
    
    // Due to complexity of generating synthesizable code for 4D array R/W with single port in combo logic, 
    // we will implement a cleaner sequential R-M-W control flow.
    
    // Re-defining the COMPUTE state logic completely to be safe and synthesizable.
    // We will use a helper state 'COMP_SUB' inside the main FSM.
    // The FSM will go: IDLE -> INIT -> [COMPUTE -> COMP_SUB] -> SUM -> DONE
    // But the requirement is a single sequential module. We can handle sub-states inside COMPUTE.
    
    // Let's reset the logic block and write a clean implementation.
    // We will keep the previous boilerplate but override the compute logic.
    
endmodule

// Re-implementation of the module with cleaner logic
// We need to include the logic inside the module.
// Actually, the previous block ended. I need to provide the full code.
// I will provide the full code below, combining the logic.

module fruit_arrangement(
    input clk,
    input rst_n,
    input start,
    input [4:0] A,
    input [4:0] C,
    input [4:0] M,
    output reg [31:0] result,
    output reg done
);

    parameter MOD = 32'd1000000007;
    
    // State encoding
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam SUM = 3'b011;
    localparam DONE = 3'b100;

    // DP Memory: 5324 entries
    reg [31:0] dp [0:5323];
    
    // FSM registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Iterators
    reg [3:0] iter_a;
    reg [3:0] iter_c;
    reg [3:0] iter_m;
    reg [1:0] iter_last;
    
    // Valid input flag
    reg valid_input;
    
    // Compute control variables
    reg [1:0] target_step; // 0: Apple, 1: Cherry, 2: Mango
    reg [31:0] current_val_reg; // Latch current value for use in update
    reg [31:0] target_val_reg;  // Latch target value read from memory
    reg [12:0] target_addr_reg; // Latch target address
    
    // Helper functions for address calculation
    function [12:0] calc_addr;
        input [3:0] a;
        input [3:0] c;
        input [3:0] m;
        input [1:0] l;
        begin
            calc_addr = ((a * 11 + c) * 11 + m) * 4 + l;
        end
    endfunction

    // FSM State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        if (A > 0 && A <= 10 && C > 0 && C <= 10 && M > 0 && M <= 10)
                            valid_input <= 1;
                        else
                            valid_input <= 0;
                    end
                end
                
                INIT: begin
                    // Initialize memory using iter variables
                    // We use target_addr_reg as write address to save logic
                    if (!(iter_a == 0 && iter_c == 0 && iter_m == 0 && iter_last == 0)) begin
                        dp[calc_addr(iter_a, iter_c, iter_m, iter_last)] <= 32'd0;
                    end
                    // Set base case
                    if (iter_a == 0 && iter_c == 0 && iter_m == 0 && iter_last == 0) begin
                        dp[calc_addr(0, 0, 0, 0)] <= 32'd1;
                    end
                end
                
                COMPUTE: begin
                    // Main DP logic
                    // We iterate through valid states (a<=A, c<=C, m<=M, l in 0..3)
                    // We only perform updates if current_val_reg > 0
                    
                    if (current_val_reg != 0) begin
                        // Perform update based on target_step
                        case (target_step)
                            2'd0: begin // Apple (l=1)
                                if (iter_last != 2'd1 && iter_a < A) begin
                                    dp[target_addr_reg] <= (target_val_reg + current_val_reg) % MOD;
                                end
                            end
                            2'd1: begin // Cherry (l=2)
                                if (iter_last != 2'd2 && iter_c < C) begin
                                    dp[target_addr_reg] <= (target_val_reg + current_val_reg) % MOD;
                                end
                            end
                            2'd2: begin // Mango (l=3)
                                if (iter_last != 2'd3 && iter_m < M) begin
                                    dp[target_addr_reg] <= (target_val_reg + current_val_reg) % MOD;
                                end
                            end
                        endcase
                    end
                end
                
                SUM: begin
                    // Accumulate final result from dp[A][C][M][1..3]
                    // We use target_val_reg to accumulate sum in previous cycle logic
                    result <= (dp[calc_addr(A, C, M, 1)] + dp[calc_addr(A, C, M, 2)] + dp[calc_addr(A, C, M, 3)]) % MOD;
                end
                
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Next State Logic & Iterator Control
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && valid_input) next_state = INIT;
                else next_state = IDLE;
            end
            
            INIT: begin
                // Finish when we hit max index 5323
                if (iter_a == 10 && iter_c == 10 && iter_m == 10 && iter_last == 3) next_state = COMPUTE;
                else next_state = INIT;
            end
            
            COMPUTE: begin
                // Loop control: We iterate a(0..A), c(0..C), m(0..M), last(0..3)
                // And for each, we do 3 steps (Apple, Cherry, Mango checks)
                // Logic: We are done when (iter_a > A || iter_c > C || iter_m > M) effectively loop ends.
                // But we iterate precisely 0..A, 0..C, 0..M.
                // The loop inside COMPUTE goes through all iterations.
                // When iterations complete, move to SUM.
                
                // Check loop completion condition
                if ( (iter_a > A || (iter_a == A && iter_c > C) || (iter_a == A && iter_c == C && iter_m > M)) ) begin
                     next_state = SUM;
                end else begin
                     next_state = COMPUTE;
                end
            end
            
            SUM: next_state = DONE;
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic for Iterators and Flags
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iter_a <= 0; iter_c <= 0; iter_m <= 0; iter_last <= 0;
            target_step <= 0;
            current_val_reg <= 0;
            target_val_reg <= 0;
        end else begin
            
            if (state == INIT) begin
                {iter_a, iter_c, iter_m, iter_last} <= {iter_a, iter_c, iter_m, iter_last} + 1;
            end
            
            else if (state == COMPUTE) begin
                // Logic to drive address reads and handle 3-step updates per state
                // Cycle 0: Read current state value at (iter_a, iter_c, iter_m, iter_last)
                // Cycle 1: Set target info for Apple (if valid), Read Target
                // Cycle 2: Write Update Apple
                // Cycle 3: Set target info for Cherry, Read Target
                // Cycle 4: Write Update Cherry
                // Cycle 5: Set target info for Mango, Read Target
                // Cycle 6: Write Update Mango
                // Cycle 7: Advance iterators
                
                // We need a sub-cycle counter to manage this flow
                // reg [3:0] compute_cycle;
                // To keep it simple and robust:
                // We use target_step to select which transition to process.
                // We also need to latch the value of the CURRENT state to add.
                // Reading DP[addr] takes 1 cycle. So:
                // State 1: Set Read Address for Current State. 
                // State 2: Latch Current Value. Start processing transitions.
                // State 3+: Process transitions.
                
                // Let's refine the loop structure.
                // We will use a small sub-state machine inside the always block logic or counters.
            end
        end
    end
    
    // Logic Breakdown for COMPUTE state
    // We need to implement the loop iteration (a, c, m, last) and the 3 internal updates.
    // Let's introduce a counter 'comp_cycle' to sequence the steps.
    reg [3:0] comp_cycle;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            comp_cycle <= 0;
        end else if (state == COMPUTE) begin
            comp_cycle <= comp_cycle + 1;
            // We cycle through: 
            // 0: Read Current (Latch current_val_reg)
            // 1: Process Apple (Read Target, if ready to write)
            // 2: Write Apple (if valid)
            // 3: Process Cherry
            // 4: Write Cherry
            // 5: Process Mango
            // 6: Write Mango
            // 7: Advance Iterators, reset to 0
            
            if (comp_cycle == 4'd7) begin
                comp_cycle <= 0;
                // Increment iterators
                if (iter_last < 3) begin
                    iter_last <= iter_last + 1;
                end else begin
                    iter_last <= 0;
                    if (iter_m < M) begin
                        iter_m <= iter_m + 1;
                    end else begin
                        iter_m <= 0;
                        if (iter_c < C) begin
                            iter_c <= iter_c + 1;
                        end else begin
                            iter_c <= 0;
                            if (iter_a < A) begin
                                iter_a <= iter_a + 1;
                            end else begin
                                iter_a <= 15; // Mark as done (will cause next_state SUM)
                            end
                        end
                    end
                end
            end
        end else begin
            comp_cycle <= 0;
            iter_a <= 0; iter_c <= 0; iter_m <= 0; iter_last <= 0;
        end
    end

    // Read/Write Control for COMPUTE state
    // This combinational block controls the 'dp' memory reads and writes based on 'comp_cycle'
    always @(*) begin
        // Defaults
        // No need for explicit we, data_wr signals as they are handled in sequential block logic
        // actually, we need to assign the write enable and data to the sequential block logic for dp
        // Since we are writing to dp array directly in the sequential block, we need to know what to write.
        // We need to set 'current_val_reg', 'target_val_reg', 'target_addr_reg' in this block or sequential.
        
        // Reset signals to prevent latches
        // We will set values in sequential logic based on comp_cycle.
    end

    // Revised Sequential Logic for Compute State (Putting it all together)
    // We need to re-organize. We will use the 'always @(posedge clk)' block to handle the specific logic.
    // 
    // NEW PLAN for Compute State:
    // 
    // Loop Variables: iter_a (0..A), iter_c (0..C), iter_m (0..M), iter_last (0..3).
    // 
    // Step 0 (Cycle 0): Read dp[iter_a][iter_c][iter_m][iter_last] -> current_val_reg.
    // Step 1 (Cycle 1): If current_val_reg > 0:
    //      a) If iter_last != 1 && iter_a < A: 
    //          Read dp[iter_a+1][iter_c][iter_m][1] -> target_val_reg. 
    //          target_addr_reg = calc(...)
    // Step 2 (Cycle 2): Write dp[target_addr_reg] = (target_val_reg + current_val_reg) % MOD.
    // Step 3 (Cycle 3): If current_val_reg > 0:
    //      b) If iter_last != 2 && iter_c < C:
    //          Read dp[iter_a][iter_c+1][iter_m][2].
    // Step 4 (Cycle 4): Write...
    // Step 5 (Cycle 5): If current_val_reg > 0:
    //      c) If iter_last != 3 && iter_m < M:
    //          Read dp[iter_a][iter_c][iter_m+1][3].
    // Step 6 (Cycle 6): Write...
    // Step 7 (Cycle 7): Increment iterators.
    
    // To implement this cleanly in the provided structure:
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_val_reg <= 0;
            target_val_reg <= 0;
            target_addr_reg <= 0;
            // reset dp logic done in INIT
        end else if (state == COMPUTE) begin
            case (comp_cycle)
                0: begin
                    // Read current state
                    // Note: In verilog, dp[addr] read is async if we use it in combo, or sync if we register it.
                    // Here we read it into a register.
                    current_val_reg <= dp[calc_addr(iter_a, iter_c, iter_m, iter_last)];
                end
                1: begin // Prepare Apple Update
                    if (current_val_reg != 0 && iter_last != 1 && iter_a < A) begin
                        target_addr_reg <= calc_addr(iter_a + 1, iter_c, iter_m, 1);
                        target_val_reg <= dp[calc_addr(iter_a + 1, iter_c, iter_m, 1)];
                    end else begin
                        target_addr_reg <= 0; // Invalidate
                    end
                end
                2: begin // Execute Apple Update
                    if (target_addr_reg != 0) begin
                        dp[target_addr_reg] <= (target_val_reg + current_val_reg) % MOD;
                    end
                end
                3: begin // Prepare Cherry Update
                    if (current_val_reg != 0 && iter_last != 2 && iter_c < C) begin
                        target_addr_reg <= calc_addr(iter_a, iter_c + 1, iter_m, 2);
                        target_val_reg <= dp[calc_addr(iter_a, iter_c + 1, iter_m, 2)];
                    end else begin
                        target_addr_reg <= 0;
                    end
                end
                4: begin // Execute Cherry Update
                    if (target_addr_reg != 0) begin
                        dp[target_addr_reg] <= (target_val_reg + current_val_reg) % MOD;
                    end
                end
                5: begin // Prepare Mango Update
                    if (current_val_reg != 0 && iter_last != 3 && iter_m < M) begin
                        target_addr_reg <= calc_addr(iter_a, iter_c, iter_m + 1, 3);
                        target_val_reg <= dp[calc_addr(iter_a, iter_c, iter_m + 1, 3)];
                    end else begin
                        target_addr_reg <= 0;
                    end
                end
                6: begin // Execute Mango Update
                    if (target_addr_reg != 0) begin
                        dp[target_addr_reg] <= (target_val_reg + current_val_reg) % MOD;
                    end
                end
                // 7 is handled in the iterator logic (incrementing loop variables)
            endcase
        end
    end

endmodule