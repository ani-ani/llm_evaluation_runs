module top_items_finder (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0][63:0] items,
    output reg [2:0] done_items,
    output reg [7:0][63:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam SORT = 3'b010;
    localparam OUTPUT = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    reg [2:0] sort_counter, next_sort_counter;
    
    // Sorting network internal state
    // 8 items of 64 bits each
    reg [63:0] s0 [0:7];
    reg [63:0] s1 [0:7];
    reg [63:0] s2 [0:7];
    reg [63:0] s3 [0:7];
    reg [63:0] s4 [0:7];
    reg [63:0] s5 [0:7]; // Final sorted items
    
    // Helper wires for comparators
    wire [63:0] swap_high [0:7];
    wire [63:0] swap_low [0:7];
    wire [63:0] noswap_high [0:7];
    wire [63:0] noswap_low [0:7];
    
    // Comparator logic - compare prices [31:0]
    // A[31:0] is price, B[63:32] is name_id (irrelevant for sort)
    // Wait, spec says: [31:0] name_id, [63:32] price. 
    // So price is upper 32 bits (bits 63:32).
    
    // Stage 0: 4 pairs of 2 (2-cycles latency logic unrolled)
    // Wait, spec says "unroll fully".
    // Bitonic Sort 8 items (Batcher's odd-even merge sort or similar)
    // Standard 8-item bitonic sort network depth is log2(8)^2 = 9 comparisons or similar.
    // Spec says 6 cycles. A Bose-Nelson sort for 8 items can be done in 6 stages of comparators.
    
    // Let's trace the Bose-Nelson network for 8 items:
    // Stage 1: (0,1), (2,3), (4,5), (6,7)
    // Stage 2: (0,2), (1,3), (4,6), (5,7)
    // Stage 3: (1,2), (5,6), (0,4), (3,7)
    // Stage 4: (1,5), (2,6), (0,4) -> wait, 0,4 is already done. 
    // Let's use a verified 6-stage network for 8 items.
    // Stage 1: (0,1)(2,3)(4,5)(6,7)
    // Stage 2: (0,2)(1,3)(4,6)(5,7)
    // Stage 3: (1,2)(5,6)(0,4)(3,7)
    // Stage 4: (1,5)(2,6)(3,5)(4,6) -> Actually let's stick to a simpler plan.
    
    // We will implement the 6 cycle unrolled logic in combinational blocks for each stage.
    // We need 6 sequential stages to match the latency requirement (plus load/output).
    
    // Comparison helper: returns High if A > B (descending price)
    // Price is bits [63:32] (Q16.16)
    function automatic [63:0] cmp_swap(input [63:0] a, input [63:0] b);
        // Compare upper 32 bits (price)
        if (a[63:32] > b[63:32]) begin
            cmp_swap = a;
        end else begin
            cmp_swap = b;
        end
    endfunction
    
    function automatic [63:0] cmp_min(input [63:0] a, input [63:0] b);
        if (a[63:32] > b[63:32]) begin
            cmp_min = b;
        end else begin
            cmp_min = a;
        end
    endfunction

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sort_counter <= 0;
            // Reset registers
            s0 <= '{default:0}; s1 <= '{default:0}; s2 <= '{default:0};
            s3 <= '{default:0}; s4 <= '{default:0}; s5 <= '{default:0};
            done <= 0;
            done_items <= 0;
            result <= '{default:0};
        end else begin
            state <= next_state;
            sort_counter <= next_sort_counter;
            
            // Combinational updates for sorting registers based on state
            // We use combinational logic feeding D-regs to pipeline the sorting network
            // LOAD state
            if (state == IDLE && start) begin
                s0 <= items; // Capture inputs
            end
            
            // SORT stages (cycles 2 through 7)
            // We effectively pipeline the comparators: s0 -> s1 -> s2 -> s3 -> s4 -> s5
            // To fit 6 cycles of sorting (plus load and output), we have 6 pipeline stages.
            // We will map the network operations to these registers.
            
            // Cycle 1 (SORT state entry after LOAD): 
            // Network Stage 1 comparisons
            if (state == SORT) begin
                case (sort_counter) // sort_counter starts at 0 or 1 depending on trigger logic
                    // We will run 6 iterations of the main loop
                    // Actually, let's map the 6 specific stages of a Bose-Nelson network
                    // S1: (0,1), (2,3), (4,5), (6,7)
                    0: begin
                        s1[0] <= cmp_swap(s0[0], s0[1]); s1[1] <= cmp_min(s0[0], s0[1]);
                        s1[2] <= cmp_swap(s0[2], s0[3]); s1[3] <= cmp_min(s0[2], s0[3]);
                        s1[4] <= cmp_swap(s0[4], s0[5]); s1[5] <= cmp_min(s0[4], s0[5]);
                        s1[6] <= cmp_swap(s0[6], s0[7]); s1[7] <= cmp_min(s0[6], s0[7]);
                    end
                    // S2: (0,2), (1,3), (4,6), (5,7)
                    1: begin
                        s2[0] <= cmp_swap(s1[0], s1[2]); s2[2] <= cmp_min(s1[0], s1[2]);
                        s2[1] <= cmp_swap(s1[1], s1[3]); s2[3] <= cmp_min(s1[1], s1[3]);
                        s2[4] <= cmp_swap(s1[4], s1[6]); s2[6] <= cmp_min(s1[4], s1[6]);
                        s2[5] <= cmp_swap(s1[5], s1[7]); s2[7] <= cmp_min(s1[5], s1[7]);
                        // s2[2] and others need to propagate from previous cycle if not swapped? 
                        // In a pipeline, we need to route the "other" value correctly.
                        // Wait, the above is incomplete. cmp_min returns the smaller one, which goes to the index of the larger one? No.
                        // For indices (i, j) where i < j, we want: 
                        // High(i) = max(A_i, A_j)
                        // Low(j) = min(A_i, A_j)
                        // But what about High(j) and Low(i)? 
                        // The standard 2-sorter block is:
                        // High = max(A, B)
                        // Low = min(A, B)
                        // But in a network, we assign High to one position and Low to another.
                        // In S1(0,1): 0 gets max, 1 gets min.
                        // In S2(0,2): 0 gets max(s0[0], s0[2]) -> but s0[0] is already swapped in S1? 
                        // NO. The network is not pipelined by "re-using registers".
                        // It is a sequence of comparison operations.
                        // To pipeline it physically, we must register outputs of each stage.
                        // Let's denote A_n as the array after n stages.
                        // Stage 1:
                        // A1[0] = max(A0[0], A0[1])
                        // A1[1] = min(A0[0], A0[1])
                        // A1[2] = max(A0[2], A0[3])
                        // A1[3] = min(A0[2], A0[3])
                        // ...
                        // Stage 2:
                        // A2[0] = max(A1[0], A1[2])
                        // A2[2] = min(A1[0], A1[2])
                        // A2[1] = max(A1[1], A1[3])
                        // A2[3] = min(A1[1], A1[3])
                        // ...
                        
                        // Since we are writing code for a "sequential module" using registers (FSM), 
                        // we can either unroll completely into comb logic (1 cycle) or pipeline it.
                        // Spec says "6 cycles for 8-item bitonic sort".
                        // So we need 6 clock cycles of SORT state.
                        // Let's use 6 sets of registers (or one set updated 6 times).
                        // Let's use 6 sequential blocks inside the FSM logic, or better, use combinational next values for the registers.
                        
                        // Re-implementing the logic for updates based on 'sort_counter' (0 to 5)
                        
                        if (sort_counter == 0) begin
                             s1[0] <= (items[0][63:32] > items[1][63:32]) ? items[0] : items[1];
                             s1[1] <= (items[0][63:32] > items[1][63:32]) ? items[1] : items[0];
                             s1[2] <= (items[2][63:32] > items[3][63:32]) ? items[2] : items[3];
                             s1[3] <= (items[2][63:32] > items[3][63:32]) ? items[3] : items[2];
                             s1[4] <= (items[4][63:32] > items[5][63:32]) ? items[4] : items[5];
                             s1[5] <= (items[4][63:32] > items[5][63:32]) ? items[5] : items[4];
                             s1[6] <= (items[6][63:32] > items[7][63:32]) ? items[6] : items[7];
                             s1[7] <= (items[6][63:32] > items[7][63:32]) ? items[7] : items[6];
                        end else if (sort_counter == 1) begin
                             // Using s1 as inputs for stage 2\_
                             s2[0] <= (s1[0][63:32] > s1[2][63:32]) ? s1[0] : s1[2];
                             s2[2] <= (s1[0][63:32] > s1[2][63:32]) ? s1[2] : s1[0];
                             s2[1] <= (s1[1][63:32] > s1[3][63:32]) ? s1[1] : s1[3];
                             s2[3] <= (s1[1][63:32] > s1[3][63:32]) ? s1[3] : s1[1];
                             s2[4] <= (s1[4][63:32] > s1[6][63:32]) ? s1[4] : s1[6];
                             s2[6] <= (s1[4][63:32] > s1[6][63:32]) ? s1[6] : s1[4];
                             s2[5] <= (s1[5][63:32] > s1[7][63:32]) ? s1[5] : s1[7];
                             s2[7] <= (s1[5][63:32] > s1[7][63:32]) ? s1[7] : s1[5];
                        end else if (sort_counter == 2) begin
                             // Stage 3: (1,2), (5,6), (0,4), (3,7)
                             s3[1] <= (s2[1][63:32] > s2[2][63:32]) ? s2[1] : s2[2];
                             s3[2] <= (s2[1][63:32] > s2[2][63:32]) ? s2[2] : s2[1];
                             s3[5] <= (s2[5][63:32] > s2[6][63:32]) ? s2[5] : s2[6];
                             s3[6] <= (s2[5][63:32] > s2[6][63:32]) ? s2[6] : s2[5];
                             s3[0] <= (s2[0][63:32] > s2[4][63:32]) ? s2[0] : s2[4];
                             s3[4] <= (s2[0][63:32] > s2[4][63:32]) ? s2[4] : s2[0];
                             s3[3] <= (s2[3][63:32] > s2[7][63:32]) ? s2[3] : s2[7];
                             s3[7] <= (s2[3][63:32] > s2[7][63:32]) ? s2[7] : s2[3];
                             // We need to pass through the other indices (0,3,4,7 were involved in other pairs?)
                             // Wait, indices 0,4,3,7 are handled. Indices 1,2,5,6 are handled.
                             // But what about s3[0]? s3[0] gets max(0,4). s3[4] gets min(0,4).
                        end else if (sort_counter == 3) begin
                             // Stage 4: (1,5), (2,6), (0,1), (4,5), (2,3), (6,7) ... 
                             // Let's map a standard 6-stage Bose-Nelson more carefully.
                             // S1: (0,1)(2,3)(4,5)(6,7)
                             // S2: (0,2)(1,3)(4,6)(5,7)
                             // S3: (1,2)(5,6)
                             // S4: (0,4)(1,5)(2,6)(3,7)
                             // S5: (1,4)(3,6)
                             // S6: (2,4)(3,5)
                             
                             // Recalculating based on strict Bose-Nelson pipeline:
                             // We need 6 registers: R0..R5.
                             // R0: Input
case (sort_counter)
0: begin // Stage 1
    s1[0] <= (items[0][63:32] > items[1][63:32]) ? items[0] : items[1]; s1[1] <= (items[0][63:32] > items[1][63:32]) ? items[1] : items[0];
    s1[2] <= (items[2][63:32] > items[3][63:32]) ? items[2] : items[3]; s1[3] <= (items[2][63:32] > items[3][63:32]) ? items[3] : items[2];
    s1[4] <= (items[4][63:32] > items[5][63:32]) ? items[4] : items[5]; s1[5] <= (items[4][63:32] > items[5][63:32]) ? items[5] : items[4];
    s1[6] <= (items[6][63:32] > items[7][63:32]) ? items[6] : items[7]; s1[7] <= (items[6][63:32] > items[7][63:32]) ? items[7] : items[6];
end
1: begin // Stage 2: (0,2)(1,3)(4,6)(5,7)
    s2[0] <= (s1[0][63:32] > s1[2][63:32]) ? s1[0] : s1[2]; s2[2] <= (s1[0][63:32] > s1[2][63:32]) ? s1[2] : s1[0];
    s2[1] <= (s1[1][63:32] > s1[3][63:32]) ? s1[1] : s1[3]; s2[3] <= (s1[1][63:32] > s1[3][63:32]) ? s1[3] : s1[1];
    s2[4] <= (s1[4][63:32] > s1[6][63:32]) ? s1[4] : s1[6]; s2[6] <= (s1[4][63:32] > s1[6][63:32]) ? s1[6] : s1[4];
    s2[5] <= (s1[5][63:32] > s1[7][63:32]) ? s1[5] : s1[7]; s2[7] <= (s1[5][63:32] > s1[7][63:32]) ? s1[7] : s1[5];
end
2: begin // Stage 3: (1,2)(5,6)
    s3[1] <= (s2[1][63:32] > s2[2][63:32]) ? s2[1] : s2[2]; s3[2] <= (s2[1][63:32] > s2[2][63:32]) ? s2[2] : s2[1];
    s3[5] <= (s2[5][63:32] > s2[6][63:32]) ? s2[5] : s2[6]; s3[6] <= (s2[5][63:32] > s2[6][63:32]) ? s2[6] : s2[5];
    // Pass through others
    s3[0] <= s2[0]; s3[3] <= s2[3]; s3[4] <= s2[4]; s3[7] <= s2[7];
end
3: begin // Stage 4: (0,4)(1,5)(2,6)(3,7)
    s4[0] <= (s3[0][63:32] > s3[4][63:32]) ? s3[0] : s3[4]; s4[4] <= (s3[0][63:32] > s3[4][63:32]) ? s3[4] : s3[0];
    s4[1] <= (s3[1][63:32] > s3[5][63:32]) ? s3[1] : s3[5]; s4[5] <= (s3[1][63:32] > s3[5][63:32]) ? s3[5] : s3[1];
    s4[2] <= (s3[2][63:32] > s3[6][63:32]) ? s3[2] : s3[6]; s4[6] <= (s3[2][63:32] > s3[6][63:32]) ? s3[6] : s3[2];
    s4[3] <= (s3[3][63:32] > s3[7][63:32]) ? s3[3] : s3[7]; s4[7] <= (s3[3][63:32] > s3[7][63:32]) ? s3[7] : s3[3];
end
4: begin // Stage 5: (1,4)(3,6)
    s5[1] <= (s4[1][63:32] > s4[4][63:32]) ? s4[1] : s4[4]; s5[4] <= (s4[1][63:32] > s4[4][63:32]) ? s4[4] : s4[1];
    s5[3] <= (s4[3][63:32] > s4[6][63:32]) ? s4[3] : s4[6]; s5[6] <= (s4[3][63:32] > s4[6][63:32]) ? s4[6] : s4[3];
    // Pass through others
    s5[0] <= s4[0]; s5[2] <= s4[2]; s5[5] <= s4[5]; s5[7] <= s4[7];
end
5: begin // Stage 6: (2,4)(3,5)
    // s5 currently has partials. We need to produce final sorted array in s5.
    // Let's overwrite s5. Wait, s5 is the final register. 
    // To avoid complex routing, let's just use one register array 'sorted_items' that we update.
    // Or just chain s5 -> s5_next.
    // Since we are inside the same block, we can update s5 directly if we use comb logic inside the if (state==LOAD)...
    // But we are in a clocked block.
    // Let's use a local wire for next_s5.
    // Inputs come from s5 (previous iteration) except for the first iteration.
    // Actually, s5 is the last register. Let's call it 's5_next' for this cycle.
    // Since we need s5 to hold the final result, we should use s4 to compute s5.
    // But s4 is only valid at cycle 4. 
    // We need to chain 6 stages. 
    // Cycle 0: Inputs -> S1
    // Cycle 1: S1 -> S2
    // Cycle 2: S2 -> S3
    // Cycle 3: S3 -> S4
    // Cycle 4: S4 -> S5
    // Cycle 5: S5 -> S5 (Final Stage 6)
    
    // So for cycle 5, we need to read from s5 (which contains output of stage 5).
    // But we just wrote to s5 in cycle 4. 
    // We need another register? 
    // Let's add one more register stage 's_result' for the final output.
    // Or we can overwrite s5 in the last step.
    
    // Cycle 4 wrote to s5 (stage 5 result). 
    // Cycle 5 computes stage 6 from s5 and writes to s5.
    // This works if we update s5 inside the case statement.
    
    // Stage 6: (2,4)(3,5)
    s5[2] <= (s5[2][63:32] > s5[4][63:32]) ? s5[2] : s5[4]; s5[4] <= (s5[2][63:32] > s5[4][63:32]) ? s5[4] : s5[2];
    s5[3] <= (s5[3][63:32] > s5[5][63:32]) ? s5[3] : s5[5]; s5[5] <= (s5[3][63:32] > s5[5][63:32]) ? s5[5] : s5[3];
    // Others stay same (0,1,6,7 don't move in final Bose-Nelson stage 6? 
    // Actually, (0,1), (4,5), (6,7) are implicit from previous stages.
    // Just updating 2,4 and 3,5 should finalize the sort if the network is correct.
    
    // Wait, we must handle the data path.
    // In cycle 0, we computed s1 from items.
    // In cycle 1, we computed s2 from s1.
    // In cycle 2, we computed s3 from s2.
    // In cycle 3, we computed s4 from s3.
    // In cycle 4, we computed s5 from s4.
    // In cycle 5, we update s5 from s5.
    // But what if we didn't compute s5 in cycle 4?
    // Let's trace back.
    // If sort_counter == 3 (cycle 4), we wrote to s4.
    // If sort_counter == 4 (cycle 5), we write to s5.
    // If sort_counter == 5 (cycle 6), we write to s5.
    // But we need 6 cycles of SORT. 
    // State Machine: IDLE -> LOAD -> SORT (counter 0 to 5) -> OUTPUT -> DONE.
    // Sort counter: 0, 1, 2, 3, 4, 5. (6 cycles).
    // Cycle 0 (counter 0): Op Stage 1. Result in S1.
    // Cycle 1 (counter 1): Op Stage 2. Result in S2.
    // Cycle 2 (counter 2): Op Stage 3. Result in S3.
    // Cycle 3 (counter 3): Op Stage 4. Result in S4.
    // Cycle 4 (counter 4): Op Stage 5. Result in S5.
    // Cycle 5 (counter 5): Op Stage 6. Result in S5.
    // But we need S5 to be available at OUTPUT.
    // S5 needs to be written in Cycle 4 and Cycle 5.
    // However, in Cycle 4, we write S5 based on S4.
    // In Cycle 5, we write S5 based on S5.
    // But in the code above, S5 is written in 'else if (sort_counter == 4)' (Cycle 4) and 'else if (sort_counter == 5)' (Cycle 5).
    // Wait, the 'sort_counter' updates at the end of the cycle.
    // If sort_counter == 0, we are in Cycle 1 (after IDLE/LOAD).
    // Logic: 
    // Cycle 1: state=LOAD, next_state=LOAD? No.
    // Let's assume LOAD is 1 cycle. 
    // Cycle 0: IDLE. 
    // Cycle 1: LOAD. s0 = items.
    // Cycle 2: SORT, counter 0. s1 computed.
    // Cycle 3: SORT, counter 1. s2 computed.
    // Cycle 4: SORT, counter 2. s3 computed.
    // Cycle 5: SORT, counter 3. s4 computed.
    // Cycle 6: SORT, counter 4. s5 computed.
    // Cycle 7: SORT, counter 5. s5 updated (stage 6).
    // Cycle 8: OUTPUT.
    // Latency 9. Correct.
    
    // Wait, in 'else if (sort_counter == 5)' block (Cycle 7), we read from s5. 
    // s5 was written in 'else if (sort_counter == 4)' (Cycle 6).
    // So s5 holds valid Stage 5 data in Cycle 7.
    // We perform Stage 6 swap and write to s5 in Cycle 7.
    // s5 is valid for OUTPUT in Cycle 8.
    
    // We need to handle the fact that s5 is also written in stage 4->5.
    // But in the code structure, 'else if (sort_counter == 4)' writes s5.
    // Then 'else if (sort_counter == 5)' reads s5 and writes s5.
    // However, in the if-else chain, only one block executes.
    // So we need to route the inputs correctly.
    // For counter 4, inputs are s4.
    // For counter 5, inputs are s5.
    // So we need a multiplexer or just duplicate logic.
    
    // Let's rewrite the sorting block carefully.
    // We will use 'current' and 'next' logic, or simply use the registered values directly in the case.
    // Note: In the non-default case, we must also pass through values that are NOT swapped in this cycle.
    // For example, in Stage 3: (1,2), (5,6). Indices 0,3,4,7 pass through.
    // If we are writing to s3[0], we must assign s2[0] to it.
    // The code above did this for Stage 3.
    
    // Let's refine the sort stages to ensure NO data is lost.
    
    // Stage 1: All pairs active. s1 updated fully.
    // Stage 2: All pairs active. s2 updated fully.
    // Stage 3: (1,2), (5,6) active. s3[1,2,5,6] swapped. s3[0,3,4,7] pass through.
    // Stage 4: (0,4), (1,5), (2,6), (3,7) active. s4 fully swapped.
    // Stage 5: (1,4), (3,6) active. s5[1,4,3,6] swapped. s5[0,2,5,7] pass through.
    // Stage 6: (2,4), (3,5) active. s5[2,4,3,5] swapped. s5[0,1,6,7] pass through.
    
    // Wait, in the code above, for Stage 5 (counter 4), I wrote to s5.
    // For Stage 6 (counter 5), I wrote to s5.
    // But Stage 5 output must be the input to Stage 6.
    // So in counter 4, we write to s5.
    // In counter 5, we read s5 (which holds Stage 5 result) and write to s5.
    // This is correct.
    
    // BUT, in counter 4, we MUST preserve the values that are not swapped.
    // My previous code for counter 4 only wrote the swapped pairs.
    // It did NOT write the preserved pairs.
    // For example, s5[0] <= s4[0] is missing.
    // I must add that.
    
    // Also, for counter 0 and 1, I wrote to s1 and s2 fully. That's fine.
    // For counter 2 (Stage 3), I wrote to s3. I handled pass-throughs. That's fine.
    // For counter 3 (Stage 4), I wrote to s4 fully. That's fine.
    // For counter 4 (Stage 5), I wrote to s5. I missed pass-throughs.
    // For counter 5 (Stage 6), I wrote to s5. I missed pass-throughs.
    
    // Let's fix the pass-throughs.
    end // end case item
    end // end if sort state
            end // always block
    
    // Combinational Next State Logic
    always @(*) begin
        next_state = state;
        next_sort_counter = sort_counter;
        
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                next_state = SORT;
                next_sort_counter = 0;
            end
            SORT: begin
                if (sort_counter < 5) begin
                    next_sort_counter = sort_counter + 1;
                end else begin
                    next_state = OUTPUT;
                end
            end
            OUTPUT: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE; // Wait for start to go low before accepting new start
                // Or just stay done until start pulse?
                // Usually done goes high for 1 cycle or until reset.
                // Let's stay in DONE until start goes low, then go to IDLE to wait for new pulse.
            end
            default: next_state = IDLE;
        endcase
    end

    // Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            done_items <= 0;
            result <= '{default:0};
        end else begin
            if (state == OUTPUT) begin
                // s5 holds the sorted array (Stage 6 result).
                // We need to take top n items.
                // n is input [2:0].
                // result is 8 items.
                // We can just output the first n items of s5, and fill the rest with zeros or don't care.
                // done_items = n.
                done_items <= n;
                done <= 1;
                
                // Output logic: 
                // n=1: result[0] = s5[0], rest 0
                // n=2: result[0] = s5[0], result[1] = s5[1], rest 0
                // n=3: result[0] = s5[0], result[1] = s5[1], result[2] = s5[2], rest 0
                // n=0? Specification says 1-3. 
                
                // We can use a loop or explicit ifs.
                // Since it's hardware, let's just mux s5 to result.
                // However, we need to register the result. 
                // The requirement says "Output sorted results" in OUTPUT state (1 cycle) and then DONE.
                // So we compute result in OUTPUT state.
                
                // Verilog doesn't like loops with variable bounds for synthesis easily unless unrolled.
                // We can unroll manually or use generate, but inside always block we can use if/else.
                
                // Mapping s5 to result based on n.
                // We need to populate result[0], result[1], ... result[7] based on n.
                // If n < 8, remaining outputs are undefined or 0. Let's zero them.
                
                result[0] <= (n >= 1) ? s5[0] : 64'b0;
                result[1] <= (n >= 2) ? s5[1] : 64'b0;
                result[2] <= (n >= 3) ? s5[2] : 64'b0;
                result[3] <= (n >= 4) ? s5[3] : 64'b0;
                result[4] <= (n >= 5) ? s5[4] : 64'b0;
                result[5] <= (n >= 6) ? s5[5] : 64'b0;
                result[6] <= (n >= 7) ? s5[6] : 64'b0;
                result[7] <= (n == 8) ? s5[7] : 64'b0; // n is 3 bits, max 7? 3 bits 0-7. Spec says 1-3.
                
                // Also zero out higher indices if n is small.
                // Actually, if n=2, we only write 0,1. 2-7 should be zero.
                // The 'else' part of the ternary handles it.
                
            end else if (state == DONE) begin
                done <= 0; // Pulse done for 1 cycle? Or keep high?
                // Spec: "done: high when computation complete". 
                // "OUTPUT: ... set done signal. DONE: Assert done signal."
                // Usually done is a pulse. I'll make it a pulse in OUTPUT state.
                // If it should stay high until reset, I should keep it high in DONE.
                // Let's keep it high in DONE, and clear it when we go back to IDLE (start goes low).
                // Actually, standard convention: done asserts when valid, clears on next start or idle.
                // Let's clear done when we leave DONE or go to IDLE.
                // If state == DONE, done remains 1.
                // But to prevent it staying high forever, we should clear it when start goes low.
                // My next_state logic goes to IDLE when !start.
                // So in IDLE, we should clear done.
                // 
                // Wait, in next_state logic: if state==DONE && !start -> IDLE.
                // So if state==DONE, done should be 1.
                // If state transitions to IDLE (because start went low), done becomes 0.
            end else if (state == IDLE) begin
                done <= 0;
                // done_items logic might be optional in IDLE, but result usually holds last value or garbage.
                // Let's clear result in IDLE? No, usually results are held until new computation.
                // Let's clear done_items in IDLE to indicate no data.
                done_items <= 0;
            end
        end
    end

    // Additional requirement: "In SORT state, use s0..s5 registers"
    // I need to make sure the sorting logic inside the clocked block is correct.
    // I will rewrite the sorting block cleanly to ensure no latches and correct routing.
    
    // Note: The previous always block for sorting (inside the register block) needs to be complete.
    // I will rely on the fact that in Verilog, if you don't assign a register in a clocked block, it keeps its value.
    // So for pass-through cases, I don't strictly need to assign every register if I am only updating the ones that change.
    // BUT, the network is a pipeline. In Cycle 2, s2 takes values from s1.
    // If I don't assign s2[0] in Cycle 2, it retains old value (from Cycle 1 or boot).
    // So I MUST assign all registers in each stage of the sorting network.
    // OR, I must default to 'pass through' and then overwrite swapped pairs.
    // Since I am using an if-else chain on sort_counter, I must explicitly assign ALL 8 items in EACH case.
    
    // Let's correct the sorting logic block inside the clocked process.
    // I will replace the previous incomplete block with a complete one.

    // Since I cannot edit the previous block in the final output, I must ensure it is perfect in the generation.
    // Let's carefully construct the sorting section.
    
    // Clocked block logic:
    if (state == IDLE && start) begin
        // Load inputs to s0 (or s1 to start pipeline? Let's use s0 as buffer)
        s0 <= items;
        // We can actually start pipeline 0 immediately if we want.
        // But let's follow the 6 cycle count.
        // If we start counting 0 at LOAD, we need to handle the first step.
        // Let's count 0..5 in SORT state.
        // Cycle 0 (sort_counter 0): Process s0 -> s1.
        // So s0 must be valid. s0 is loaded in IDLE->LOAD transition? 
        // My next_state logic: IDLE -> LOAD -> SORT (counter 0).
        // So if we go LOAD->SORT, we need s0 to be ready.
        // LOAD state is 1 cycle. So if state == LOAD, we set s0 = items.
    end
    
    // Let's re-evaluate the state transition timing.
    // Cycle N: State = IDLE. Start=1. Next = LOAD.
    // Cycle N+1: State = LOAD. 
    //   - In clocked block: s0 = items. (s0 ready now).
    //   - Next = SORT, counter=0.
    // Cycle N+2: State = SORT, counter=0.
    //   - Logic for counter 0: s1 = f(s0).
    //   - Next = SORT, counter=1.
    // Cycle N+3: State = SORT, counter=1.
    //   - Logic for counter 1: s2 = f(s1).
    // Cycle N+4: State = SORT, counter=2.
    //   - Logic for counter 2: s3 = f(s2).
    // Cycle N+5: State = SORT, counter=3.
    //   - Logic for counter 3: s4 = f(s3).
    // Cycle N+6: State = SORT, counter=4.
    //   - Logic for counter 4: s5 = f(s4).
    // Cycle N+7: State = SORT, counter=5.
    //   - Logic for counter 5: s5 = f(s5).
    // Cycle N+8: State = OUTPUT.
    //   - result = s5.
    //   - Next = DONE.
    // Cycle N+9: State = DONE.
    
    // Total latency 9 cycles from start pulse (Cycle N).
    
    // The missing pass-throughs:
    // Counter 0: s1 assigned full.
    // Counter 1: s2 assigned full.
    // Counter 2: s3 assigned indices 1,2,5,6 swapped; 0,3,4,7 passed. 
    //   - s3[0] <= s2[0]
    //   - s3[3] <= s2[3]
    //   - s3[4] <= s2[4]
    //   - s3[7] <= s2[7]
    // Counter 3: s4 assigned full.
    // Counter 4: s5 assigned indices 1,3,4,6 swapped; 0,2,5,7 passed.
    //   - s5[0] <= s4[0]
    //   - s5[2] <= s4[2]
    //   - s5[5] <= s4[5]
    //   - s5[7] <= s4[7]
    // Counter 5: s5 assigned indices 2,3,4,5 swapped; 0,1,6,7 passed.
    //   - s5[0] <= s5[0] (implicit)
    //   - s5[1] <= s5[1]
    //   - s5[6] <= s5[6]
    //   - s5[7] <= s5[7]
    //   - This is done by only assigning the swapped indices if the others are not overwritten.
    //   - Wait, if we write `s5[0] <= s5[0]` it works but it's redundant.
    //   - However, if we just assign `s5[2] <= ...` and `s5[4] <= ...`, then `s5[0]` retains the value from the previous clock edge.
    //   - In counter 5, we are reading `s5` (value from counter 4) and writing `s5` (new value).
    //   - This is a blocking assignment issue or a read-before-write issue in hardware.
    //   - In hardware registers, we read the OLD value before the clock edge, and write the NEW value.
    //   - So `s5[0]` retains value from counter 4 if not updated.
    //   - Correct.
    
    // So we can just assign the swapped indices. 
    // But we must be careful in Counter 2 and Counter 4 where not all indices are swapped.
    // In Counter 2, we must explicitly pass through the other indices to s3.
    // In Counter 4, we must explicitly pass through other indices to s5.
    
    // The code provided in the "Dummy" block earlier was:
    // if (sort_counter == 0) ...
    // else if (sort_counter == 1) ...
    // else if (sort_counter == 2) ...
    // 
    // I need to ensure the final code I generate has these pass-throughs.
    
    // One edge case: n input is 0? Spec says 1-3. I should handle n=0 just in case (output 0 items).
    
    // Let's prepare the final code string.
    // I will include a full always block for the sorting logic inside the main clocked block.
    // I'll use the logic derived above.
    
    // Also need to handle the `items` input. Spec says `input [7:0][63:0] items`. This is SV array syntax. 
    // Synthesizable for modern tools. 
    // `s0 <= items;` works.
    // Comparisons: `items[0][63:32] > items[1][63:32]`.
    
    // Final check on DONE state.
    // Output logic sets done=1 in OUTPUT state.
    // Then state goes to DONE.
    // In DONE state, done should remain 1.
    // So `else if (state == DONE) done <= 1;`? 
    // No, clocked block: if not assigned, it holds.
    // So if we set done=1 in OUTPUT, it stays 1 in DONE.
    // When we leave DONE (start goes low), next_state = IDLE.
    // In IDLE, we should clear done.
    // So in IDLE block: done <= 0.
    
    // What if start stays high?
    // In DONE, if start is high, next_state logic:
    // if (state == DONE) if (!start) next_state = IDLE else next_state = DONE.
    // So if start stays high, it stays in DONE.
    // Done stays high.
    // When start goes low, goes to IDLE, done clears.
    
    // Okay, looks solid.

endmodule

module top_items_finder (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0][63:0] items,
    output reg [2:0] done_items,
    output reg [7:0][63:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam SORT = 3'b010;
    localparam OUTPUT = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] sort_counter;
    reg [2:0] next_sort_counter;
    
    // Sorting registers
    reg [63:0] s0 [0:7]; // Load stage
    reg [63:0] s1 [0:7]; // Stage 1
    reg [63:0] s2 [0:7]; // Stage 2
    reg [63:0] s3 [0:7]; // Stage 3
    reg [63:0] s4 [0:7]; // Stage 4
    reg [63:0] s5 [0:7]; // Stage 5 & 6 (Final)
    
    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sort_counter <= 0;
            // Reset sorting registers
            s0 <= '{default:0};
            s1 <= '{default:0};
            s2 <= '{default:0};
            s3 <= '{default:0};
            s4 <= '{default:0};
            s5 <= '{default:0};
            done <= 0;
            done_items <= 0;
            result <= '{default:0};
        end else begin
            state <= next_state;
            sort_counter <= next_sort_counter;
            
            // LOAD state logic
            if (state == IDLE && start) begin
                // Capture inputs (standard practice to capture on start)
                // But to make it a 1-cycle LOAD state, we do it here or in LOAD state.
                // Let's do it in LOAD state to match the description.
            end
            
            // SORT state logic
            if (state == LOAD) begin
                s0 <= items;
            end
            
            if (state == SORT) begin
                case (sort_counter)
                    // Cycle 0: Stage 1
                    0: begin
                        // Pair (0,1)
                        if (s0[0][63:32] > s0[1][63:32]) begin s1[0] <= s0[0]; s1[1] <= s0[1]; end
                        else begin s1[0] <= s0[1]; s1[1] <= s0[0]; end
                        // Pair (2,3)
                        if (s0[2][63:32] > s0[3][63:32]) begin s1[2] <= s0[2]; s1[3] <= s0[3]; end
                        else begin s1[2] <= s0[3]; s1[3] <= s0[2]; end
                        // Pair (4,5)
                        if (s0[4][63:32] > s0[5][63:32]) begin s1[4] <= s0[4]; s1[5] <= s0[5]; end
                        else begin s1[4] <= s0[5]; s1[5] <= s0[4]; end
                        // Pair (6,7)
                        if (s0[6][63:32] > s0[7][63:32]) begin s1[6] <= s0[6]; s1[7] <= s0[7]; end
                        else begin s1[6] <= s0[7]; s1[7] <= s0[6]; end
                    end
                    // Cycle 1: Stage 2
                    1: begin
                        // Pair (0,2)
                        if (s1[0][63:32] > s1[2][63:32]) begin s2[0] <= s1[0]; s2[2] <= s1[2]; end
                        else begin s2[0] <= s1[2]; s2[2] <= s1[0]; end
                        // Pair (1,3)
                        if (s1[1][63:32] > s1[3][63:32]) begin s2[1] <= s1[1]; s2[3] <= s1[3]; end
                        else begin s2[1] <= s1[3]; s2[3] <= s1[1]; end
                        // Pair (4,6)
                        if (s1[4][63:32] > s1[6][63:32]) begin s2[4] <= s1[4]; s2[6] <= s1[6]; end
                        else begin s2[4] <= s1[6]; s2[6] <= s1[4]; end
                        // Pair (5,7)
                        if (s1[5][63:32] > s1[7][63:32]) begin s2[5] <= s1[5]; s2[7] <= s1[7]; end
                        else begin s2[5] <= s1[7]; s2[7] <= s1[5]; end
                    end
                    // Cycle 2: Stage 3
                    2: begin
                        // Pass through non-swapped
                        s3[0] <= s2[0]; s3[3] <= s2[3]; s3[4] <= s2[4]; s3[7] <= s2[7];
                        // Pair (1,2)
                        if (s2[1][63:32] > s2[2][63:32]) begin s3[1] <= s2[1]; s3[2] <= s2[2]; end
                        else begin s3[1] <= s2[2]; s3[2] <= s2[1]; end
                        // Pair (5,6)
                        if (s2[5][63:32] > s2[6][63:32]) begin s3[5] <= s2[5]; s3[6] <= s2[6]; end
                        else begin s3[5] <= s2[6]; s3[6] <= s2[5]; end
                    end
                    // Cycle 3: Stage 4
                    3: begin
                        // Pair (0,4)
                        if (s3[0][63:32] > s3[4][63:32]) begin s4[0] <= s3[0]; s4[4] <= s3[4]; end
                        else begin s4[0] <= s3[4]; s4[4] <= s3[0]; end
                        // Pair (1,5)
                        if (s3[1][63:32] > s3[5][63:32]) begin s4[1] <= s3[1]; s4[5] <= s3[5]; end
                        else begin s4[1] <= s3[5]; s4[5] <= s3[1]; end
                        // Pair (2,6)
                        if (s3[2][63:32] > s3[6][63:32]) begin s4[2] <= s3[2]; s4[6] <= s3[6]; end
                        else begin s4[2] <= s3[6]; s4[6] <= s3[2]; end
                        // Pair (3,7)
                        if (s3[3][63:32] > s3[7][63:32]) begin s4[3] <= s3[3]; s4[7] <= s3[7]; end
                        else begin s4[3] <= s3[7]; s4[7] <= s3[3]; end
                    end
                    // Cycle 4: Stage 5
                    4: begin
                        // Pass through non-swapped
                        s5[0] <= s4[0]; s5[2] <= s4[2]; s5[5] <= s4[5]; s5[7] <= s4[7];
                        // Pair (1,4)
                        if (s4[1][63:32] > s4[4][63:32]) begin s5[1] <= s4[1]; s5[4] <= s4[4]; end
                        else begin s5[1] <= s4[4]; s5[4] <= s4[1]; end
                        // Pair (3,6)
                        if (s4[3][63:32] > s4[6][63:32]) begin s5[3] <= s4[3]; s5[6] <= s4[6]; end
                        else begin s5[3] <= s4[6]; s5[6] <= s4[3]; end
                    end
                    // Cycle 5: Stage 6
                    5: begin
                        // Pass through non-swapped (retain values from previous cycle)
                        // Note: we are assigning to s5, so we read from s5 (old value) and write to s5 (new value)
                        // The read value is from Cycle 4 result.
                        // s5[0], s5[1], s5[6], s5[7] are not swapped, so they stay the same.
                        // We don't need to write them explicitly if we don't overwrite them.
                        
                        // Pair (2,4)
                        if (s5[2][63:32] > s5[4][63:32]) begin 
                            // Swap: put max in 2, min in 4
                            // We need temp storage or sequential assignment.
                            // Standard register update: calculate new values.
                            // However, s5[2] and s5[4] are updated simultaneously.
                            // We must capture old values first.
                            // But 's5' on RHS is the value before clock edge (Cycle 4 result). 
                            // So it works for comparison. 
                            // But we need to swap them.
                            // s5[2] <= s5[2] (no, swap)
                            // s5[2] <= s5[4] (old)
                            // s5[4] <= s5[2] (old)
                            
                            // Wait, if we do:
                            // s5[2] <= s5[4];
                            // s5[4] <= s5[2];
                            // This works in Verilog non-blocking assignments because RHS is evaluated before update.
                            
                            // But wait, we only want to swap if 2 > 4. 
                            // If 2 > 4, we keep 2 in 2, 4 in 4. 
                            // So no swap needed.
                            // If 2 <= 4, we swap: 2 gets 4, 4 gets 2.
                            // So logic is:
                            // if (old_s5[2] > old_s5[4]) no change.
                            // else swap.
                            
                            // Let's simplify:
                            // s5[2] <= (s5[2][63:32] > s5[4][63:32]) ? s5[2] : s5[4];
                            // s5[4] <= (s5[2][63:32] > s5[4][63:32]) ? s5[4] : s5[2];
                            
                            // However, s5[2] on RHS is the OLD value.
                            // If we assign s5[2] first, s5[2] becomes new value.
                            // Then s5[4] reads new s5[2]? No, non-blocking.
                            // So it is safe.
                            
                            if (s5[2][63:32] > s5[4][63:32]) begin
                                s5[2] <= s5[2];
                                s5[4] <= s5[4];
                            end else begin
                                s5[2] <= s5[4];
                                s5[4] <= s5[2];
                            end
                        end
                        // Pair (3,5)
                        // This is (3,5) not (3,6) as I wrote in thought process. 
                        // Bose Nelson: (2,4), (3,5).
                        if (s5[3][63:32] > s5[5][63:32]) begin
                            s5[3] <= s5[3];
                            s5[5] <= s5[5];
                        end else begin
                            s5[3] <= s5[5];
                            s5[5] <= s5[3];
                        end
                    end
                endcase
            end
            
            // OUTPUT state logic
            if (state == OUTPUT) begin
                done_items <= n;
                done <= 1;
                
                // Map s5 to result based on n
                // If n=0, handle explicitly (though spec says 1-3)
                if (n >= 1) result[0] <= s5[0]; else result[0] <= 64'b0;
                if (n >= 2) result[1] <= s5[1]; else result[1] <= 64'b0;
                if (n >= 3) result[2] <= s5[2]; else result[2] <= 64'b0;
                if (n >= 4) result[3] <= s5[3]; else result[3] <= 64'b0;
                if (n >= 5) result[4] <= s5[4]; else result[4] <= 64'b0;
                if (n >= 6) result[5] <= s5[5]; else result[5] <= 64'b0;
                if (n >= 7) result[6] <= s5[6]; else result[6] <= 64'b0;
                if (n >= 8) result[7] <= s5[7]; else result[7] <= 64'b0;
                // Note: n is 3 bits, max 7. 8 is impossible if input is 3 bits. 
                // But check: n is input [2:0]. Range 0-7.
                // Spec says 1-3. 
                // I'll keep the >= 8 check for completeness but it won't trigger.
            end else if (state == IDLE) begin
                // Clear done flag when returning to idle
                done <= 0;
                done_items <= 0;
            end else if (state == DONE) begin
                // Keep done high if we stay in DONE (start held high)
                // done is already 1 from OUTPUT.
                // If we want to pulse done only in OUTPUT, we would clear it here.
                // Spec: "DONE: Assert done signal". 
                // Let's keep it asserted in DONE state too.
                done <= 1;
            end
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        next_sort_counter = sort_counter;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            LOAD: begin
                next_state = SORT;
                next_sort_counter = 0;
            end
            SORT: begin
                if (sort_counter < 5) begin
                    next_sort_counter = sort_counter + 1;
                end else begin
                    next_state = OUTPUT;
                end
            end
            OUTPUT: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
