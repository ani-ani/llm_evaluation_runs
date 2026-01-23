module lps(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
    output reg [3:0] result,
    output reg done
);

    parameter CHAR_WIDTH = 8;
    parameter LUT_SIZE = 8;

    // State Encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Internal Registers
    reg [1:0] state, next_state;
    reg [3:0] dp_table [0:7][0:7]; // 8x8 DP table, 4 bits per entry
    reg [2:0] cl; // Current substring length (1 to 8)
    reg [2:0] i;  // Row index
    reg [2:0] j;  // Column index
    reg [6:0] op_count; // Operation counter to track 128 cycles
    
    // Wires for character comparison (combinational logic)
    wire char_eq;
    assign char_eq = (get_char(i) == get_char(j));

    // Helper function to map index to input ports
    function [7:0] get_char;
        input [2:0] idx;
        begin
            case(idx)
                3'd0: get_char = char_0;
                3'd1: get_char = char_1;
                3'd2: get_char = char_2;
                3'd3: get_char = char_3;
                3'd4: get_char = char_4;
                3'd5: get_char = char_5;
                3'd6: get_char = char_6;
                3'd7: get_char = char_7;
                default: get_char = 8'h00;
            endcase
        end
    endfunction

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = PROCESSING;
                else next_state = IDLE;
            end
            PROCESSING: begin
                if (op_count == 7'd127) next_state = DONE;
                else next_state = PROCESSING;
            end
            DONE: begin
                // Stay in DONE until reset or new start
                if (start) next_state = PROCESSING;
                else next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main Datapath Logic (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 4'd0;
            done <= 1'b0;
            op_count <= 7'd0;
            cl <= 3'd1;
            i <= 3'd0;
            j <= 3'd0;
            // Reset DP Table (optional but good practice)
            // Synthesis tools usually initialize to 0, but let's be explicit in the logic flow
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        op_count <= 7'd0;
                        cl <= 3'd1; // Start with length 1 in first step of PROCESSING
                        i <= 3'd0;
                    end
                end

                PROCESSING: begin
                    // Algorithm mapped to linear 128-cycle sequence
                    // Cycle breakdown:
                    // 0-7: L[i][i] = 1 (cl=1)
                    // 8-31: cl=2, 7 iterations (indices 0-6)
                    // 32-55: cl=3, 6 iterations
                    // ... 
                    // 120-127: cl=8, 1 iteration

                    if (op_count < 8) begin
                        // --- Phase 1: Initialize Diagonals (cl=1) ---
                        // i = op_count (0 to 7)
                        dp_table[op_count][op_count] <= 4'd1;
                        
                    end else begin
                        // --- Phase 2: Main DP Loop (cl=2 to 8) ---
                        // Derive cl and i from op_count
                        // op_count 8 maps to cl=2, i=0
                        // op_count 127 maps to cl=8, i=0
                        
                        // cl calculation: cl = 2 + (op_count - 8) / 7
                        // i calculation: i = (op_count - 8) % 7 (clamped by current max i)
                        // However, simpler to just use a counter and update cl/i explicitly or compute next indices
                        
                        // Let's stick to the explicit counter approach implied by "128 cycles"
                        // We just need to correctly index the table based on the current op_count
                        
                        // Pre-calculate next indices for cleaner logic
                        if (op_count >= 8) begin
                            // We are in cl >= 2 phase
                            // We need to update the indices continuously or map mathematically
                            
                            // Let's use the logic derived in thought trace:
                            // We update cl and i at boundaries
                            
                            // We need the values of j, val1, val2 for the calculation at THIS step
                            // Wait, the assignment says "Store results in 8x8 memory array".
                            // The control logic must be robust.
                            
                            // Let's re-instantiate the indices for this clock cycle explicitly
                            // We need to know exactly who is i and j for the current op_count
                            
                            // Dynamic index calculation for the DP step:
                            // Offset = op_count - 8
                            // cl = 2 + Offset / 7
                            // i = Offset % 7
                            // BUT i must be < 8-cl+1. 
                            
                            // Let's use the explicit counter variables 'cl' and 'i' maintained in registers
                            // to drive the logic, and we update them at the end of the cycle.
                            
                            // 1. Compute Logic for CURRENT values of cl and i
                            // Note: j = i + cl - 1
                            // In PROCESSING state, we are calculating L[i][j] for current i, cl
                            
                            // We need to fetch L[i+1][j] and L[i][j-1] (and L[i+1][j-1])
                            // Since we fill table row-by-row, top-left to bottom-right, and cl increases,
                            // these values are ALWAYS ready in the table.
                            
                            if (cl == 3'd2 && char_eq) begin
                                dp_table[i][i+1] <= 4'd2;
                            end else if (char_eq) begin
                                // L[i][j] = L[i+1][j-1] + 2
                                dp_table[i][i+cl-1] <= dp_table[i+1][i+cl-2] + 2;
                            end else begin
                                // L[i][j] = max(L[i][j-1], L[i+1][j])
                                // Manual max logic for synthesis
                                if (dp_table[i][i+cl-2] >= dp_table[i+1][i+cl-1])
                                    dp_table[i][i+cl-1] <= dp_table[i][i+cl-2];
                                else
                                    dp_table[i][i+cl-1] <= dp_table[i+1][i+cl-1];
                            end
                        end
                    end

                    // Update Counters for Next Cycle
                    if (op_count < 7'd127) begin
                        op_count <= op_count + 1;
                        
                        // Logic to update i and cl for next cycle
                        if (op_count < 7'd7) begin
                            // Still in diagonal init (cl=1)
                            // i increments naturally with op_count
                        end else begin
                            // In cl >= 2 phase
                            // We need to advance i. If i reaches max, reset i and inc cl.
                            // Current max i for cl is 8 - cl.
                            // However, we are updating for the NEXT cycle.
                            
                            // Let's predict the next state of (cl, i) based on current (cl, i)
                            // Current (cl, i) valid for calculation at op_count >= 8.
                            // At op_count = 8, cl=2, i=0.
                            // At op_count = 9, we need cl=2, i=1.
                            
                            // We need to handle the transition logic carefully.
                            // Actually, we can just keep the counters running and update them.
                            // Current i is valid. Is i < (8 - cl) ?
                            // If yes, next i = i + 1.
                            // If no, next i = 0, next cl = cl + 1.
                            
                            // But wait, we need to know the CURRENT cl and i to compute the DP value.
                            // We initialized cl=1 in IDLE.
                            // At op_count=0 (first iter of processing), we do diag init.
                            // At op_count=8, we are starting cl=2.
                            // So at op_count=8, we need cl=2, i=0.
                            
                            // Let's maintain cl and i explicitly.
                            // Initialization in IDLE: cl=1, i=0.
                            // In PROCESSING:
                            // If op_count < 8: We are in diag init. i increments. (0..7)
                            // At op_count=8: Start cl=2, i=0.
                            
                            // Let's implement a state machine for (cl, i) updates.
                            // Actually, simpler to just compute next cl/i from op_count.
                            // Let's use the "op_count" to infer cl and i.
                            // But we need dp_table accesses, so we need them registered or combinational.
                            
                            // Let's use the explicit register update logic:
                            // If op_count >= 8: 
                            //   If (op_count - 8) % 7 == 6 (i.e. we just did the last i for current cl)
                            //      Next cl = cl + 1, Next i = 0
                            //   Else
                            //      Next cl = cl, Next i = i + 1
                            
                            // However, we need to know cl/i *during* the cycle to access dp_table.
                            // So we must update cl/i at the END of the cycle for the NEXT iteration.
                            
                            // Fix: We will use a separate "current" index logic or assume the register values are for the current operation.
                            // Let's use the register values of cl and i as the CURRENT operation indices.
                            // We initialized cl=1, i=0 in IDLE.
                            // We need to set them correctly before the first op of PROCESSING.
                            
                            // Correction:
                            // In IDLE->PROCESSING transition, we need cl=1, i=0? 
                            // No, op_count 0 is diag init (cl=1 concept). 
                            // Let's use a single step counter and compute indices on the fly for the read/write.
                            // This avoids complex state updates inside the loop.
                            
                            // Let's restructure the Datapath slightly:
                            // We will use 'op_count' to determine (cl, i, j) for the current cycle.
                            // We will calculate (next_cl, next_i) to store in registers for the *next* cycle (though we might recompute anyway).
                            
                            // Let's stick to the "Update counters at end" logic.
                            // But we need cl/i for the DP calculation in the body.
                            // So we need to calculate cl and i for the CURRENT op_count.
                            
                            // Calculation for CURRENT indices based on op_count:
                            // If op_count < 8: cl=1, i=op_count. (Actually cl is implicit, target is diag).
                            // If op_count >= 8: 
                            //   Offset = op_count - 8
                            //   cl = 2 + (Offset / 7)  // Integer division
                            //   i = Offset % 7
                            //   if (i >= 8 - cl) then this is the LAST element of the row (e.g. cl=3, i=4 -> j=6, next is cl=4)
                            //   Wait, cl=3 range is i=0 to 4 (5 elements). 8-cl = 5. i goes 0,1,2,3,4. 
                            //   The calculation holds. 
                            
                            // So we will calculate cl_current, i_current inside the always block.
                            // We don't actually need to store cl/i registers if we calculate them from op_count.
                            // But we need to write to dp_table. 
                            // Let's do this: calculate (cl_cur, i_cur) combinationally based on op_count.
                            // Then use those to read/write dp_table.
                            // Update op_count sequentially.
                            // This is cleaner.
                            
                            // However, the prompt says "State machine: IDLE -> PROCESSING (8x8 iterations) -> DONE".
                            // The iterations count is 128. 
                            // The logic calculation (comb) is heavy but valid.
                            
                            // Let's stick to the register approach for cl and i to save logic depth, 
                            // as area/latency is a concern in ASIC, and 128 cycles is fixed.
                            
                            // Re-implementation of sequential logic for (cl, i):
                            // We assume we are in the state PROCESSING.
                            // We need to figure out what cl and i are for THIS cycle.
                            // We will update them at the end.
                            
                            // Let's update the logic block below to be explicit.
                            
                        end // end if op_count >= 8
                    end // end if op_count < 127
                end // end PROCESSING state

                DONE: begin
                    result <= dp_table[0][7];
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Logic to update op_count, cl, i, j (Refactored for clarity inside the main block)
    // Since we need to handle the indices correctly, let's simplify the sequential block
    // and move the index update logic here.
    
    // Actually, let's refine the PROCESSING block to be purely about the calculation
    // and update the counters cleanly.
    // The 'dp_table' update logic in the main block above uses 'cl' and 'i'.
    // We must ensure 'cl' and 'i' are correct for the specific 'op_count'.
    
    // Let's create a combinational block to set cl and i based on op_count,
    // or just update them sequentially.
    
    // Sequential update for cl and i:
    // In IDLE, we can set cl=1, i=0.
    // In PROCESSING, at the end of every cycle (except the last):
    //   If op_count < 7: (Init phase) -> i = op_count + 1 (next), cl=1.
    //   If op_count == 7: Transition to cl=2, i=0.
    //   If op_count >= 8:
    //      If i == 8 - cl - 1: // i is at the last valid position for current cl
    //          i <= 0;
    //          cl <= cl + 1;
    //      else:
    //          i <= i + 1;
    
    // Let's inject this logic into the PROCESSING block.
    // Since we already wrote the body, let's rewrite the PROCESSING block fully to be robust.
    
    // RE-WRITING PROCESSING BLOCK FOR SYNTHESIS ROBUSTNESS
    // We need to ensure we don't drive 'dp_table' with X or wrong indices.
    // We will use 'cl_reg' and 'i_reg' to store the CURRENT operation indices.
    
    reg [2:0] cl_reg;
    reg [2:0] i_reg;
    
    // Helper wire for j
    wire [2:0] j_reg;
    assign j_reg = i_reg + cl_reg - 1;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 4'd0;
            done <= 1'b0;
            op_count <= 7'd0;
            cl_reg <= 3'd0;
            i_reg <= 3'd0;
            // Clear dp_table? Usually not done in hardware unless reset clears it.
            // We'll just overwrite it.
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        op_count <= 7'd0;
                        cl_reg <= 3'd1; // Prepare for first op: Diag init
                        i_reg <= 3'd0;
                    end
                end

                PROCESSING: begin
                    // 1. Perform Calculation based on current cl_reg and i_reg
                    // Note: We must handle cl=1 specially (diagonal init)
                    if (cl_reg == 3'd1) begin
                        // Diagonal init: L[i][i] = 1
                        dp_table[i_reg][i_reg] <= 4'd1;
                    end else begin
                        // cl >= 2
                        if (cl_reg == 3'd2 && (get_char(i_reg) == get_char(j_reg))) begin
                            dp_table[i_reg][j_reg] <= 4'd2;
                        end else if (get_char(i_reg) == get_char(j_reg)) begin
                            dp_table[i_reg][j_reg] <= dp_table[i_reg + 1][j_reg - 1] + 2;
                        end else begin
                            if (dp_table[i_reg][j_reg - 1] >= dp_table[i_reg + 1][j_reg])
                                dp_table[i_reg][j_reg] <= dp_table[i_reg][j_reg - 1];
                            else
                                dp_table[i_reg][j_reg] <= dp_table[i_reg + 1][j_reg];
                        end
                    end

                    // 2. Update Counters for Next Cycle
                    if (op_count < 7'd127) begin
                        op_count <= op_count + 1;
                        
                        // Update i_reg and cl_reg for the NEXT operation
                        if (cl_reg == 3'd1) begin
                            if (i_reg < 3'd7) begin
                                i_reg <= i_reg + 1;
                            end else begin
                                // Finished diag, move to cl=2
                                cl_reg <= 3'd2;
                                i_reg <= 3'd0;
                            end
                        end else begin
                            // Determine max i for current cl: 8 - cl
                            // If we just computed the last element of the row (i == 8 - cl), move to next cl
                            if (i_reg == (4'd8 - cl_reg - 1)) begin
                                cl_reg <= cl_reg + 1;
                                i_reg <= 3'd0;
                            end else begin
                                i_reg <= i_reg + 1;
                            end
                        end
                    end
                end

                DONE: begin
                    // Latch the final result
                    result <= dp_table[0][7];
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule