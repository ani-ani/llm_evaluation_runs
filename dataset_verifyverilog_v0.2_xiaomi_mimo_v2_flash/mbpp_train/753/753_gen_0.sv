module min_k_records(
    input clk,
    input rst_n,
    input start,
    input [3:0] K,
    input [31:0] name_0, name_1, name_2, name_3,
    input [7:0] score_0, score_1, score_2, score_3,
    output reg [31:0] out_name_0, out_name_1, out_name_2, out_name_3,
    output reg [7:0] out_score_0, out_score_1, out_score_2, out_score_3,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam SORT = 2'b01;
    localparam OUTPUT = 2'b10;
    localparam DONE_STATE = 2'b11;

    // Registers for state machine
    reg [1:0] state, next_state;
    reg [2:0] cycle_count, next_cycle_count;
    reg [2:0] out_idx, next_out_idx;

    // Intermediate sorted records after each stage
    // Each record has {name, score}
    // 32 bits name + 8 bits score = 40 bits
    wire [39:0] rec0_s1, rec1_s1, rec2_s1, rec3_s1;
    wire [39:0] rec0_s2, rec1_s2, rec2_s2, rec3_s2;
    wire [39:0] rec0_s3, rec1_s3, rec2_s3, rec3_s3;

    // Input packing
    wire [39:0] in_rec0 = {name_0, score_0};
    wire [39:0] in_rec1 = {name_1, score_1};
    wire [39:0] in_rec2 = {name_2, score_2};
    wire [39:0] in_rec3 = {name_3, score_3};

    // --- STAGE 1 REGISTERS (Cycle 1) ---
    reg [39:0] s1_rec0, s1_rec1, s1_rec2, s1_rec3;

    // Combinational Logic for Stage 1 Compare-and-Swap (0-1, 2-3)
    // Done at input to Stage 1 registers (calculates values for cycle 1)
    // The spec says "Latency: 6 clock cycles... combinational sorting network with pipelined registers"
    // We interpret this as: Start -> Cycle 1 (Stage 1 Out) -> Cycle 2 (Stage 2 Out) -> Cycle 3 (Stage 3 Out) -> Output
    // Total latency from start assertion to valid sorted data is 3 cycles.
    // To reach 6 cycles total latency to DONE, we will extend the state machine timing or add pipeline depth.
    // Let's strictly follow "Stage 1 -> Stage 2 -> Stage 3".
    // We will use the registers s1_rec etc. as the pipeline stages.

    // Helper function for min/max swap
    function [39:0] csw(input [39:0] a, b);
        // Sort ascending by score (lower 8 bits)
        csw = (a[7:0] <= b[7:0]) ? a : b;
    endfunction

    function [39:0] csw_max(input [39:0] a, b);
        // Helper to keep the larger one for the other path if needed, 
        // but simpler to just specify outputs of the swap unit.
        // Standard compare-swap: output smaller on A port, larger on B port.
        csw_max = (a[7:0] <= b[7:0]) ? b : a;
    endfunction

    // Stage 1 Logic (Combinational preceding the s1 registers, but since we need 6 cycles, 
    // we will implement the pipeline registers explicitly and flow data through).
    // Actually, to achieve 6 cycles latency, let's look at the pipeline stages:
    // Cycle 0: Input latched (or just available on inputs)
    // Cycle 1: Stage 1 computes, latched in S1 reg.
    // Cycle 2: Stage 2 computes, latched in S2 reg.
    // Cycle 3: Stage 3 computes, latched in S3 reg.
    // Cycle 4: Output state starts.
    // This is only 4 cycles.
    // Requirement: "Latency: 6 clock cycles after start".
    // I will add two dummy pipeline stages or double register the outputs to meet the 6 cycle constraint strictly.
    // Let's assume the "6 cycles" includes the time to fill the pipeline and output.
    // I will strictly implement the 3 stages as requested and the state machine, 
    // but I will insert a 2-cycle delay in the OUTPUT or DONE phase to meet the 6 cycle total latency requirement.
    // Or simply, the user wants the computation to take 6 cycles. 
    // Let's break down: 3 stages of sorting network. 
    // I will add 3 extra cycles of delay to satisfy the "6 cycles" requirement.
    // Wait, "Latency: 6 clock cycles after start".
    // If I have 3 stages, I need 3 registers. 
    // If I use 3 stages of registers, and the start pulse is at cycle 0:
    // Cycle 1: Stage 1 valid.
    // Cycle 2: Stage 2 valid.
    // Cycle 3: Stage 3 valid.
    // Cycle 4: Output can happen.
    // Cycle 5: Done.
    // To make it 6 cycles, I will add 2 more wait states.
    // Let's modify the design to: IDLE -> S1 -> S2 -> S3 -> OUTPUT -> DONE (Wait) -> DONE.
    // Or simpler: Calculate in 3 cycles, then wait 3 cycles in OUTPUT/DONE.
    // Actually, let's look at the state machine requirement: IDLE -> SORT -> OUTPUT -> DONE.
    // I will map SORT to take 3 cycles (handling the stages), and OUTPUT/DONE to take 3 cycles.

    // --- STAGE 1 ---
    wire [39:0] s1_in_0 = in_rec0;
    wire [39:0] s1_in_1 = in_rec1;
    wire [39:0] s1_in_2 = in_rec2;
    wire [39:0] s1_in_3 = in_rec3;

    wire [39:0] s1_out_0 = csw(s1_in_0, s1_in_1);
    wire [39:0] s1_out_1 = csw_max(s1_in_0, s1_in_1);
    wire [39:0] s1_out_2 = csw(s1_in_2, s1_in_3);
    wire [39:0] s1_out_3 = csw_max(s1_in_2, s1_in_3);

    // --- STAGE 2 REGISTERS (Cycle 2) ---
    reg [39:0] s2_rec0, s2_rec1, s2_rec2, s2_rec3;

    // Stage 2 Logic (Compare Cross Pairs: 0-2, 1-3)
    // Inputs are Stage 1 outputs
    wire [39:0] s2_in_0 = s1_rec0;
    wire [39:0] s2_in_1 = s1_rec1;
    wire [39:0] s2_in_2 = s1_rec2;
    wire [39:0] s2_in_3 = s1_rec3;

    wire [39:0] s2_out_0 = csw(s2_in_0, s2_in_2);
    wire [39:0] s2_out_1 = csw(s2_in_1, s2_in_3);
    wire [39:0] s2_out_2 = csw_max(s2_in_0, s2_in_2);
    wire [39:0] s2_out_3 = csw_max(s2_in_1, s2_in_3);

    // --- STAGE 3 REGISTERS (Cycle 3) ---
    reg [39:0] s3_rec0, s3_rec1, s3_rec2, s3_rec3;

    // Stage 3 Logic (Compare Adjacent Pairs: 1-2)
    // Inputs are Stage 2 outputs
    wire [39:0] s3_in_0 = s2_rec0;
    wire [39:0] s3_in_1 = s2_rec1;
    wire [39:0] s3_in_2 = s2_rec2;
    wire [39:0] s3_in_3 = s2_rec3;

    wire [39:0] s3_out_0 = s3_in_0; // 0 stays
    wire [39:0] s3_out_1 = csw(s3_in_1, s3_in_2);
    wire [39:0] s3_out_2 = csw_max(s3_in_1, s3_in_2);
    wire [39:0] s3_out_3 = s3_in_3; // 3 stays

    // --- Registers Update Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 0;
            out_idx <= 0;
            // Reset registers
            s1_rec0 <= 0; s1_rec1 <= 0; s1_rec2 <= 0; s1_rec3 <= 0;
            s2_rec0 <= 0; s2_rec1 <= 0; s2_rec2 <= 0; s2_rec3 <= 0;
            s3_rec0 <= 0; s3_rec1 <= 0; s3_rec2 <= 0; s3_rec3 <= 0;
            // Reset outputs
            out_name_0 <= 0; out_name_1 <= 0; out_name_2 <= 0; out_name_3 <= 0;
            out_score_0 <= 0; out_score_1 <= 0; out_score_2 <= 0; out_score_3 <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            cycle_count <= next_cycle_count;
            out_idx <= next_out_idx;

            // Pipeline updates
            if (state == IDLE && start) begin
                // Latch inputs into Stage 1 logic (conceptually) or update registers
                // We update registers based on next_state logic usually, 
                // but here we want to propagate data through stages.
                // The control logic decides when to shift data.
                // Since we need to pipeline, we register the results of the compare-swaps.
            end

            // Update Stage Registers
            if (state == SORT) begin
                if (cycle_count == 0) begin
                    // Move input to Stage 1 logic and latch output to s1 regs
                    // But if cycle_count=0 in SORT, we usually start computation.
                    // Let's define: cycle_count tracks sub-steps in SORT.
                    // 0 -> calculate s1, latch to s1_regs
                    // 1 -> calculate s2, latch to s2_regs
                    // 2 -> calculate s3, latch to s3_regs
                    s1_rec0 <= s1_out_0; s1_rec1 <= s1_out_1; s1_rec2 <= s1_out_2; s1_rec3 <= s1_out_3;
                end else if (cycle_count == 1) begin
                    s2_rec0 <= s2_out_0; s2_rec1 <= s2_out_1; s2_rec2 <= s2_out_2; s2_rec3 <= s2_out_3;
                end else if (cycle_count == 2) begin
                    s3_rec0 <= s3_out_0; s3_rec1 <= s3_out_1; s3_rec2 <= s3_out_2; s3_rec3 <= s3_out_3;
                end
            end

            // Output Registers
            if (state == OUTPUT) begin
                // We need to output K records. 
                // To meet 6 cycle latency, we will output one record per cycle (or a few cycles wait).
                // The requirement "Unused output slots should have zero value".
                // We will output the sorted records from s3_regs.
                // We need to handle K. 
                // If we are in OUTPUT state, we probably need to iterate or just latch the valid ones.
                // Since there are 4 outputs, we can just latch them based on K.
                // But we have to fill 6 cycles. 
                // Let's assume we just do the computation and then wait in DONE for the remaining cycles to hit 6.
                // However, the prompt implies a stream or valid output at the end.
                // Let's output the data when we reach the DONE state (which happens after 6 cycles total).
                // So, at cycle 5 (6th cycle counting start), we go to DONE and assert data.
                // But wait, "output the first K records". 
                // If I wait until cycle 5, I just put the data on the bus. That's one cycle of data valid.
                // If I need to output K records over time, I would need a valid signal. 
                // The prompt gives output registers. 
                // I will assume we latch the output values when the computation is finished (at the end of cycle 5).
                // The state machine will run for 6 cycles total.
                // Cycle 0: Start (IDLE -> SORT)
                // Cycle 1: S1
                // Cycle 2: S2
                // Cycle 3: S3
                // Cycle 4: Wait (to stretch to 6)
                // Cycle 5: Wait
                // Cycle 6: DONE (Data valid)
                // Actually, let's just use a 3-bit counter in SORT state.
                // SORT state takes 3 cycles (0, 1, 2).
                // Then OUTPUT state takes 3 cycles (3, 4, 5).
                // At cycle 5 (end of OUTPUT), we go to DONE and assert data.
                // This gives 6 cycles from start (cycle 0) to DONE.
            end
            
            if (state == DONE_STATE) begin
                // Latch the final sorted values into output registers
                // We need to mask based on K.
                // s3_rec0 is smallest, s3_rec1 is second, etc.
                // out_score_0 <= (K > 0) ? s3_rec0[7:0] : 8'b0;
                // out_name_0 <= (K > 0) ? s3_rec0[39:8] : 32'b0;
                // ...
                // But we should do this in the OUTPUT state transition or DONE state entry.
                // Let's do it when we enter DONE.
            end
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        next_state = state;
        next_cycle_count = cycle_count;
        next_out_idx = out_idx;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SORT;
                    next_cycle_count = 0;
                end
            end
            
            SORT: begin
                if (cycle_count < 3'd2) begin // 0, 1, 2 (3 cycles total)
                    next_cycle_count = cycle_count + 1;
                end else begin
                    next_state = OUTPUT;
                    next_cycle_count = 0;
                end
            end

            OUTPUT: begin
                // Wait for 2 more cycles to meet 6 cycle latency requirement
                // Total time: 3 (SORT) + 3 (OUTPUT) = 6 cycles.
                if (cycle_count < 3'd2) begin
                    next_cycle_count = cycle_count + 1;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                // Stay here for one cycle to assert done signal and output data
                // Then return to IDLE if start is low, or handle new start.
                // Assuming start goes low after assertion.
                // If start stays high, we might loop. 
                // Let's go back to IDLE.
                next_state = IDLE;
            end
        endcase
    end

    // Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main block
        end else begin
            // Done signal
            if (state == DONE_STATE && next_state == IDLE) begin
                done <= 1'b1;
                // Latch outputs here
                // Use K to mask
                // s3_rec0 is smallest (index 0)...
                // But wait, the sorting network logic needs to be verified.
                // Standard odd-even transposition sort for 4 elements:
                // Stage 1: (0-1), (2-3)
                // Stage 2: (0-2), (1-3)
                // Stage 3: (1-2)
                // This results in sorted sequence 0, 1, 2, 3.
                
                // Output assignments
                if (K >= 1) begin
                    out_name_0 <= s3_rec0[39:8];
                    out_score_0 <= s3_rec0[7:0];
                end else begin
                    out_name_0 <= 32'b0;
                    out_score_0 <= 8'b0;
                end

                if (K >= 2) begin
                    out_name_1 <= s3_rec1[39:8];
                    out_score_1 <= s3_rec1[7:0];
                end else begin
                    out_name_1 <= 32'b0;
                    out_score_1 <= 8'b0;
                end

                if (K >= 3) begin
                    out_name_2 <= s3_rec2[39:8];
                    out_score_2 <= s3_rec2[7:0];
                end else begin
                    out_name_2 <= 32'b0;
                    out_score_2 <= 8'b0;
                end

                if (K >= 4) begin
                    out_name_3 <= s3_rec3[39:8];
                    out_score_3 <= s3_rec3[7:0];
                end else begin
                    out_name_3 <= 32'b0;
                    out_score_3 <= 8'b0;
                end
            end else if (state == IDLE) begin
                done <= 1'b0;
            end
        end
    end

endmodule
