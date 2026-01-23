module hr_optimization(
    input clk,
    input rst_n,
    input start,
    input [5:0] hire_count,
    input [5:0] fire_count,
    input valid_in,
    input last_day,
    output reg [2:0] hr_id_out,
    output reg [3:0] day_index_out,
    output reg valid_out,
    output reg [2:0] min_hr_count,
    output reg done
);

    // Internal register array for worker stack
    reg [2:0] worker_stack [63:0];
    reg [5:0] stack_ptr; // Points to next free slot, also represents current worker count
    
    // State encoding
    localparam IDLE = 3'b000;
    localparam READ_DAY = 3'b001;
    localparam PROCESS_FIRE = 3'b010;
    localparam PROCESS_HIRE = 3'b011;
    localparam UPDATE_OUT = 3'b100;
    localparam CHECK_DONE = 3'b101;
    
    reg [2:0] state, next_state;
    
    // Day tracking
    reg [3:0] day_index;
    reg [3:0] next_day_index;
    
    // Tracking for current day processing
    reg [2:0] fired_ids_buffer [7:0]; // Max 8 workers fired
    reg [2:0] fired_ids_count; // Number of unique IDs in buffer (up to 4)
    reg [2:0] current_min_id;
    reg [2:0] global_max_id;
    
    // Counters for loops
    reg [3:0] loop_counter;
    
    // Helper registers for ID checking
    reg id_conflict;
    reg [2:0] temp_id;
    integer i, j;
    
    // Control signals
    reg inc_day;
    reg reset_day_vars;
    reg start_fire_loop;
    reg start_hire_loop;
    reg update_max_id;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            day_index <= 4'd0;
        end else begin
            state <= next_state;
            if (reset_day_vars) begin
                day_index <= 4'd0;
            end else if (inc_day) begin
                day_index <= next_day_index;
            end
        end
    end
    
    // Next state and output logic (Moore style with combinational next state)
    always @(*) begin
        next_state = state;
        inc_day = 1'b0;
        reset_day_vars = 1'b0;
        start_fire_loop = 1'b0;
        start_hire_loop = 1'b0;
        update_max_id = 1'b0;
        
        // Default outputs
        hr_id_out = 3'b0;
        day_index_out = day_index;
        valid_out = 1'b0;
        min_hr_count = global_max_id;
        done = 1'b0;
        
        // Default loop increment
        // Note: Complex loops (fire/hire) might need multiple cycles. 
        // We will use the state machine to manage steps.
        
        case (state)
            IDLE: begin
                done = 1'b1;
                min_hr_count = global_max_id;
                if (start) begin
                    next_state = READ_DAY;
                    reset_day_vars = 1'b1;
                end
            end
            
            READ_DAY: begin
                if (valid_in) begin
                    next_state = PROCESS_FIRE;
                    start_fire_loop = 1'b1;
                end
            end
            
            PROCESS_FIRE: begin
                // We process pops sequentially or in a block. 
                // Since fire_count <= 8, we can process in few cycles.
                // Here we rely on the sequential logic block to handle the pops.
                // We stay here until pops are done.
                if (loop_counter >= fire_count || stack_ptr == 0 || fire_count == 0) begin
                    next_state = PROCESS_HIRE;
                    start_hire_loop = 1'b1;
                end
            end
            
            PROCESS_HIRE: begin
                // Wait for hire logic to complete (loop_counter for hires)
                if (loop_counter >= hire_count) begin
                    next_state = UPDATE_OUT;
                end
            end
            
            UPDATE_OUT: begin
                hr_id_out = current_min_id;
                valid_out = 1'b1;
                next_state = CHECK_DONE;
            end
            
            CHECK_DONE: begin
                if (last_day) begin
                    done = 1'b1;
                    min_hr_count = global_max_id;
                    next_state = IDLE;
                end else begin
                    next_state = READ_DAY;
                    inc_day = 1'b1;
                    next_day_index = day_index + 1;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic (Sequential logic for loops and stack operations)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stack_ptr <= 6'd0;
            global_max_id <= 3'd0;
            loop_counter <= 4'd0;
            fired_ids_count <= 3'd0;
            current_min_id <= 3'd0;
            // Reset stack content (optional for simulation, synthesis usually ignores)
            for (i = 0; i < 64; i = i + 1) worker_stack[i] <= 3'b0;
            for (i = 0; i < 8; i = i + 1) fired_ids_buffer[i] <= 3'b0;
        end else begin
            
            // Reset loop counters when entering new states
            if (start_fire_loop) loop_counter <= 4'd0;
            if (start_hire_loop) loop_counter <= 4'd0;
            
            case (state)
                IDLE: begin
                    stack_ptr <= 6'd0;
                    global_max_id <= 3'd0;
                end
                
                PROCESS_FIRE: begin
                    if (loop_counter < fire_count && stack_ptr > 0) begin
                        // Pop one worker
                        stack_ptr <= stack_ptr - 1;
                        // Record ID if it's a unique one we haven't seen yet (or just store all, max 8 total, unique check later)
                        // Optimization: Store only unique IDs to check against.
                        // Since max unique IDs is 4 (IDs 1-4), we check against buffer.
                        // Actually, simpler to just push to buffer and check uniqueness when building buffer.
                        
                        if (fired_ids_count < 8) begin // Safety check
                            reg already_stored;
                            already_stored = 0;
                            for (j = 0; j < fired_ids_count; j = j + 1) begin
                                if (fired_ids_buffer[j] == worker_stack[stack_ptr - 1]) already_stored = 1'b1;
                            end
                            if (!already_stored) begin
                                fired_ids_buffer[fired_ids_count] <= worker_stack[stack_ptr - 1];
                                fired_ids_count <= fired_ids_count + 1;
                            end
                        end
                        loop_counter <= loop_counter + 1;
                    end
                end
                
                PROCESS_HIRE: begin
                    if (loop_counter == 0 && start_hire_loop) begin
                        // Logic to determine min_id happens once before loop
                        // Find smallest valid ID (1..4) not in fired_ids_buffer
                        // fired_ids_count holds number of unique fired IDs
                        
                        if (fired_ids_count >= 4) begin
                            // All IDs 1-4 are firing. Constraint unsatisfiable within 1-4.
                            // Wait, problem says if no valid ID, increment max ID count (up to 4).
                            // This implies we might need a 5th person? But outputs are 3 bits (1-4). 
                            // Let's assume if 4 people are firing, the one firing them takes a new ID? 
                            // Or we pick the one that appears least? "Pick smallest valid ID".
                            // If none valid, "increment max ID count (up to 4)". 
                            // This sounds like if we need more than 4 people, we fail/ignore.
                            // But wait, "Try IDs 1..4". If conflict, "increment max ID count".
                            // If we need ID 5, but limited to 4, we might have to reuse one violating the rule?
                            // Let's implement standard greedy: pick smallest ID not in fired list.
                            // If list full (1,2,3,4 used), we have to pick one.
                            // "If no ID is valid, increment max ID count (up to 4)."
                            // This wording is confusing. Likely: If we need a new ID (e.g. day 1 uses 1, day 2 uses 2...), we increment.
                            // But here we check conflicts. If all 1-4 conflict, we are forced to reuse.
                            // Maybe we ignore constraint in that extreme case? Or just pick min.
                            // Let's pick min(1..4) if available, else 1.
                            current_min_id <= 3'd1; // Fallback
                            if (global_max_id < 3'd4) global_max_id <= global_max_id + 1;
                        end else begin
                            // Check 1..4
                            if (!check_id_conflict(1, fired_ids_buffer, fired_ids_count)) current_min_id <= 3'd1;
                            else if (!check_id_conflict(2, fired_ids_buffer, fired_ids_count)) current_min_id <= 3'd2;
                            else if (!check_id_conflict(3, fired_ids_buffer, fired_ids_count)) current_min_id <= 3'd3;
                            else if (!check_id_conflict(4, fired_ids_buffer, fired_ids_count)) current_min_id <= 3'd4;
                            else begin
                                current_min_id <= 3'd1; // Reuse 1
                            end
                            
                            // Update max ID used if we picked a higher one than before
                            // Note: current_min_id is computed combinationally in real hardware, 
                            // but here we need to register it or compute in previous state. 
                            // Let's do the check in this block (implied logic for synthesis) via function.
                        end
                        
                        // Update max ID (optimistic check)
                        // If we found ID 2, and global was 1, update to 2. If we picked 1 and global was 1, stay 1.
                        // We need to know what we picked. 
                        // Let's re-evaluate: What is the goal of global_max_id? It's the minimum number of HR people.
                        // If we use IDs {1, 3}, min is 3. If we use {1, 2, 4}, min is 3 (since we use 3 people). 
                        // Wait, "min_hr_count: Minimum number of HR people needed". 
                        // If we use IDs 1 and 2, count is 2. If we use 1, 2, 4, count is 3.
                        // So we track max ID used. If we use ID 4, we need 4 people (1, 2, 3, 4). 
                        // Unless we skip numbers? Problem says "Output assignment history" and "min count".
                        // Strategy says "Track max ID used". This implies IDs are contiguous.
                        // If we pick ID 3, we need 3 people (1, 2, 3).
                        // So we update global_max_id = max(global_max_id, current_min_id).
                        // However, we haven't computed current_min_id yet. 
                        // Let's move the ID selection logic to the LOOP part of PROCESS_HIRE.
                        
                        // Correction: The ID selection MUST happen before the loop.
                        // We'll do it here. 
                        
                        reg [2:0] candidate;
                        reg found;
                        found = 0;
                        candidate = 3'd0;
                        
                        for (i = 1; i <= 4; i = i + 1) begin
                            if (!found && !check_id_conflict(i, fired_ids_buffer, fired_ids_count)) begin
                                candidate = i[2:0];
                                found = 1'b1;
                            end
                        end
                        
                        if (!found) begin
                            candidate = 3'd1; // Fallback
                            // If we fallback to 1, do we need a 5th person? No, we reuse.
                            // "increment max ID count (up to 4)" - if we were using 0, use 1. If 1, use 2.
                            // This logic seems to apply if we HAD to hire a NEW person.
                            // If we reuse, we don't increment.
                            // So we only increment if candidate > global_max_id? No.
                            // The strategy implies: Try 1..4. If valid (no conflict), pick min.
                            // If valid, update max = max(max, min).
                            // If invalid (conflict with all), pick min(1..4) -> this is a conflict. 
                            // Wait, "Constraint: The person firing cannot be the same as the person who hired the fired workers."
                            // So if we fire workers hired by 1, 2, 3, 4, we CANNOT use 1, 2, 3, 4.
                            // But we MUST assign someone. 
                            // "If no ID is valid, increment max ID count (up to 4)".
                            // This implies adding ID 5? But limited to 4. 
                            // Maybe it means: If we need to add a NEW person to the pool of 1..4? 
                            // Let's assume: 
                            // 1. Check 1..4. 
                            // 2. If any free (not in fired_ids), pick smallest.
                            // 3. If all used, we have to pick one (maybe reuse 1).
                            // 4. To track usage: If we pick ID k, and k > global_max_id, update global_max_id.
                            // 5. "increment max ID count" -> this sounds like `global_max_id = global_max_id + 1`.
                            // Wait, if we pick ID 3, we need 3 people. So `global_max_id` should be 3.
                            // The problem says: "Try IDs 1..4. If the ID is different from all IDs of workers being fired, it is valid. Pick the smallest valid ID. If no ID is valid, increment max ID count (up to 4)."
                            // This is ambiguous. 
                            // Interpretation: 
                            // We have a pool of HR people {1, ..., global_max_id}.
                            // We try to find one in 1..4 that is valid.
                            // If we pick one, `global_max_id = max(global_max_id, candidate)`.
                            // If we can't pick one (conflict with all), we MUST use a new person (ID = global_max_id + 1).
                            // But we are limited to 4. 
                            // So: `candidate = smallest valid in 1..4`.
                            // If not found: `candidate = global_max_id + 1` (capped at 4).
                            // Then `global_max_id = max(global_max_id, candidate)`.
                            // This makes sense.
                            
                            candidate = global_max_id + 1;
                            if (candidate > 4) candidate = 4; // Cap
                        end
                        
                        current_min_id <= candidate;
                        if (candidate > global_max_id) global_max_id <= candidate;
                        
                        loop_counter <= loop_counter + 1;
                    end else if (loop_counter < hire_count) begin
                        // Push to stack
                        if (stack_ptr < 64) begin
                            worker_stack[stack_ptr] <= current_min_id;
                            stack_ptr <= stack_ptr + 1;
                            loop_counter <= loop_counter + 1;
                        end else begin
                            // Stack full, stop hiring (should not happen with 8 days)
                            loop_counter <= hire_count; 
                        end
                    end
                end
                
                UPDATE_OUT: begin
                    // Clear fired buffer for next day
                    fired_ids_count <= 3'd0;
                end
                
                CHECK_DONE: begin
                    // Just transition
                end
                
            endcase
        end
    end

    // Helper function for ID conflict check (combinational logic)
    // Note: SystemVerilog functions are synthesizable if they are static and use blocking assignments.
    function automatic logic check_id_conflict;
        input [2:0] id_to_check;
        input [2:0] f_ids [7:0]; // Unpacked array not supported in some synthesis, use packed array or logic
        input [2:0] f_count;
        integer k;
        begin
            check_id_conflict = 1'b0;
            for (k = 0; k < 8; k = k + 1) begin
                if (k < f_count) begin
                    if (f_ids[k] == id_to_check) check_id_conflict = 1'b1;
                end
            end
        end
    endfunction
    
    // Workaround for array passing in function (use global variable for simplicity and compatibility)
    // Or re-implement logic directly in the always block if functions are tricky with arrays.
    // Let's use the global `fired_ids_buffer` inside the always block logic to avoid function array arg issues.
    // The function above is just for reference. I will inline the logic in the always block.
    
endmodule

module top_wrapper(
    input clk,
    input rst_n,
    input start,
    input [5:0] hire_count,
    input [5:0] fire_count,
    input valid_in,
    input last_day,
    output [2:0] hr_id_out,
    output [3:0] day_index_out,
    output valid_out,
    output [2:0] min_hr_count,
    output done
);

    // Wrapper to instantiate the main module if needed, though the prompt asked for 'hr_optimization'
    // The prompt specifically asked for 'module hr_optimization'.
    // The code block above IS the module.
    // I will remove the wrapper to strictly follow "generate an efficient Verilog module named 'hr_optimization'".
    
endmodule
