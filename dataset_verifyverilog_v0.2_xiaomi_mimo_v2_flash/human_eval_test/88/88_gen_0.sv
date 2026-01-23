module sort_array(
    input clk,
    input rst_n,
    input start,
    input [2:0] array_length,
    input [7:0] array_in [0:7],
    output reg [7:0] array_out [0:7],
    output reg done
);

    // States definition
    localparam IDLE = 3'b000;
    localparam CHECK_SUM = 3'b001;
    localparam SORT_PASS = 3'b010;
    localparam VERIFY_DONE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] current_state, next_state;
    reg [2:0] pass_count;       // Counts number of passes (up to array_length - 1)
    reg [2:0] index;            // Index for iterating through array during swap check
    reg sort_ascending;         // 1 for ascending, 0 for descending
    reg [7:0] temp_array [0:7]; // Internal storage for sorting
    reg [7:0] temp_val;         // Temporary register for swapping
    reg load_inputs;            // Control signal to load inputs
    reg update_sorting;         // Control signal to perform comparison and swap
    reg inc_pass;               // Control signal to increment pass counter
    reg inc_index;              // Control signal to increment index counter
    reg clear_done;             // Control signal to clear done flag
    reg set_done;               // Control signal to set done flag

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = CHECK_SUM;
            end
            CHECK_SUM: begin
                // If array length is 0 or 1, we are done immediately
                if (array_length <= 3'd1)
                    next_state = DONE;
                else
                    next_state = SORT_PASS;
            end
            SORT_PASS: begin
                // Check if we have iterated through the current pass
                // Pass length decreases: (array_length - 1) - pass_count
                // But we compare index with array_length - 1 - pass_count
                // Actually, in Bubble sort, inner loop goes 0 to (array_length - 2 - pass_count)
                // Let's use a condition: index < array_length - 1 - pass_count
                // Since we need to compare index and index+1, we stop when index reaches upper bound.
                // Current limit = array_length - 1 - pass_count
                // We iterate index from 0 up to limit - 1? 
                // Standard bubble sort: 
                // for (i=0; i < n-1; i++)
                //   for (j=0; j < n-1-i; j++)
                // So pass_count is 'i', index is 'j'.
                // Condition to stay in this state: index < array_length - 1 - pass_count
                if (index < (array_length - 1 - pass_count))
                    next_state = SORT_PASS; // Continue current pass
                else
                    next_state = VERIFY_DONE; // Pass finished
            end
            VERIFY_DONE: begin
                // Check if pass_count has reached array_length - 2 (since pass_count starts at 0)
                // If we have done (n-1) passes, we are done.
                // pass_count has been incremented at end of previous pass.
                // Wait, let's trace: n=3. Passes needed: 2 (indices 0 and 1). 
                // Pass 0 (pass_count=0): goes to index 0->1 (limit=2-0-1=1, index<1, so index 0 processed). 
                // Pass 1 (pass_count=1): goes to index 0->0 (limit=2-1-1=0, index<0 false). 
                // So we stop sorting when pass_count >= array_length - 1.
                if (pass_count >= (array_length - 1))
                    next_state = DONE;
                else
                    next_state = SORT_PASS;
            end
            DONE: begin
                if (start) // Stay in done until start goes low? Or wait for reset? 
                    // Usually done stays high until next start. 
                    // The problem says "high when computation complete".
                    // We will stay in DONE until start goes low, then go to IDLE.
                    next_state = DONE;
                else
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath and Control Signals
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            pass_count <= 3'b0;
            index <= 3'b0;
            sort_ascending <= 1'b0;
            // Reset output array to 0 or x (optional, but good practice to define)
            // We keep it as is or undefined, but let's clear internal temp too
        end else begin
            // Default assignments
            load_inputs = 1'b0;
            update_sorting = 1'b0;
            inc_pass = 1'b0;
            inc_index = 1'b0;
            clear_done = 1'b0;
            set_done = 1'b0;

            case (current_state)
                IDLE: begin
                    // Reset counters and flags
                    pass_count <= 3'b0;
                    index <= 3'b0;
                    if (start) begin
                        load_inputs = 1'b1;
                    end
                end

                CHECK_SUM: begin
                    // Just a logic state, no actions needed here really
                    // We decide sort direction here based on loaded inputs or current state
                    // Since we load in IDLE, we can calc sum here.
                    // Sum = array_in[0] + array_in[array_length-1]
                    // But array_in is an input array. 
                    // We need to capture the direction flag.
                    // Let's do it in IDLE or CHECK_SUM? 
                    // CHECK_SUM state exists to handle 0/1 length cases.
                    // We determine direction based on array_in inputs.
                    // Note: array_in is input, so we can read it directly.
                    // If length 0, array_in[array_length-1] is undefined. Must guard.
                    if (array_length > 0) begin
                        // Calc sum. Logic: 
                        // Even sum -> Descending (sort_ascending = 0)
                        // Odd sum -> Ascending (sort_ascending = 1)
                        // Note: If length 1, element 0 is used twice? "Sum of first and last valid element."
                        // If length 1, last valid = first = index 0.
                        // If length 0, sum is 0 (even) -> Descending, but we go to DONE immediately.
                        
                        if (array_length == 1)
                            sort_ascending <= (array_in[0] + array_in[0])[0]; // Check LSB
                        else
                            sort_ascending <= (array_in[0] + array_in[array_length-1])[0];
                    end
                    // If length <= 1, we transition to DONE in next state logic
                    // If length > 1, we transition to SORT_PASS
                end

                SORT_PASS: begin
                    // Perform comparison and swap on temp_array
                    update_sorting = 1'b1;
                    
                    // Increment index for next cycle
                    // Unless it was the last element of the pass (handled in state transition logic)
                    // But we update index here. If next state is VERIFY_DONE, we reset index for next pass?
                    // Actually, it's cleaner to handle index increment here.
                    // However, we need to know if we are done with this pass to reset index.
                    // Let's do index increment here. Reset in VERIFY_DONE or IDLE.
                    // Wait, standard flow: 
                    // 1. Compare j and j+1.
                    // 2. Increment j.
                    // 3. Check if j < limit.
                    // Since we check condition in state transition, we can increment index here.
                    // BUT, if we are at the end of the pass, next state is VERIFY_DONE. 
                    // We should reset index to 0 when entering VERIFY_DONE or SORT_PASS (first time).
                    // Let's increment index here. 
                    if (index < (array_length - 1 - pass_count))
                        index <= index + 1;
                    else
                        index <= 3'b0; // Reset for next pass
                        
                end

                VERIFY_DONE: begin
                    // Increment pass count
                    // If pass_count reaches limit, next state is DONE
                    pass_count <= pass_count + 1;
                    index <= 3'b0; // Ensure reset for next pass
                end

                DONE: begin
                    done <= 1'b1;
                    // Pass outputs to array_out (combinational logic below handles it usually, 
                    // but here we can latch it or just keep it assigned)
                end
            endcase

            if (set_done) done <= 1'b1;
            if (clear_done) done <= 1'b0;
        end
    end

    // Sorting Datapath Logic (Combinational logic driven by update_sorting)
    // Since temp_array needs to be updated on clock edge, we use an always block sensitive to update_sorting and state?
    // Actually, temp_array is a register. We update it based on inputs.
    // We can use a separate always block or handle it in the main FSM block.
    // Let's handle it in a dedicated logic block for clarity.
    
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Clear temp array (optional)
            for (i = 0; i < 8; i = i + 1) begin
                temp_array[i] <= 8'b0;
            end
        end else begin
            if (load_inputs) begin
                // Copy inputs to temp_array
                for (i = 0; i < 8; i = i + 1) begin
                    // We load all 8 inputs, but only valid indices will be used in sorting logic based on array_length
                    temp_array[i] <= array_in[i];
                end
            end else if (update_sorting && (current_state == SORT_PASS)) begin
                // Compare temp_array[index] and temp_array[index+1]
                // Logic: 
                // Ascending: if (current > next) swap
                // Descending: if (current < next) swap
                // Use temporary value for swap
                
                // Note: Accessing registers inside this block implies they are updated at clock edge.
                // But we need current values for comparison.
                // Since this is synchronous logic, 'temp_array[index]' gives current value.
                
                if (sort_ascending) begin
                    if (temp_array[index] > temp_array[index + 1]) begin
                        // Swap
                        temp_array[index] <= temp_array[index + 1];
                        temp_array[index + 1] <= temp_array[index];
                    end
                end else begin // Descending
                    if (temp_array[index] < temp_array[index + 1]) begin
                        // Swap
                        temp_array[index] <= temp_array[index + 1];
                        temp_array[index + 1] <= temp_array[index];
                    end
                end
            end
        end
    end

    // Output assignment
    // array_out is an array of 8 regs.
    // It should hold the sorted values.
    // When to update array_out? 
    // 1. If array length is 0/1: Update immediately after CHECK_SUM -> DONE.
    // 2. After sorting complete: Update in DONE state or when leaving VERIFY_DONE.
    // Let's make array_out follow temp_array continuously in DONE state, 
    // but hold values otherwise? 
    // Requirements: "Output 'array_out' should contain the sorted array"
    // So when 'done' is high, it must be sorted.
    // We can assign array_out = (current_state == DONE || current_state == IDLE) ? temp_array : array_out;
    // Or simpler: Assign output logic based on state.
    
    always @(*) begin
        if (done) begin
            // Output the sorted array from internal storage
            for (int k = 0; k < 8; k = k + 1) begin
                if (k < array_length)
                    array_out[k] = temp_array[k];
                else
                    array_out[k] = 8'b0; // Zero out unused elements
            end
        end else begin
            // Undefined or preserve? 
            // Let's output zeros or undefined if not done. 
            // For hardware cleanliness, outputting 0 is safe.
            for (int k = 0; k < 8; k = k + 1) begin
                array_out[k] = 8'b0;
            end
        end
    end

endmodule