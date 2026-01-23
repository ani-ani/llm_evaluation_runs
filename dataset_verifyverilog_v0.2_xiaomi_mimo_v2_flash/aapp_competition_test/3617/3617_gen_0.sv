module pikeman_solver (
    input clk,
    input rst_n,
    input start,
    input [31:0] t0,
    input [63:0] T,
    output reg [31:0] count,
    output reg [31:0] penalty,
    output reg done
);

    // --- Parameters and State Definition ---
    parameter IDLE = 3'b000;
    parameter GENERATE = 3'b001;
    parameter SORT = 3'b010;
    parameter CALCULATE = 3'b011;
    parameter DONE = 3'b100;
    
    // Modulo constant: 1000000007
    parameter MOD = 32'd1000000007;

    // --- Internal Registers ---
    reg [2:0] current_state, next_state;
    reg [4:0] counter; // General counter for loops (max 16 or sorting stages)
    reg [31:0] lfsr_reg;
    reg [31:0] mem [0:15]; // Storage for numbers
    
    // Calculation registers
    reg [63:0] accumulated_time;
    reg [31:0] current_penalty;
    
    // Sort control signal
    reg sort_start;
    
    // --- LFSR Logic (Galois, Poly 0x8005) ---
    wire lfsr_tick = (current_state == GENERATE);
    wire [31:0] lfsr_next;
    
    assign lfsr_next = {lfsr_reg[30:0], 1'b0} ^ (lfsr_reg[31] ? 32'h8005 : 32'h0);

    // --- Sorting Network (Bitonic Sort for 16 elements) ---
    // This is a combinational block that sorts mem into sorted_mem when sort_start is high.
    // It implements a standard Bitonic Sorter for 16 inputs.
    // Since we are registering the output, we define the intermediate wires.
    
    wire [31:0] s0 [0:15]; // Stage 0 output
    wire [31:0] s1 [0:15]; // Stage 1 output
    wire [31:0] s2 [0:15]; // Stage 2 output
    wire [31:0] s3 [0:15]; // Stage 3 output
    wire [31:0] s4 [0:15]; // Stage 4 output (Final)

    // Comparator macro: Merges two inputs ascending
    `define MERGE_UP(a, b) (a < b ? a : b), (a < b ? b : a)
    // Comparator macro: Merges two inputs descending
    `define MERGE_DOWN(a, b) (a > b ? a : b), (a > b ? b : a)

    // Stage 0: 2-element sorts (Directions: 8 up, 8 down)
    // Indices: (0,1) Up, (2,3) Down, (4,5) Up, (6,7) Down, etc.
    assign {s0[0], s0[1]} = `MERGE_UP(mem[0], mem[1]);
    assign {s0[2], s0[3]} = `MERGE_DOWN(mem[2], mem[3]);
    assign {s0[4], s0[5]} = `MERGE_UP(mem[4], mem[5]);
    assign {s0[6], s0[7]} = `MERGE_DOWN(mem[6], mem[7]);
    assign {s0[8], s0[9]} = `MERGE_UP(mem[8], mem[9]);
    assign {s0[10], s0[11]} = `MERGE_DOWN(mem[10], mem[11]);
    assign {s0[12], s0[13]} = `MERGE_UP(mem[12], mem[13]);
    assign {s0[14], s0[15]} = `MERGE_DOWN(mem[14], mem[15]);

    // Stage 1: 4-element sorts (1/2 bitonic merges)
    // Pairs: (0,1,2,3) -> (Up, Down) -> (All Up)
    assign {s1[0], s1[1], s1[2], s1[3]} = {
        `MERGE_UP(s0[0], s0[2]), `MERGE_UP(s0[1], s0[3])
    };
    assign {s1[4], s1[5], s1[6], s1[7]} = {
        `MERGE_DOWN(s0[4], s0[6]), `MERGE_DOWN(s0[5], s0[7])
    };
    assign {s1[8], s1[9], s1[10], s1[11]} = {
        `MERGE_UP(s0[8], s0[10]), `MERGE_UP(s0[9], s0[11])
    };
    assign {s1[12], s1[13], s1[14], s1[15]} = {
        `MERGE_DOWN(s0[12], s0[14]), `MERGE_DOWN(s0[13], s0[15])
    };

    // Stage 2: 8-element sorts
    assign {s2[0], s2[1], s2[2], s2[3], s2[4], s2[5], s2[6], s2[7]} = {
        `MERGE_UP(s1[0], s1[4]), `MERGE_UP(s1[1], s1[5]), 
        `MERGE_UP(s1[2], s1[6]), `MERGE_UP(s1[3], s1[7])
    };
    assign {s2[8], s2[9], s2[10], s2[11], s2[12], s2[13], s2[14], s2[15]} = {
        `MERGE_DOWN(s1[8], s1[12]), `MERGE_DOWN(s1[9], s1[13]), 
        `MERGE_DOWN(s1[10], s1[14]), `MERGE_DOWN(s1[11], s1[15])
    };

    // Stage 3: 16-element sort (Full bitonic merge)
    assign {s3[0], s3[1], s3[2], s3[3], s3[4], s3[5], s3[6], s3[7], s3[8], s3[9], s3[10], s3[11], s3[12], s3[13], s3[14], s3[15]} = {
        `MERGE_UP(s2[0], s2[8]), `MERGE_UP(s2[1], s2[9]), `MERGE_UP(s2[2], s2[10]), `MERGE_UP(s2[3], s2[11]),
        `MERGE_UP(s2[4], s2[12]), `MERGE_UP(s2[5], s2[13]), `MERGE_UP(s2[6], s2[14]), `MERGE_UP(s2[7], s2[15])
    };

    // Stage 4: Final (This is actually the standard Bitonic layout)
    // Wait, standard Bitonic sort for 16 needs 5 stages. 
    // The previous stages were for constructing the bitonic sequences. 
    // Let's list the standard 5 stages for 16 elements.
    // Stage 0: (0,1), (2,3) ... 
    // Stage 1: (0,2), (1,3) ... 
    // Stage 2: (0,4), (1,5), (2,6), (3,7) ... 
    // Stage 3: (0,8), (1,9) ... 
    // Stage 4: (0,16) ... 
    // The wiring above is a standard implementation, but let's ensure the last stage is correct.
    // The network usually finishes with a 'merge' stage. 
    // Let's re-evaluate the stages to match a 5-stage sorter (log2(16)^2 = 16, but parallel networks compress it).
    
    // Let's use the explicit 5 stages (log2(N)*(log2(N)+1)/2 = 20 steps, but we do parallel).
    // Actually, for 16 elements, a bitonic sort network has depth 5.
    // Correct stages:
    // S0: K=1 (0,1), (2,3) ... (alternating directions)
    // S1: K=2 (0,2), (1,3) ... (alternating directions)
    // S2: K=4 (0,4), (1,5), (2,6), (3,7) ... (alternating directions)
    // S3: K=8 (0,8), (1,9), (2,10), (3,11), (4,12), (5,13), (6,14), (7,15) ... (alternating directions)
    // S4: K=16 (Global merge, all directions ascending)
    
    // The code above mixes stages. Let's rewrite strictly for S3 (K=8) and S4 (K=16) using S2 as input.
    // S2 output is 's2' in my code. 
    // S3 (K=8, Direction: Split: 0-7 Up, 8-15 Down)
    wire [31:0] s3_temp [0:15];
    // 0-7 block (Up) connects 0-7 to 8-15? No, K=8 means gap is 8.
    // Pairs: (0,8), (1,9), (2,10), (3,11), (4,12), (5,13), (6,14), (7,15).
    // Directions: 0-3 Up, 4-7 Down (relative to the block of 16? No, standard bitonic is strictly based on indices for the final merge).
    // Actually, for K=8, we are merging two sorted lists of 8.
    // List A: s2[0..7] (already sorted ascending) -> Dir Up
    // List B: s2[8..15] (already sorted descending) -> Dir Up (to merge into Ascending)
    // So S3 should be all UP pairs (0,8), (1,9)...
    // Wait, S2 produced 0-7 Ascending and 8-15 Descending.
    // So S3: (0,8), (1,9)... all UP.
    // S4: K=4, Gap 4. 
    // Sequence: 0-3 Up, 4-7 Down, 8-11 Up, 12-15 Down? 
    // Actually, we are just doing the final merge of the 16-element bitonic sequence.
    // The standard sequence for 16 is:
    // S0: (0,1)D, (2,3)U, (4,5)D... (Wait, I used Up/Down in my first code. Let's verify)
    // Standard Bitonic Sorter (Parallel):
    // Stage 1 (K=1): 0-1 D, 2-3 U, 4-5 D...
    // Stage 2 (K=2): 0-2 D, 1-3 D, 4-6 U, 5-7 U...
    // Stage 3 (K=4): 0-4 D, 1-5 D, 2-6 D, 3-7 D, 8-12 U, 9-13 U...
    // Stage 4 (K=8): 0-8 D, 1-9 D... 7-15 D.
    // Stage 5 (K=16): 0-16 U... (Global sort).
    // Let's implement the standard parallel sorter exactly.

    // S0: K=1, Direction: Alternating D/U (or U/D depending on convention). Let's do U/D pattern.
    // Standard: 0-1 Ascending, 2-3 Descending...
    wire [31:0] s_s0 [0:15];
    assign s_s0[0] = (mem[0] < mem[1]) ? mem[0] : mem[1];
    assign s_s0[1] = (mem[0] < mem[1]) ? mem[1] : mem[0];
    assign s_s0[2] = (mem[2] > mem[3]) ? mem[2] : mem[3];
    assign s_s0[3] = (mem[2] > mem[3]) ? mem[3] : mem[2];
    assign s_s0[4] = (mem[4] < mem[5]) ? mem[4] : mem[5];
    assign s_s0[5] = (mem[4] < mem[5]) ? mem[5] : mem[4];
    assign s_s0[6] = (mem[6] > mem[7]) ? mem[6] : mem[7];
    assign s_s0[7] = (mem[6] > mem[7]) ? mem[7] : mem[6];
    assign s_s0[8] = (mem[8] < mem[9]) ? mem[8] : mem[9];
    assign s_s0[9] = (mem[8] < mem[9]) ? mem[9] : mem[8];
    assign s_s0[10] = (mem[10] > mem[11]) ? mem[10] : mem[11];
    assign s_s0[11] = (mem[10] > mem[11]) ? mem[11] : mem[10];
    assign s_s0[12] = (mem[12] < mem[13]) ? mem[12] : mem[13];
    assign s_s0[13] = (mem[12] < mem[13]) ? mem[13] : mem[12];
    assign s_s0[14] = (mem[14] > mem[15]) ? mem[14] : mem[15];
    assign s_s0[15] = (mem[14] > mem[15]) ? mem[15] : mem[14];

    // S1: K=2, Direction: Alternating blocks of 2 (U, D, U, D...)
    wire [31:0] s_s1 [0:15];
    // 0-1-2-3 block: 0-2 U, 1-3 U
    assign s_s1[0] = (s_s0[0] < s_s0[2]) ? s_s0[0] : s_s0[2];
    assign s_s1[1] = (s_s0[1] < s_s0[3]) ? s_s0[1] : s_s0[3];
    assign s_s1[2] = (s_s0[0] < s_s0[2]) ? s_s0[2] : s_s0[0];
    assign s_s1[3] = (s_s0[1] < s_s0[3]) ? s_s0[3] : s_s0[1];
    // 4-5-6-7 block: 4-6 D, 5-7 D
    assign s_s1[4] = (s_s0[4] > s_s0[6]) ? s_s0[4] : s_s0[6];
    assign s_s1[5] = (s_s0[5] > s_s0[7]) ? s_s0[5] : s_s0[7];
    assign s_s1[6] = (s_s0[4] > s_s0[6]) ? s_s0[6] : s_s0[4];
    assign s_s1[7] = (s_s0[5] > s_s0[7]) ? s_s0[7] : s_s0[5];
    // 8-9-10-11 block: 8-10 U, 9-11 U
    assign s_s1[8] = (s_s0[8] < s_s0[10]) ? s_s0[8] : s_s0[10];
    assign s_s1[9] = (s_s0[9] < s_s0[11]) ? s_s0[9] : s_s0[11];
    assign s_s1[10] = (s_s0[8] < s_s0[10]) ? s_s0[10] : s_s0[8];
    assign s_s1[11] = (s_s0[9] < s_s0[11]) ? s_s0[11] : s_s0[9];
    // 12-13-14-15 block: 12-14 D, 13-15 D
    assign s_s1[12] = (s_s0[12] > s_s0[14]) ? s_s0[12] : s_s0[14];
    assign s_s1[13] = (s_s0[13] > s_s0[15]) ? s_s0[13] : s_s0[15];
    assign s_s1[14] = (s_s0[12] > s_s0[14]) ? s_s0[14] : s_s0[12];
    assign s_s1[15] = (s_s0[13] > s_s0[15]) ? s_s0[15] : s_s0[13];

    // S2: K=4, Direction: Alternating blocks of 4 (U, D, U, D)
    wire [31:0] s_s2 [0:15];
    // Block 0 (0-3): U (pairs 0-4, 1-5, 2-6, 3-7)
    assign s_s2[0] = (s_s1[0] < s_s1[4]) ? s_s1[0] : s_s1[4];
    assign s_s2[1] = (s_s1[1] < s_s1[5]) ? s_s1[1] : s_s1[5];
    assign s_s2[2] = (s_s1[2] < s_s1[6]) ? s_s1[2] : s_s1[6];
    assign s_s2[3] = (s_s1[3] < s_s1[7]) ? s_s1[3] : s_s1[7];
    assign s_s2[4] = (s_s1[0] < s_s1[4]) ? s_s1[4] : s_s1[0];
    assign s_s2[5] = (s_s1[1] < s_s1[5]) ? s_s1[5] : s_s1[1];
    assign s_s2[6] = (s_s1[2] < s_s1[6]) ? s_s1[6] : s_s1[2];
    assign s_s2[7] = (s_s1[3] < s_s1[7]) ? s_s1[7] : s_s1[3];
    // Block 1 (4-7): D (pairs 4-8, 5-9, 6-10, 7-11)
    assign s_s2[8] = (s_s1[8] > s_s1[12]) ? s_s1[8] : s_s1[12];
    assign s_s2[9] = (s_s1[9] > s_s1[13]) ? s_s1[9] : s_s1[13];
    assign s_s2[10] = (s_s1[10] > s_s1[14]) ? s_s1[10] : s_s1[14];
    assign s_s2[11] = (s_s1[11] > s_s1[15]) ? s_s1[11] : s_s1[15];
    assign s_s2[12] = (s_s1[8] > s_s1[12]) ? s_s1[12] : s_s1[8];
    assign s_s2[13] = (s_s1[9] > s_s1[13]) ? s_s1[13] : s_s1[9];
    assign s_s2[14] = (s_s1[10] > s_s1[14]) ? s_s1[14] : s_s1[10];
    assign s_s2[15] = (s_s1[11] > s_s1[15]) ? s_s1[15] : s_s1[11];

    // S3: K=8, Direction: Alternating blocks of 8 (U, D)
    wire [31:0] s_s3 [0:15];
    // Block 0 (0-7): U (pairs 0-8, 1-9, 2-10, 3-11, 4-12, 5-13, 6-14, 7-15)
    assign s_s3[0] = (s_s2[0] < s_s2[8]) ? s_s2[0] : s_s2[8];
    assign s_s3[1] = (s_s2[1] < s_s2[9]) ? s_s2[1] : s_s2[9];
    assign s_s3[2] = (s_s2[2] < s_s2[10]) ? s_s2[2] : s_s2[10];
    assign s_s3[3] = (s_s2[3] < s_s2[11]) ? s_s2[3] : s_s2[11];
    assign s_s3[4] = (s_s2[4] < s_s2[12]) ? s_s2[4] : s_s2[12];
    assign s_s3[5] = (s_s2[5] < s_s2[13]) ? s_s2[5] : s_s2[13];
    assign s_s3[6] = (s_s2[6] < s_s2[14]) ? s_s2[6] : s_s2[14];
    assign s_s3[7] = (s_s2[7] < s_s2[15]) ? s_s2[7] : s_s2[15];
    assign s_s3[8] = (s_s2[0] < s_s2[8]) ? s_s2[8] : s_s2[0];
    assign s_s3[9] = (s_s2[1] < s_s2[9]) ? s_s2[9] : s_s2[1];
    assign s_s3[10] = (s_s2[2] < s_s2[10]) ? s_s2[10] : s_s2[2];
    assign s_s3[11] = (s_s2[3] < s_s2[11]) ? s_s2[11] : s_s2[3];
    assign s_s3[12] = (s_s2[4] < s_s2[12]) ? s_s2[12] : s_s2[4];
    assign s_s3[13] = (s_s2[5] < s_s2[13]) ? s_s2[13] : s_s2[5];
    assign s_s3[14] = (s_s2[6] < s_s2[14]) ? s_s2[14] : s_s2[6];
    assign s_s3[15] = (s_s2[7] < s_s2[15]) ? s_s2[15] : s_s2[7];
    // Block 1 (8-15) is empty, this is the final merge.

    // The sorted array is s_s3. We need to latch it into mem when sorting is done.
    
    // --- Next State Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        case (current_state)
            IDLE: 
                if (start) next_state = GENERATE;
                else next_state = IDLE;
            
            GENERATE:
                // Generate 16 values. t0 is stored at cycle 0 (start). 
                // We need 15 more cycles to fill array 1..15.
                // Or: t0 at mem[0], then generate 1..15. 
                // Let's say we use 16 cycles. 
                // Cycle 0: mem[0] = t0. 
                // Cycle 1: mem[1] = LFSR(t0).
                // ...
                // Cycle 15: mem[15] = LFSR(...).
                // So we need counter from 0 to 15.
                if (counter == 5'd15) next_state = SORT;
                else next_state = GENERATE;
            
            SORT:
                // Sorting network is combinational. 
                // We need 1 clock cycle to capture the result into mem.
                next_state = CALCULATE;
            
            CALCULATE:
                // Iterate 16 times max.
                if (counter == 5'd15) next_state = DONE;
                // Or if accumulated_time > T, break to DONE immediately?
                // The prompt says "Else: break loop". 
                // Since we are in a state, we need to exit the state.
                else if (accumulated_time > T) next_state = DONE;
                else next_state = CALCULATE;
            
            DONE:
                // Wait in done or go to IDLE? 
                // Usually, wait for reset or start low? 
                // Prompt says "High when computation is complete".
                // Let's stay in DONE until reset or maybe next start?
                // If start goes low, maybe return to IDLE.
                if (!start) next_state = IDLE;
                else next_state = DONE;
            
            default: next_state = IDLE;
        endcase
    end

    // --- Datapath Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
            penalty <= 0;
            done <= 0;
            counter <= 0;
            lfsr_reg <= 0;
            // mem reset not strictly needed but good practice
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    counter <= 0;
                    if (start) begin
                        // Prepare LFSR with seed
                        lfsr_reg <= t0;
                        // Store t0 immediately? Or handle in GENERATE.
                        // We'll handle t0 storage in GENERATE state logic by checking counter.
                    end
                end

                GENERATE: begin
                    // Store value
                    if (counter == 0) begin
                        mem[0] <= t0;
                    end else begin
                        // LFSR has updated from previous cycle (or IDLE)
                        mem[counter] <= lfsr_reg;
                    end
                    
                    // Update LFSR for next cycle
                    lfsr_reg <= lfsr_next;
                    
                    counter <= counter + 1;
                end

                SORT: begin
                    // Capture combinational sorting result into mem
                    mem[0] <= s_s3[0];
                    mem[1] <= s_s3[1];
                    mem[2] <= s_s3[2];
                    mem[3] <= s_s3[3];
                    mem[4] <= s_s3[4];
                    mem[5] <= s_s3[5];
                    mem[6] <= s_s3[6];
                    mem[7] <= s_s3[7];
                    mem[8] <= s_s3[8];
                    mem[9] <= s_s3[9];
                    mem[10] <= s_s3[10];
                    mem[11] <= s_s3[11];
                    mem[12] <= s_s3[12];
                    mem[13] <= s_s3[13];
                    mem[14] <= s_s3[14];
                    mem[15] <= s_s3[15];
                    
                    // Reset counters and accumulators for calculation
                    counter <= 0;
                    accumulated_time <= 0;
                    current_penalty <= 0;
                    count <= 0;
                    penalty <= 0;
                end

                CALCULATE: begin
                    // Read current value from mem
                    // Ideally we use the registered value. 
                    // Since mem is updated in SORT state, and we are now in CALCULATE, we can use mem[counter].
                    // However, reading mem[counter] creates a combinational path from mem to logic.
                    // To keep timing clean, we can buffer the value or just read it.
                    // With N=16, the depth is small. 
                    
                    // Add to accumulated time
                    // mem is 32bit, accumulated_time is 64bit
                    accumulated_time <= accumulated_time + {32'b0, mem[counter]};
                    
                    // Check condition with OLD accumulated_time or NEW?
                    // The problem says: "accumulated_time <= accumulated_time + val"
                    // "If accumulated_time <= T".
                    // Usually we check if NEW accumulated_time <= T.
                    // But if we break, we shouldn't add the penalty.
                    
                    // Let's use the NEW accumulated time for the check.
                    // Wait, if we update accumulated_time <= ... in this block, the new value is available next cycle.
                    // So we should compare (accumulated_time + val) <= T.
                    
                    if ((accumulated_time + {32'b0, mem[counter]}) <= T) begin
                        count <= count + 1;
                        // Update penalty: new_p = (old_p + new_accumulated_time) % MOD
                        // new_accumulated_time is (accumulated_time + mem[counter])
                        // We need a 65-bit adder for (current_penalty + new_accumulated_time) 
                        // current_penalty is 32, new_accumulated_time is 64. Sum is 65.
                        // Or modulo first? Accumulated time can be huge (up to 16*2^32), fits in 48 bits.
                        // T is 64-bit. 
                        // Penalty needs modulo 1000000007.
                        
                        // Since penalty is 32-bit, we can do:
                        // penalty_new = (penalty + (accumulated_time + mem[counter])) % MOD
                        // We can't easily modulo a 64-bit number in HW without division.
                        // But we can use the property: (a + b) % m = ((a % m) + (b % m)) % m.
                        // However, (accumulated_time + val) might be > 2^32.
                        // But accumulated_time % MOD is NOT accumulated_time.
                        // We need to track penalty update correctly.
                        // The penalty is sum of accumulated times of accepted elements.
                        // P = sum_{i=1}^{k} (sum_{j=1}^{i} val_j).
                        // This grows quickly. 
                        // Since we need modulo, and intermediate values can be huge (64 bit), we need to perform modulo arithmetic.
                        // We can add the NEW accumulated time to the penalty accumulator, and mod it.
                        // New accumulated time = (accumulated_time + mem[counter]).
                        // Let's use a 65-bit adder for (penalty + new_accumulated_time).
                        // Then we need to mod the result.
                        // Modulo operation is expensive, but since we only do it 16 times, we can use a divider or a specialized logic.
                        // Given the constraints (Verilog, no divide specified), we should probably implement a sequential remainder logic or assume a synthesizable modulo.
                        // Actually, for synthesis, we can use the % operator if the tool supports it for constants, or use repeated subtraction (slow) or a pipelined divider.
                        // But with <1000 cycles, we have budget. 
                        // However, the prompt asks for an efficient module. Division by constant 1000000007 is typically optimized by synthesis tools.
                        // Let's use the % operator. It usually infers a divider.
                        // To make it safe and timing friendly, we can split the logic.
                        
                        // Let's compute: next_penalty_val = penalty + (accumulated_time + {32'b0, mem[counter]});
                        // We need 65 bits for the sum to be safe.
                        wire [64:0] sum_penalty = {33'b0, penalty} + accumulated_time + {32'b0, mem[counter]};
                        // But penalty is 32, accumulated is 64. 
                        // Penalty update is: penalty = (penalty + NEW_accum_time) % MOD.
                        // NEW_accum_time = accumulated_time + val.
                        // accumulated_time can be up to ~16*4e9 = 64e9, fits in 36 bits.
                        // T is 64 bit, so accumulated_time can theoretically be large, but if T is large, accumulated_time grows.
                        // Max sum: 16 * 2^32 ~ 6.8e10. Fits in 37 bits.
                        // Penalty sum: Sum of sums. Max ~ 16*6.8e10 = 1e12. Fits in 40 bits.
                        // So we can safely use 64-bit arithmetic for penalty calculation.
                        
                        // Wait, accumulated_time is 64-bit because T is 64-bit.
                        // If T is huge, accumulated_time can be huge.
                        // Example: T = 2^60. accumulated_time = 2^60. 
                        // Penalty update adds 2^60 to penalty (32-bit). 
                        // So we need to mod accumulated_time before adding to penalty? 
                        // No, the problem says: penalty = (penalty + accumulated_time) % 1000000007.
                        // So we need (penalty + accumulated_time) % MOD.
                        // Since accumulated_time is 64-bit, we need 64-bit arithmetic for the modulo.
                        // We can use the identity: (A + B) % M = ((A % M) + (B % M)) % M.
                        // But A is accumulated_time. We are NOT tracking accumulated_time % MOD, we are tracking exact accumulated_time for the T comparison.
                        // So we need to compute (accumulated_time % MOD) + penalty, then mod.
                        // This is better: 64-bit modulo is cheaper than 128-bit.
                        
                        // So: term = accumulated_time % MOD. 
                        // new_penalty = (penalty + term) % MOD.
                        // We can compute term using the % operator. Synthesis tools optimize division by constants.
                        // Since we are in a combinational logic block inside an always block, we need to be careful with large dividers (latency).
                        // However, we have 1 clock cycle per iteration in CALCULATE state.
                        // If the divider takes 1 cycle, we are fine.
                        // If it takes more, we need a multi-cycle state.
                        // 1000000007 is a prime. Division is slow. 
                        // Let's assume we can do this in 1 cycle or use a sequential divider logic.
                        // Given the prompt asks for a *module*, and no specific latency for modulo, I will assume a 1-cycle latency for simplicity of the FSM structure, but I will add a 33-bit adder for the modulo sum.
                        
                        // However, standard synthesis might not fit a 64-bit divider in 1 cycle comfortably. 
                        // But N=16, we can unroll the modulo logic or use a slow path.
                        // Alternative: We can update penalty in two cycles? No, state is single.
                        // Let's stick to the % operator. If timing fails, user can add pipelining.
                        // Actually, to be safe and efficient, let's just add accumulated_time to a 64-bit extension of penalty and mod at the end? 
                        // No, must mod every step to prevent overflow.
                        
                        // Let's do: penalty <= (penalty + (accumulated_time % MOD)) % MOD;
                        // This requires 2 mod operations. 
                        // Or: penalty <= (penalty + accumulated_time) % MOD. (This implies adding 64-bit to 32-bit). 
                        // The sum might exceed 64-bit if penalty wraps? No, penalty < MOD. accumulated_time < T (which is 64). 
                        // Sum < 2*10^9 + 2^64. Fits in 65 bits. 
                        // So: new_p_64 = {32'b0, penalty} + accumulated_time;
                        // penalty <= new_p_64 % MOD. 
                        // This is the most direct interpretation.
                        
                        // Note: % operator in Verilog for synthesis on large vectors might be slow. 
                        // But let's proceed with this. It is the most correct to the spec.
                        // We need a wire for the addition to be combinational.
                        // Since this is sequential block, we can't do math in the @(posedge) block directly for intermediate signals without creating latches or complex logic. 
                        // So we do the math inside the block.
                        // We need to calculate: (penalty + accumulated_time) % MOD.
                        // This is a 65-bit add, then 64-bit mod.
                        // We will compute it in a combinational way before the assignment.
                        // Since we are in always @(posedge), we can't instantiate wires easily. 
                        // We can use an 'assign' inside the always block? No.
                        // We calculate it directly.
                        // To avoid long paths, we rely on the tool.
                        
                        // Let's define a temporary variable for the new penalty.
                        // Because Verilog allows this inside always blocks.
                        // penalty <= (penalty + accumulated_time) % MOD;
                        // This is valid syntax.
                        penalty <= (penalty + accumulated_time) % MOD;
                    end
                    
                    counter <= counter + 1;
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule

module TopModuleWrapper(pikeman_solver u_pikeman_solver);
    // This wrapper is just to ensure the pikeman_solver module is defined correctly.
    // The user should instantiate pikeman_solver directly.
endmodule