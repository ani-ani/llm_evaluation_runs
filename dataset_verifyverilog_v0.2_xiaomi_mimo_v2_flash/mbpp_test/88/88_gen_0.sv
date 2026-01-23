module freq_counter (
    input clk,
    input rst_n,
    input start,
    input [6:0] list_data [0:15],
    output reg [6:0] unique_values [0:7],
    output reg [3:0] frequencies [0:7],
    output reg [3:0] unique_count,
    output reg done
);

    // State encoding
    localparam IDLE          = 3'b001;
    localparam COLLECT_UNIQUE = 3'b010;
    localparam COUNT_FREQ    = 3'b100;
    // Note: DONE state is handled by setting done flag and returning to IDLE on next cycle

    reg [2:0] state;
    reg [3:0] i; // index for iterating through list_data (0-15)
    reg [3:0] j; // index for iterating through unique_values (0-7)
    reg [3:0] k; // index for iterating through list_data during counting (0-15)
    
    // Helper logic for comparisons
    wire is_new;
    assign is_new = (list_data[i] != unique_values[j]);
    
    // Helper logic for finding empty slot
    wire is_empty;
    assign is_empty = (unique_values[j] == 7'h7F); // 0x7F is 127, the sentinel value

    integer m; // general purpose integer for resetting arrays

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            state <= IDLE;
            done <= 1'b0;
            unique_count <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            
            // Reset arrays (set to sentinel 0x7F for unique_values, 0 for frequencies)
            for (m = 0; m < 8; m = m + 1) begin
                unique_values[m] <= 7'h7F;
                frequencies[m] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COLLECT_UNIQUE;
                        i <= 4'd0;
                        j <= 4'd0;
                        unique_count <= 4'd0;
                        // Initialize unique_values array to sentinel
                        for (m = 0; m < 8; m = m + 1) begin
                            unique_values[m] <= 7'h7F;
                            frequencies[m] <= 4'd0; // clear frequencies just in case
                        end
                    end
                end

                COLLECT_UNIQUE: begin
                    if (i < 16 && unique_count < 8) begin
                        // We need to check if list_data[i] is already in unique_values
                        // We use a flag implicit in logic. Since we need to scan unique_values array.
                        // We can check sequentially using 'j' but we need to ensure we finish checking
                        // the whole array or find a match.
                        // Wait, standard verilog unrolled logic is better for hardware, but we need
                        // sequential logic here to save space and handle the iteration.
                        // Let's implement a check inside the cycle or use a small FSM inside this state.
                        
                        // Optimization: We can't easily do a full search in one cycle without unrolling.
                        // But the spec says "parallel comparison logic" and "latency 18".
                        // If we do one comparison per cycle, max unique search is 8 cycles. 
                        // Plus 16 iterations, that's 16*8 = 128 cycles. Too slow.
                        // We need to optimize. We must check all stored uniques in parallel.
                        // But writing that in sequential logic implies using generate or always_comb.
                        // Let's use an always_comb block to find status before the clock edge.
                        
                        // However, Verilog rules dictate we can't call functions inside always_ff easily.
                        // Let's define the logic inside always_ff using intermediate signals computed in logic.
                        
                        // Actually, the prompt asks for a synthesizable module. 
                        // A standard way to do this in one cycle is to check all j values simultaneously.
                        // Since we are constrained by the 'state machine' instructions, we will iterate 'j'.
                        // BUT to meet latency of 18 cycles, we cannot iterate sequentially for 16*8 items.
                        // Therefore, we must assume we check all 8 slots in parallel or iterate 'i' sequentially.
                        // Let's try to iterate 'i' sequentially (16 cycles) and inside each cycle check 'j' (0 to 7) in parallel using an auxiliary loop or flag.
                        
                        // Let's use a flag computed in combinational logic.
                    end
                    
                    // Re-implementing the logic to be robust for synthesis:
                    // We need to find if list_data[i] is in unique_values[0..unique_count-1].
                    // And find the first empty slot (where unique_values[j] == 0x7F).
                end
            endcase
        end
    end

    // Combinational logic helper for COLLECT_UNIQUE state
    // This block determines the next step for the COLLECT_UNIQUE state
    reg found_in_unique;
    reg [3:0] empty_slot_idx;
    reg [3:0] match_idx;
    
    always @(*) begin
        found_in_unique = 1'b0;
        empty_slot_idx = 4'd8;
        match_idx = 4'd8;
        
        // Check against existing unique values
        for (int t = 0; t < 8; t = t + 1) begin
            if (unique_values[t] == list_data[i]) begin
                found_in_unique = 1'b1;
                match_idx = t[3:0];
            end
            // Also find first empty slot for insertion
            if (unique_values[t] == 7'h7F && empty_slot_idx == 4'd8) begin
                empty_slot_idx = t[3:0];
            end
        end
    end

    // Combinational logic helper for COUNT_FREQ state
    // This block calculates the frequency for unique_values[j] by scanning list_data
    reg [3:0] current_freq_count;
    always @(*) begin
        current_freq_count = 4'd0;
        if (unique_values[j] != 7'h7F) begin
            for (int t = 0; t < 16; t = t + 1) begin
                if (list_data[t] == unique_values[j]) begin
                    current_freq_count = current_freq_count + 1;
                end
            end
        end
    end

    // Main FSM Logic corrected to use these helpers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            unique_count <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            for (m = 0; m < 8; m = m + 1) begin
                unique_values[m] <= 7'h7F;
                frequencies[m] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COLLECT_UNIQUE;
                        i <= 4'd0;
                        // Reset unique values for new operation
                        for (m = 0; m < 8; m = m + 1) begin
                            unique_values[m] <= 7'h7F;
                        end
                        unique_count <= 4'd0;
                    end
                end

                COLLECT_UNIQUE: begin
                    if (i < 16 && unique_count < 8) begin
                        // In parallel, we have computed 'found_in_unique' and 'empty_slot_idx'
                        if (!found_in_unique) begin
                            // It is a new value, add it if space available
                            if (empty_slot_idx < 8) begin
                                unique_values[empty_slot_idx] <= list_data[i];
                                unique_count <= unique_count + 1;
                            end
                        end
                        i <= i + 1;
                    end else begin
                        // Finished scanning list or reached max unique count
                        state <= COUNT_FREQ;
                        j <= 4'd0; // Reset j for counting frequencies
                    end
                end

                COUNT_FREQ: begin
                    if (j < unique_count) begin
                        // We have the count from combinational logic 'current_freq_count'
                        frequencies[j] <= current_freq_count;
                        j <= j + 1;
                    end else if (j == unique_count && j < 8) begin
                        // Clear remaining frequency slots if any (strictly speaking 0 is default but good practice)
                        frequencies[j] <= 4'd0;
                        j <= j + 1;
                    end else if (j >= 8) begin
                        state <= IDLE; // Completion
                        done <= 1'b1;
                    end else begin
                        // If unique_count was 0 (empty list case handled by sentinel, but logic continues)
                        // If unique_count is 0, we go to done immediately? 
                        // If unique_count is 0, j is 0, so we skip loop and land here if special handling needed.
                        // Let's handle the transition cleanly:
                        // If j >= unique_count and j >= 8 (or simply j >= 8 to clear rest)
                        state <= IDLE;
                        done <= 1'b1;
                    end
                end
                
                default: state <= IDLE;
            endcase
            
            // Handling the transition logic for COUNT_FREQ more carefully
            if (state == COUNT_FREQ) begin
                if (j < unique_count) begin
                     frequencies[j] <= current_freq_count;
                     j <= j + 1;
                end else begin
                     // Done counting all unique values
                     // Ensure we clear the rest of the frequencies array if we didn't fill it
                     if (j < 8) begin
                         frequencies[j] <= 4'd0;
                         j <= j + 1;
                     end else begin
                         state <= IDLE;
                         done <= 1'b1;
                     end
                end
            end
        end
    end

endmodule

module freq_counter_optimized (
    input clk,
    input rst_n,
    input start,
    input [6:0] list_data [0:15],
    output reg [6:0] unique_values [0:7],
    output reg [3:0] frequencies [0:7],
    output reg [3:0] unique_count,
    output reg done
);

    // State encoding
    localparam IDLE          = 3'b001;
    localparam COLLECT_UNIQUE = 3'b010;
    localparam COUNT_FREQ    = 3'b100;

    reg [2:0] state;
    reg [3:0] i; // iterates 0-15
    reg [3:0] j; // iterates 0-7 (for checking unique)
    
    // Intermediate storage for counting frequencies in parallel
    reg [3:0] freq_counts [0:7]; 

    // Helper signals for combinational logic
    wire found_match;
    wire [3:0] next_empty_slot;
    
    // Check if list_data[i] exists in unique_values
    assign found_match = (list_data[i] == unique_values[0]) ||
                         (list_data[i] == unique_values[1]) ||
                         (list_data[i] == unique_values[2]) ||
                         (list_data[i] == unique_values[3]) ||
                         (list_data[i] == unique_values[4]) ||
                         (list_data[i] == unique_values[5]) ||
                         (list_data[i] == unique_values[6]) ||
                         (list_data[i] == unique_values[7]);

    // Find next empty slot (priority encoder style)
    // We check which slot is 0x7F (sentinel)
    // If we are currently adding, we need to know where to add.
    // We can compute this combinatorially based on the current state of the array.
    assign next_empty_slot = (unique_values[0] == 7'h7F) ? 4'd0 :
                             (unique_values[1] == 7'h7F) ? 4'd1 :
                             (unique_values[2] == 7'h7F) ? 4'd2 :
                             (unique_values[3] == 7'h7F) ? 4'd3 :
                             (unique_values[4] == 7'h7F) ? 4'd4 :
                             (unique_values[5] == 7'h7F) ? 4'd5 :
                             (unique_values[6] == 7'h7F) ? 4'd6 :
                             (unique_values[7] == 7'h7F) ? 4'd7 : 4'd8;

    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            unique_count <= 4'd0;
            i <= 4'd0;
            for (k = 0; k < 8; k = k + 1) begin
                unique_values[k] <= 7'h7F;
                frequencies[k] <= 4'd0;
                freq_counts[k] <= 4'd0; // init internal counter
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COLLECT_UNIQUE;
                        i <= 4'd0;
                        unique_count <= 4'd0;
                        for (k = 0; k < 8; k = k + 1) begin
                            unique_values[k] <= 7'h7F;
                            freq_counts[k] <= 4'd0;
                        end
                    end
                end

                COLLECT_UNIQUE: begin
                    if (i < 16 && unique_count < 8) begin
                        // Check if current list_data[i] is new
                        if (!found_match) begin
                            // Add to unique_values at next empty slot
                            // We need to use the combinational next_empty_slot signal.
                            // However, if we update the array, the next_empty_slot might change.
                            // But since we iterate 'i' one by one, we can write to the slot.
                            // The 'next_empty_slot' is computed from current state.
                            if (next_empty_slot < 8) begin
                                unique_values[next_empty_slot] <= list_data[i];
                                unique_count <= unique_count + 1;
                            end
                        end
                        i <= i + 1;
                    end else begin
                        // Done with list or max unique found
                        // Transition to COUNT_FREQ
                        state <= COUNT_FREQ;
                        // We will perform counting in the next cycle(s). 
                        // To meet 18 cycles, we need to do this fast.
                        // Let's use 2 cycles for counting.
                        // 1. Reset counters.
                        // 2. Accumulate.
                        // But wait, we can do it in one cycle if we want, but we need to iterate list_data.
                        // Actually, let's look at the 18 cycle limit again.
                        // Collect takes 16 cycles. 
                        // We have 2 cycles left (17th and 18th).
                        // We can do counting in 1 cycle if we parallelize the counting logic.
                        
                        // Strategy for COUNT_FREQ state (1 cycle):
                        // Use combinational logic to calculate frequency for all unique_values simultaneously.
                        // Then latch it.
                        
                        state <= DONE_STATE; // We can add a DONE state or just latch done.
                    end
                end

                COUNT_FREQ: begin
                    // This state is now a "latch results" state.
                    // We calculate frequencies combinationally and latch them.
                    // Calculation: 
                    // freq[0] = count of unique_values[0] in list_data
                    // ...
                    // This requires a loop over list_data for each unique value, but unrolled.
                    // Since we have 8 unique values and 16 list items, it's large but valid.
                    
                    // We will implement the counting logic here inline or use an always_comb.
                    // Let's use the logic we defined earlier.
                    
                    for (k = 0; k < 8; k = k + 1) begin
                        if (unique_values[k] != 7'h7F) begin
                            frequencies[k] <= 0; // Reset first (not strictly needed if we use accumulator logic)
                            // Actually, to save space, we will use the internal accumulator approach.
                            // But Verilog in always_ff must be blocking/unblocking carefully.
                            // Let's just do the calculation in a separate always_comb for synthesis.
                        end else begin
                            frequencies[k] <= 4'd0;
                        end
                    end
                    
                    // Since I cannot call an always_comb block from here easily, let's unroll the logic for 8 entries.
                    // This might be verbose but correct.
                    
                    // We need to compute frequency for slot 0:
                    frequencies[0] <= (unique_values[0]==7'h7F) ? 4'd0 : (
                        (list_data[0]==unique_values[0]) + (list_data[1]==unique_values[0]) + 
                        (list_data[2]==unique_values[0]) + (list_data[3]==unique_values[0]) +
                        (list_data[4]==unique_values[0]) + (list_data[5]==unique_values[0]) +
                        (list_data[6]==unique_values[0]) + (list_data[7]==unique_values[0]) +
                        (list_data[8]==unique_values[0]) + (list_data[9]==unique_values[0]) +
                        (list_data[10]==unique_values[0]) + (list_data[11]==unique_values[0]) +
                        (list_data[12]==unique_values[0]) + (list_data[13]==unique_values[0]) +
                        (list_data[14]==unique_values[0]) + (list_data[15]==unique_values[0])
                    );
                    
                    frequencies[1] <= (unique_values[1]==7'h7F) ? 4'd0 : (
                        (list_data[0]==unique_values[1]) + (list_data[1]==unique_values[1]) + 
                        (list_data[2]==unique_values[1]) + (list_data[3]==unique_values[1]) +
                        (list_data[4]==unique_values[1]) + (list_data[5]==unique_values[1]) +
                        (list_data[6]==unique_values[1]) + (list_data[7]==unique_values[1]) +
                        (list_data[8]==unique_values[1]) + (list_data[9]==unique_values[1]) +
                        (list_data[10]==unique_values[1]) + (list_data[11]==unique_values[1]) +
                        (list_data[12]==unique_values[1]) + (list_data[13]==unique_values[1]) +
                        (list_data[14]==unique_values[1]) + (list_data[15]==unique_values[1])
                    );

                    frequencies[2] <= (unique_values[2]==7'h7F) ? 4'd0 : (
                        (list_data[0]==unique_values[2]) + (list_data[1]==unique_values[2]) + 
                        (list_data[2]==unique_values[2]) + (list_data[3]==unique_values[2]) +
                        (list_data[4]==unique_values[2]) + (list_data[5]==unique_values[2]) +
                        (list_data[6]==unique_values[2]) + (list_data[7]==unique_values[2]) +
                        (list_data[8]==unique_values[2]) + (list_data[9]==unique_values[2]) +
                        (list_data[10]==unique_values[2]) + (list_data[11]==unique_values[2]) +
                        (list_data[12]==unique_values[2]) + (list_data[13]==unique_values[2]) +
                        (list_data[14]==unique_values[2]) + (list_data[15]==unique_values[2])
                    );

                    frequencies[3] <= (unique_values[3]==7'h7F) ? 4'd0 : (
                        (list_data[0]==unique_values[3]) + (list_data[1]==unique_values[3]) + 
                        (list_data[2]==unique_values[3]) + (list_data[3]==unique_values[3]) +
                        (list_data[4]==unique_values[3]) + (list_data[5]==unique_values[3]) +
                        (list_data[6]==unique_values[3]) + (list_data[7]==unique_values[3]) +
                        (list_data[8]==unique_values[3]) + (list_data[9]==unique_values[3]) +
                        (list_data[10]==unique_values[3]) + (list_data[11]==unique_values[3]) +
                        (list_data[12]==unique_values[3]) + (list_data[13]==unique_values[3]) +
                        (list_data[14]==unique_values[3]) + (list_data[15]==unique_values[3])
                    );

                    frequencies[4] <= (unique_values[4]==7'h7F) ? 4'd0 : (
                        (list_data[0]==unique_values[4]) + (list_data[1]==unique_values[4]) + 
                        (list_data[2]==unique_values[4]) + (list_data[3]==unique_values[4]) +
                        (list_data[4]==unique_values[4]) + (list_data[5]==unique_values[4]) +
                        (list_data[6]==unique_values[4]) + (list_data[7]==unique_values[4]) +
                        (list_data[8]==unique_values[4]) + (list_data[9]==unique_values[4]) +
                        (list_data[10]==unique_values[4]) + (list_data[11]==unique_values[4]) +
                        (list_data[12]==unique_values[4]) + (list_data[13]==unique_values[4]) +
                        (list_data[14]==unique_values[4]) + (list_data[15]==unique_values[4])
                    );

                    frequencies[5] <= (unique_values[5]==7'h7F) ? 4'd0 : (
                        (list_data[0]==unique_values[5]) + (list_data[1]==unique_values[5]) + 
                        (list_data[2]==unique_values[5]) + (list_data[3]==unique_values[5]) +
                        (list_data[4]==unique_values[5]) + (list_data[5]==unique_values[5]) +
                        (list_data[6]==unique_values[5]) + (list_data[7]==unique_values[5]) +
                        (list_data[8]==unique_values[5]) + (list_data[9]==unique_values[5]) +
                        (list_data[10]==unique_values[5]) + (list_data[11]==unique_values[5]) +
                        (list_data[12]==unique_values[5]) + (list_data[13]==unique_values[5]) +
                        (list_data[14]==unique_values[5]) + (list_data[15]==unique_values[5])
                    );

                    frequencies[6] <= (unique_values[6]==7'h7F) ? 4'd0 : (
                        (list_data[0]==unique_values[6]) + (list_data[1]==unique_values[6]) + 
                        (list_data[2]==unique_values[6]) + (list_data[3]==unique_values[6]) +
                        (list_data[4]==unique_values[6]) + (list_data[5]==unique_values[6]) +
                        (list_data[6]==unique_values[6]) + (list_data[7]==unique_values[6]) +
                        (list_data[8]==unique_values[6]) + (list_data[9]==unique_values[6]) +
                        (list_data[10]==unique_values[6]) + (list_data[11]==unique_values[6]) +
                        (list_data[12]==unique_values[6]) + (list_data[13]==unique_values[6]) +
                        (list_data[14]==unique_values[6]) + (list_data[15]==unique_values[6])
                    );

                    frequencies[7] <= (unique_values[7]==7'h7F) ? 4'd0 : (
                        (list_data[0]==unique_values[7]) + (list_data[1]==unique_values[7]) + 
                        (list_data[2]==unique_values[7]) + (list_data[3]==unique_values[7]) +
                        (list_data[4]==unique_values[7]) + (list_data[5]==unique_values[7]) +
                        (list_data[6]==unique_values[7]) + (list_data[7]==unique_values[7]) +
                        (list_data[8]==unique_values[7]) + (list_data[9]==unique_values[7]) +
                        (list_data[10]==unique_values[7]) + (list_data[11]==unique_values[7]) +
                        (list_data[12]==unique_values[7]) + (list_data[13]==unique_values[7]) +
                        (list_data[14]==unique_values[7]) + (list_data[15]==unique_values[7])
                    );

                    state <= IDLE;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule

module freq_counter_v2 (
    input clk,
    input rst_n,
    input start,
    input [6:0] list_data [0:15],
    output reg [6:0] unique_values [0:7],
    output reg [3:0] frequencies [0:7],
    output reg [3:0] unique_count,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam COLLECT_UNIQUE = 3'b001;
    localparam COUNT_FREQ = 3'b010;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [3:0] i; // Iterates 0-15 for list
    
    // Helper for collecting unique
    wire found_match;
    wire [3:0] next_empty_slot;
    
    // Check if list_data[i] exists in unique_values[0..7] (parallel check)
    assign found_match = (list_data[i] == unique_values[0]) ||
                         (list_data[i] == unique_values[1]) ||
                         (list_data[i] == unique_values[2]) ||
                         (list_data[i] == unique_values[3]) ||
                         (list_data[i] == unique_values[4]) ||
                         (list_data[i] == unique_values[5]) ||
                         (list_data[i] == unique_values[6]) ||
                         (list_data[i] == unique_values[7]);

    // Priority encoder for empty slot
    assign next_empty_slot = (unique_values[0] == 7'h7F) ? 4'd0 :
                             (unique_values[1] == 7'h7F) ? 4'd1 :
                             (unique_values[2] == 7'h7F) ? 4'd2 :
                             (unique_values[3] == 7'h7F) ? 4'd3 :
                             (unique_values[4] == 7'h7F) ? 4'd4 :
                             (unique_values[5] == 7'h7F) ? 4'd5 :
                             (unique_values[6] == 7'h7F) ? 4'd6 :
                             (unique_values[7] == 7'h7F) ? 4'd7 : 4'd8;

    integer k;
    
    // Combinational block for frequency counting (to be used in COUNT_FREQ state)
    reg [3:0] freq_calc [0:7];
    always @(*) begin
        for (k = 0; k < 8; k = k + 1) begin
            if (unique_values[k] != 7'h7F) begin
                freq_calc[k] = 0;
                for (int m = 0; m < 16; m = m + 1) begin
                    if (list_data[m] == unique_values[k]) freq_calc[k] = freq_calc[k] + 1;
                end
            end else begin
                freq_calc[k] = 0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            unique_count <= 4'd0;
            i <= 4'd0;
            for (k = 0; k < 8; k = k + 1) begin
                unique_values[k] <= 7'h7F;
                frequencies[k] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COLLECT_UNIQUE;
                        i <= 4'd0;
                        unique_count <= 4'd0;
                        // Reset unique array
                        for (k = 0; k < 8; k = k + 1) unique_values[k] <= 7'h7F;
                    end
                end

                COLLECT_UNIQUE: begin
                    if (i < 16 && unique_count < 8) begin
                        if (!found_match) begin
                            if (next_empty_slot < 8) begin
                                unique_values[next_empty_slot] <= list_data[i];
                                unique_count <= unique_count + 1;
                            end
                        end
                        i <= i + 1;
                    end else begin
                        state <= COUNT_FREQ;
                    end
                end

                COUNT_FREQ: begin
                    // Use the combinational calculation
                    for (k = 0; k < 8; k = k + 1) begin
                        frequencies[k] <= freq_calc[k];
                    end
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    // Wait for reset or auto-advance to IDLE as per description
                    // "Return to IDLE on next clock or wait for reset."
                    // Usually we return to IDLE to accept new start.
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule