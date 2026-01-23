module find_min_sublist (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_sublists,
    input [2:0] sublist_lengths [0:3],
    input [7:0] all_elements [0:31],
    output reg [2:0] min_index,
    output reg [2:0] min_length,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam FIND_MIN = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [1:0] next_state;
    
    // Iteration counter
    reg [1:0] index;
    reg [1:0] next_index;
    
    // Temporary storage for min comparison
    reg [2:0] temp_min_length;
    reg [2:0] next_min_length;
    reg [2:0] temp_min_index;
    reg [2:0] next_min_index;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 2'b00;
            temp_min_length <= 3'b000;
            temp_min_index <= 3'b000;
        end else begin
            state <= next_state;
            index <= next_index;
            temp_min_length <= next_min_length;
            temp_min_index <= next_min_index;
        end
    end

    // Next State Logic and Output Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_index = index;
        next_min_length = temp_min_length;
        next_min_index = temp_min_index;
        min_index = 3'b0;
        min_length = 3'b0;
        done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FIND_MIN;
                    next_index = 2'b00;
                    // Initialize with first sublist (index 0) if it exists
                    if (num_sublists > 0) begin
                        next_min_length = sublist_lengths[0];
                        next_min_index = 3'b000;
                    end else begin
                        next_min_length = 3'b111; // Max value (invalid)
                        next_min_index = 3'b000;
                    end
                end else begin
                    next_state = IDLE;
                    next_index = 2'b00;
                    next_min_length = 3'b000;
                    next_min_index = 3'b000;
                end
            end

            FIND_MIN: begin
                // We iterate from 1 to num_sublists-1 (since index 0 is initialized)
                if (index < 2'b11 && (index + 1) < num_sublists[1:0]) begin
                    next_index = index + 1'b1;
                    
                    // Compare current index+1 with current min
                    // index in this state represents the index of the sublist we just compared (0-based)
                    // We need to compare sublist at position (index + 1)
                    // Note: In this cycle, we compare sublist_lengths[index + 1] with temp_min_length
                    // Wait, the timing here needs to be careful.
                    // Cycle 1: index=0, compare sublist 1. Cycle 2: index=1, compare sublist 2.
                    // etc.
                    // Actually, let's use index to track the *last compared* index.
                    // If index=0, we have processed sublist 0. Next we process 1.
                    // Wait, initialization happened in IDLE->FIND_MIN transition.
                    // So in FIND_MIN state, if index=0, we should check sublist 1.
                    // If index=1, check sublist 2.
                    // If index=2, check sublist 3.
                    
                    // Correction: The value 'index' stored in register is the index of the sublist *currently being considered*?
                    // Let's refine: 
                    // Transition to FIND_MIN: next_index = 1 (to compare sublist 1). 
                    // But we initialized with sublist 0.
                    // So logic inside FIND_MIN:
                    // If index < num_sublists: compare sublist_lengths[index] with temp_min.
                    // Then increment index.
                    // Let's restart the logic for clarity.
                    
                    // Revised Logic:
                    // 1. IDLE: Prepare. min <= lengths[0]. index <= 1.
                    // 2. FIND_MIN: 
                    //    Compare lengths[index] with min.
                    //    Update min.
                    //    Increment index.
                    //    If index >= num_sublists, next_state = DONE.
                end
            end
            
            DONE: begin
                done = 1'b1;
                min_index = temp_min_index;
                min_length = temp_min_length;
                next_state = IDLE;
            end
        endcase
    end

    // Re-implementing logic cleanly to ensure 6 cycle latency and correctness
    // Latency: 1 (IDLE) + 4 (FIND_MIN) + 1 (DONE) = 6.
    // Max sublists = 4. Iteration steps = 3 (compare sublist 1, 2, 3 against initial 0).
    // So FIND_MIN needs to hold for 4 cycles (or just process the comparisons).
    
    // Cleaned up State Machine Logic:
    always @(*) begin
        next_state = state;
        next_index = index;
        next_min_length = temp_min_length;
        next_min_index = temp_min_index;
        min_index = 3'b0;
        min_length = 3'b0;
        done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FIND_MIN;
                    // Initialize with sublist 0
                    if (num_sublists > 0) begin
                        next_min_length = sublist_lengths[0];
                        next_min_index = 3'b000;
                    end else begin
                        // Should not happen per spec (1-4), but safe default
                        next_min_length = 3'b111;
                        next_min_index = 3'b000;
                    end
                    next_index = 2'b01; // Start checking from sublist 1
                end
            end

            FIND_MIN: begin
                // Check if we have more sublists to compare
                // 'index' is the sublist length index we are CURRENTLY comparing against current min
                // Only compare if index < num_sublists
                // Note: num_sublists is 3 bits, index is 2 bits (enough for 0-3)
                
                if (index < num_sublists[1:0]) begin
                    // Perform comparison in this cycle
                    if (sublist_lengths[index] < temp_min_length) begin
                        next_min_length = sublist_lengths[index];
                        next_min_index = index;
                    end else begin
                        next_min_length = temp_min_length;
                        next_min_index = temp_min_index;
                    end
                    next_index = index + 1'b1;
                    next_state = FIND_MIN;
                end else begin
                    // Done comparing all sublists
                    // Need to go to DONE state next
                    next_state = DONE;
                    next_index = 2'b00; // Not used in DONE
                end
            end

            DONE: begin
                done = 1'b1;
                min_index = temp_min_index;
                min_length = temp_min_length;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 2'b00;
            temp_min_length <= 3'b000;
            temp_min_index <= 3'b000;
        end else begin
            state <= next_state;
            index <= next_index;
            temp_min_length <= next_min_length;
            temp_min_index <= next_min_index;
        end
    end

endmodule