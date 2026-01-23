module tuple_union_sort (
    input clk,
    input rst_n,
    input start,
    input [7:0] tuple1 [0:7],
    input [7:0] tuple2 [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam MERGE = 3'b001;
    localparam SORT_PASS = 3'b010;
    localparam SORT_CHECK = 3'b011;
    localparam PACK = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    
    // Temporary storage for merged elements (16 slots max)
    reg [7:0] temp_array [0:15];
    reg [4:0] temp_count; // Can go up to 16
    
    // Indices for various loops
    reg [3:0] i; // General purpose index (max 15)
    reg [3:0] j; // General purpose index (max 15)
    reg [3:0] k; // General purpose index (max 7)
    
    // Flag to check if array is sorted
    reg sorted;
    
    // Temporary variable for bubble sort swap
    reg [7:0] swap_temp;
    
    // Flag to indicate if value is duplicate
    reg is_duplicate;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            temp_count <= 5'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            sorted <= 1'b0;
            is_duplicate <= 1'b0;
            // Reset result array
            for (int r = 0; r < 8; r++) begin
                result[r] <= 8'hFF;
            end
            // Reset temp array
            for (int t = 0; t < 16; t++) begin
                temp_array[t] <= 8'h00;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= MERGE;
                        i <= 4'd0; // Index for tuple1
                        j <= 4'd0; // Index for tuple2 (0 means not started checking)
                        temp_count <= 5'd0;
                    end
                end

                MERGE: begin
                    // Strategy: Iterate through tuple1 and tuple2 sequentially.
                    // For each element, check if it already exists in temp_array.
                    // If not, add it.
                    
                    if (i < 8) begin
                        // Processing tuple1
                        if (j == 0) begin
                            // Start checking duplicates for tuple1[i]
                            is_duplicate <= 1'b0;
                            j <= 1; // Start loop at index 0 of temp_array
                            // If temp_count is 0, we don't need to check
                            if (temp_count == 0) begin
                                temp_array[0] <= tuple1[i];
                                temp_count <= temp_count + 1;
                                i <= i + 1;
                                j <= 0;
                            end
                        end else begin
                            // Checking loop for duplicates
                            if (j < temp_count) begin
                                if (temp_array[j] == tuple1[i]) begin
                                    is_duplicate <= 1'b1;
                                end
                                j <= j + 1;
                            end else begin
                                // Loop finished
                                if (!is_duplicate) begin
                                    // Add to temp if not duplicate (and space permits)
                                    if (temp_count < 16) begin
                                        temp_array[temp_count] <= tuple1[i];
                                        temp_count <= temp_count + 1;
                                    end
                                end
                                i <= i + 1;
                                j <= 0;
                                is_duplicate <= 1'b0;
                            end
                        end
                    end else if (i >= 8 && i < 16) begin
                        // Processing tuple2 (index i-8)
                        // Logic same as above, but accessing tuple2
                        if (j == 0) begin
                            is_duplicate <= 1'b0;
                            j <= 1;
                            if (temp_count == 0) begin
                                temp_array[0] <= tuple2[i-8];
                                temp_count <= temp_count + 1;
                                i <= i + 1;
                                j <= 0;
                            end
                        end else begin
                            if (j < temp_count) begin
                                if (temp_array[j] == tuple2[i-8]) begin
                                    is_duplicate <= 1'b1;
                                end
                                j <= j + 1;
                            end else begin
                                if (!is_duplicate) begin
                                    if (temp_count < 16) begin
                                        temp_array[temp_count] <= tuple2[i-8];
                                        temp_count <= temp_count + 1;
                                    end
                                end
                                i <= i + 1;
                                j <= 0;
                                is_duplicate <= 1'b0;
                            end
                        end
                    end else begin
                        // Finished MERGE
                        state <= SORT_PASS;
                        i <= 1; // Start bubble sort from index 1
                        j <= 0; // Use j for inner loop
                        sorted <= 1'b0;
                    end
                end

                SORT_PASS: begin
                    // Perform one pass of bubble sort
                    if (i < temp_count) begin
                        if (j < (temp_count - i)) begin
                            // Compare temp_array[j] and temp_array[j+1]
                            if (temp_array[j] > temp_array[j+1]) begin
                                swap_temp <= temp_array[j];
                                temp_array[j] <= temp_array[j+1];
                                temp_array[j+1] <= swap_temp; // Note: logic delay here is handled by sequential update in clocked block? No, this is blocking assignment in combinational logic or controlled sequence. 
                                // We need to be careful. In a clocked block, use non-blocking for storage updates.
                                // But we need to swap. We can use the registered swap_temp.
                                // However, temp_array[j] is updated immediately if we use blocking, but it's reg in always block.
                                // Let's use intermediate swap logic.
                                // Actually, standard swap in FSM:
                                // temp_array[j] <= temp_array[j+1];
                                // temp_array[j+1] <= temp_array[j];
                                // This works in non-blocking if we don't need the old value of temp_array[j+1] later in the same cycle.
                                // But we need to read it. 
                                // Correct way for 1-cycle swap in FSM:
                                temp_array[j] <= temp_array[j+1];
                                temp_array[j+1] <= temp_array[j]; 
                                // This creates a race if we read immediately, but since it's sequential logic, the updates happen at the end of the cycle.
                                // However, we are inside the always block. 
                                // Let's stick to a safe swap using a temp register.
                                // Correction: The line above `swap_temp <= temp_array[j]` captures the value.
                                // The next lines update the array.
                                // Since we are in a clocked block, values update at the end of the cycle.
                                // We need to perform the swap in one cycle or multiple.
                                // Given the size, one cycle swap is fine.
                                // Just use the captured swap_temp.
                                temp_array[j] <= temp_array[j+1];
                                temp_array[j+1] <= swap_temp;
                            end
                            j <= j + 1;
                        end else begin
                            // Finished this pass
                            state <= SORT_CHECK;
                            i <= 1; // Reset i for SORT_CHECK
                            j <= 0;
                        end
                    end else begin
                        // Should not reach here if logic is correct, but fallback
                        state <= SORT_CHECK;
                        i <= 1;
                    end
                end

                SORT_CHECK: begin
                    // Check if sorted
                    if (i < temp_count) begin
                        if (temp_array[i-1] > temp_array[i]) begin
                            sorted <= 1'b0;
                            i <= temp_count; // Force exit loop
                            state <= SORT_PASS; // Needs another pass
                            i <= 1; // Reset i for next pass
                            j <= 0;
                        end else begin
                            i <= i + 1;
                        end
                    end else begin
                        // Loop finished, check flag
                        if (sorted) begin // Actually, we need to update sorted dynamically or check if we found any inversion.
                            // My logic above sets sorted implicitly. If we finish loop without finding inversion, it is sorted.
                            // But I have a 'sorted' register. 
                            // Let's restart 'sorted' to 1 at start of check.
                            // Revising logic:
                            // At start of CHECK, set sorted = 1. If we find inversion, set to 0 and go to PASS.
                            // If we finish loop and sorted is still 1, we are done sorting.
                            // Let's implement this logic in the previous state transitions or here.
                            // Let's handle it here by checking the flag I set at the start of SORT_PASS.
                            // Actually, simpler: if we didn't jump back to PASS, we are done.
                            // If I am here, and I didn't find inversion in the loop, I go to PACK.
                            // But wait, the loop needs to run. 
                            // Logic correction for SORT_CHECK:
                            // We need to iterate i from 0 to temp_count-2.
                            // If we find an inversion, go to SORT_PASS.
                            // If we finish loop, go to PACK.
                            // So I need a flag 'inverted' or just logic.
                            // Let's use i to iterate. 
                             if (i == 1) sorted <= 1'b1; // First cycle of check
                            
                            if (i < temp_count) begin
                                if (temp_array[i-1] > temp_array[i]) begin
                                    sorted <= 1'b0;
                                    state <= SORT_PASS;
                                    i <= 1;
                                    j <= 0;
                                end else begin
                                    if (i == temp_count - 1) begin
                                        // End of array, no inversion found
                                        state <= PACK;
                                        k <= 0; // Index for result array
                                        i <= 0; // Index for temp_array
                                    end else begin
                                        i <= i + 1;
                                    end
                                end
                            end else begin
                                // Should not happen if temp_count <= 1
                                state <= PACK;
                                k <= 0;
                                i <= 0;
                            end
                        end
                    end
                    // Revising the SORT_CHECK block implementation for clarity and robustness:
                    // It needs to be a separate logic block essentially. 
                    // To save states, let's assume the logic above is correct but merge the conditionals.
                    // Let's rewrite the SORT_CHECK block content carefully:
                    /* 
                       We enter here. We need to scan the array. 
                       If we find a[i] > a[i+1], set inversion_found = 1, go to SORT_PASS.
                       If we reach end, go to PACK.
                       Since I already wrote the transition logic above, I will stick to it but ensure 'i' is handled correctly.
                       The previous code block logic was getting complex. Let's simplify the FSM transition in this block.
                    */
                    // Re-write of SORT_CHECK:
                    // If (i == 0) start scan.
                    // If (temp_array[i] > temp_array[i+1]) -> SORT_PASS (i reset).
                    // Else increment i. If i == temp_count-2 -> PACK.
                    // (Note: temp_count is number of elements. Indices 0 to count-1).
                    // The code above does: if (i < temp_count) { if (temp_array[i-1] > temp_array[i]) ... }
                    // This implies i starts at 1. 
                    // Let's just assume the previous logic sets 'sorted' or transitions correctly. 
                    // For the sake of generating working code, I will ensure the transitions are precise.
                    // In SORT_CHECK, we iterate. 
                end

                PACK: begin
                    // Copy temp_array to result, fill rest with 0xFF
                    if (i < temp_count && k < 8) begin
                        result[k] <= temp_array[i];
                        i <= i + 1;
                        k <= k + 1;
                    end else if (k < 8) begin
                        // Fill remaining with 0xFF
                        result[k] <= 8'hFF;
                        k <= k + 1;
                    end else begin
                        state <= DONE;
                        done <= 1'b1;
                    end
                end

                DONE: begin
                    // Wait for reset or new start (implied by start signal handling in IDLE)
                    // If we want to automatically return to IDLE when done, we can do it here or rely on start going low.
                    // Usually, done stays high until reset or new start.
                    // But to be safe, let's return to IDLE if start goes low.
                    // Or just stay in DONE until reset. The requirement says "High when computation is complete".
                    // It doesn't specify self-clearing. We'll wait for reset.
                    // However, to allow back-to-back operations, we should check start.
                    if (!start) begin
                         state <= IDLE;
                         done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
    
    // Correction for SORT_CHECK and SORT_PASS logic
    // The code skeleton above handles the main flow but might be buggy on the sorting details.
    // Sorting logic needs to be robust.
    // Specifically, SORT_PASS performs ONE pass. 
    // SORT_CHECK checks if we need another pass.
    
    // Let's refine the implementation inside the always block for MERGE, SORT_PASS, SORT_CHECK to be error-free.
    // Since I cannot edit the previous lines, I will override/assume the user appends the corrections or relies on the logic.
    // Actually, I can output the full code block. I will rewrite the always block cleanly to ensure correctness.

endmodule

// Improved module implementation to ensure correctness
module tuple_union_sort (
    input clk,
    input rst_n,
    input start,
    input [7:0] tuple1 [0:7],
    input [7:0] tuple2 [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    localparam IDLE = 3'b000;
    localparam MERGE = 3'b001;
    localparam SORT_PASS = 3'b010;
    localparam SORT_CHECK = 3'b011;
    localparam PACK = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [7:0] temp_array [0:15];
    reg [4:0] temp_count;
    reg [3:0] idx_in, idx_check, idx_pack;
    reg is_dup;
    reg swap_needed;
    reg [7:0] temp_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            temp_count <= 5'd0;
            idx_in <= 4'd0;
            idx_check <= 4'd0;
            idx_pack <= 4'd0;
            is_dup <= 1'b0;
            for (int k = 0; k < 8; k++) result[k] <= 8'hFF;
            for (int k = 0; k < 16; k++) temp_array[k] <= 8'h00;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= MERGE;
                        idx_in <= 4'd0; // 0-7 for tuple1, 8-15 for tuple2
                        temp_count <= 5'd0;
                        is_dup <= 1'b0;
                        idx_check <= 4'd0; // Used for checking duplicates in MERGE
                    end
                end

                MERGE: begin
                    if (idx_in < 16) begin
                        // Determine current value
                        reg [7:0] current_val;
                        current_val = (idx_in < 8) ? tuple1[idx_in] : tuple2[idx_in - 8];
                        
                        // If temp_count is 0, just add
                        if (temp_count == 0) begin
                            temp_array[0] <= current_val;
                            temp_count <= 1;
                            idx_in <= idx_in + 1;
                        end else begin
                            // Check for duplicate or equality
                            if (idx_check < temp_count) begin
                                if (temp_array[idx_check] == current_val) begin
                                    is_dup <= 1'b1;
                                end
                                idx_check <= idx_check + 1;
                            end else begin
                                // Finished checking
                                if (!is_dup) begin
                                    if (temp_count < 16) begin
                                        temp_array[temp_count] <= current_val;
                                        temp_count <= temp_count + 1;
                                    end
                                end
                                idx_in <= idx_in + 1;
                                idx_check <= 4'd0;
                                is_dup <= 1'b0;
                            end
                        end
                    end else begin
                        state <= SORT_PASS;
                        idx_check <= 4'd0; // Will be used for bubble sort inner loop
                    end
                end

                SORT_PASS: begin
                    // Perform one pass of bubble sort
                    // Swap adjacent elements if out of order
                    // Inner loop: j from 0 to temp_count - 2
                    if (idx_check < temp_count - 1) begin
                        if (temp_array[idx_check] > temp_array[idx_check + 1]) begin
                            // Swap
                            temp_array[idx_check] <= temp_array[idx_check + 1];
                            temp_array[idx_check + 1] <= temp_array[idx_check];
                        end
                        idx_check <= idx_check + 1;
                    end else begin
                        // Pass complete
                        state <= SORT_CHECK;
                        idx_check <= 4'd1; // Start checking from index 1
                        swap_needed <= 1'b0; // Assume sorted until proven otherwise
                    end
                end

                SORT_CHECK: begin
                    // Check if any adjacent elements are out of order
                    if (idx_check < temp_count) begin
                        if (temp_array[idx_check - 1] > temp_array[idx_check]) begin
                            swap_needed <= 1'b1;
                            // Optimization: we can break loop early, but state transitions need care.
                            // Let's finish the scan to be simple, or just transition immediately.
                            // Immediate transition is better for latency.
                            state <= SORT_PASS;
                            idx_check <= 4'd0;
                        end else begin
                            idx_check <= idx_check + 1;
                        end
                    end else begin
                        // End of array reached
                        if (swap_needed) begin
                            // If we found an inversion during the scan (and didn't transition early)
                            // But we transitioned early above. So if we reach here, no inversions found.
                            state <= PACK;
                            idx_pack <= 4'd0;
                            idx_check <= 4'd0; // Use idx_check as index into temp_array
                        end else begin
                            // No inversions found
                            state <= PACK;
                            idx_pack <= 4'd0;
                            idx_check <= 4'd0;
                        end
                    end
                end

                PACK: begin
                    // Copy to result
                    if (idx_check < temp_count && idx_pack < 8) begin
                        result[idx_pack] <= temp_array[idx_check];
                        idx_check <= idx_check + 1;
                        idx_pack <= idx_pack + 1;
                    end else if (idx_pack < 8) begin
                        result[idx_pack] <= 8'hFF;
                        idx_pack <= idx_pack + 1;
                    end else begin
                        state <= DONE;
                        done <= 1'b1;
                    end
                end

                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end
endmodule