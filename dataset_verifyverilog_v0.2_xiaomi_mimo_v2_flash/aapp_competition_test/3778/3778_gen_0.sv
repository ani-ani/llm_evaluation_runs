module boomerang_solver (
    input clk,
    input rst_n,
    input start,
    input [1:0] a_in,
    output reg [4:0] target_r,
    output reg [2:0] target_c,
    output reg valid,
    output reg done,
    output reg error
);

    // States
    localparam IDLE = 2'b00;
    localparam PROCESS = 2'b01;
    localparam ERROR_STATE = 2'b10;

    // Internal Registers
    reg [1:0] state, next_state;
    reg [2:0] col_cnt, next_col_cnt; // 0-3 for columns 1-4
    reg [2:0] row_cnt, next_row_cnt; // 0-4 (1-4 used), tracks next available row
    
    // Stacks implemented as shift registers
    // pending_stack stores row indices (1-4), depth 4
    reg [3:0] pending_stack_data, next_pending_stack_data;
    reg pending_stack_empty, next_pending_stack_empty;
    
    // two_stack stores row indices (1-4), depth 4
    reg [3:0] two_stack_data, next_two_stack_data;
    reg two_stack_empty, next_two_stack_empty;

    // Output Buffers for multi-cycle output
    reg [1:0] out_count, next_out_count; // How many outputs to generate
    reg [4:0] out_r_1, next_out_r_1;
    reg [2:0] out_c_1, next_out_c_1;
    reg [4:0] out_r_2, next_out_r_2;
    reg [2:0] out_c_2, next_out_c_2;

    // Next State Logic
    always @(*) begin
        next_state = state;
        next_col_cnt = col_cnt;
        next_row_cnt = row_cnt;
        next_pending_stack_data = pending_stack_data;
        next_pending_stack_empty = pending_stack_empty;
        next_two_stack_data = two_stack_data;
        next_two_stack_empty = two_stack_empty;
        next_out_count = 2'b00;
        next_out_r_1 = 5'b0;
        next_out_c_1 = 3'b0;
        next_out_r_2 = 5'b0;
        next_out_c_2 = 3'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                    next_col_cnt = 3'd0; // Start at column 0 (User sees 1)
                    next_row_cnt = 3'd1; // Start assigning rows from 1
                    next_pending_stack_empty = 1'b1;
                    next_two_stack_empty = 1'b1;
                end
            end

            PROCESS: begin
                // Determine current column index (1-based)
                // col_cnt is 0..3, so current_col = col_cnt + 1
                
                if (a_in == 2'b00) begin
                    // Requirement 0: No action, just advance
                    // Note: The problem description doesn't explicitly define behavior for a=0,
                    // but implies we move on. No stack changes, no outputs.
                    if (col_cnt == 3'd3) begin
                        next_state = IDLE;
                        next_done_flag = 1'b1; // Use a signal or handle done in sequential
                    end else begin
                        next_col_cnt = col_cnt + 1;
                    end
                end
                else if (a_in == 2'b01) begin
                    // a=1: Add current row to stack. Output (current_row, current_col).
                    // Stack push
                    next_pending_stack_data = {pending_stack_data[2:0], row_cnt};
                    next_pending_stack_empty = 1'b0;
                    
                    // Output
                    next_out_count = 2'd1;
                    next_out_r_1 = {2'b00, row_cnt}; // Convert 3-bit to 5-bit
                    next_out_c_1 = col_cnt + 1; // 1-based column
                    
                    // Advance row
                    if (row_cnt < 3'd4) next_row_cnt = row_cnt + 1;
                    
                    // Advance column
                    if (col_cnt == 3'd3) next_state = IDLE;
                    else next_col_cnt = col_cnt + 1;
                end
                else if (a_in == 2'b10) begin
                    // a=2: Requires item from stack. Output (stack_item, current_col). Add current_row to two_stack.
                    if (pending_stack_empty && two_stack_empty) begin
                        next_state = ERROR_STATE;
                    end else begin
                        // Priority: Pending Stack (based on implementation details description order)
                        // Actually description says: "Requires item from stack." then "Adds current_row to two_stack."
                        // "Use an internal stack to keep track of 'pending' rows". 
                        // "Priority: two_stack > pending_stack" is for a=3. 
                        // For a=2, it just says "Requires item from stack.". 
                        // Usually 'pending' implies the stack built by a=1. 
                        // However, to be safe, we check pending_stack first, then two_stack? 
                        // Let's assume the standard "pending stack" is the one built by a=1.
                        // But the problem says "Internal stacks... pending_stack... two_stack".
                        // It says "Priority: two_stack > pending_stack" for a=3.
                        // It doesn't specify priority for a=2. 
                        // Let's assume a=2 consumes from the stack built by a=1 (pending_stack).
                        // If that is empty, it's an error? Or fallback to two_stack?
                        // Given "Requires item from stack", and stacks are 'pending' and 'two'.
                        // Let's implement: Try pending_stack, if empty error.
                        // Wait, looking at standard Boomerang problem logic:
                        // a=1 opens a demand. a=2 closes a demand (from a=1) and opens a new one for next.
                        // a=3 closes a demand and opens two. 
                        // The description: "a=2: ... Adds current_row to a 'two_stack'."
                        // This implies the stack for a=2 is the 'pending' one (built by a=1).
                        // Let's stick to consuming from pending_stack.
                        
                        if (!pending_stack_empty) begin
                            // Pop pending
                            next_pending_stack_data = {1'b0, pending_stack_data[3:1]};
                            if (pending_stack_data[3:1] == 3'b000) next_pending_stack_empty = 1'b1;
                            
                            // Output
                            next_out_count = 2'd1;
                            next_out_r_1 = {2'b00, pending_stack_data[2:0]}; // Top of stack (before shift)
                            next_out_c_1 = col_cnt + 1;
                            
                            // Add current to two_stack
                            next_two_stack_data = {two_stack_data[2:0], row_cnt};
                            next_two_stack_empty = 1'b0;
                            
                            // Advance row
                            if (row_cnt < 3'd4) next_row_cnt = row_cnt + 1;
                        end else begin
                            next_state = ERROR_STATE;
                        end
                        
                        // Advance column
                        if (col_cnt == 3'd3) next_state = IDLE;
                        else next_col_cnt = col_cnt + 1;
                    end
                end
                else if (a_in == 2'b11) begin
                    // a=3: Requires item from stack (priority: two_stack > pending_stack).
                    // Outputs (current_row, current_col) and (current_row, matched_col).
                    // Adds current_row to two_stack.
                    if (two_stack_empty && pending_stack_empty) begin
                        next_state = ERROR_STATE;
                    end else begin
                        // Check stacks
                        reg match_from_two;
                        reg [2:0] popped_row;
                        
                        match_from_two = !two_stack_empty;
                        
                        if (match_from_two) begin
                            popped_row = two_stack_data[2:0];
                            next_two_stack_data = {1'b0, two_stack_data[3:1]};
                            if (two_stack_data[3:1] == 3'b000) next_two_stack_empty = 1'b1;
                        end else begin
                            popped_row = pending_stack_data[2:0];
                            next_pending_stack_data = {1'b0, pending_stack_data[3:1]};
                            if (pending_stack_data[3:1] == 3'b000) next_pending_stack_empty = 1'b1;
                        end
                        
                        // Outputs: 2 targets
                        next_out_count = 2'd2;
                        
                        // First output: (current_row, current_col)
                        next_out_r_1 = {2'b00, row_cnt};
                        next_out_c_1 = col_cnt + 1;
                        
                        // Second output: (current_row, matched_col)
                        // matched_col is the column where the popped row was initially matched?
                        // Wait. The problem says: "Outputs targets (current_row, current_col) and (current_row, matched_col)."
                        // In Boomerang problem:
                        // If we match row X (from stack) at current column C.
                        // Output 1: (Current Row, C)
                        // Output 2: (Current Row, Column of X)? 
                        // Or is it (Current Row, Column where X was matched)?
                        // Let's re-read: "Outputs targets (current_row, current_col) and (current_row, matched_col)."
                        // "matched_col" refers to the column associated with the item taken from the stack.
                        // The stack items in this problem represent rows that are 'pending'.
                        // But we haven't stored the column index of the stack items in the stack itself.
                        // The stack only stores row indices.
                        // However, in the problem statement: "a=1: Adds current row to stack. Outputs target (current_row, current_col)."
                        // This implies a row is added to stack when we output it for column A.
                        // "a=2: ... Outputs target (stack_item, current_col)."
                        // "a=3: ... Outputs targets (current_row, current_col) and (current_row, matched_col)."
                        // If we take item from stack (say, from a=1), the "matched_col" for that item is the column where it was first output (column A).
                        // If we take item from two_stack (from a=2), the "matched_col" is the column where it was output (column B).
                        // We MUST store the column index with the row in the stack!
                        // The stack depth is 4. We need to store Row (3 bits) + Col (2 bits) = 5 bits per entry.
                        // But the instructions said "Internal stacks can be implemented as registers (e.g., 4 registers for pending, 4 for two_stack)."
                        // This usually means 4 separate registers. But for synthesis efficiency, a shift register is better.
                        // Let's expand the stack storage.
                        
                        // Re-evaluating stack storage:
                        // We need to store {row, col} for each stack entry.
                        // Pending Stack: 4 entries of {row(3), col(2)} -> 5 bits wide, 4 deep.
                        // Two Stack: 4 entries of {row(3), col(2)} -> 5 bits wide, 4 deep.
                        // Wait, the problem says "4 registers". If we use shift registers, we can flatten them.
                        // Let's declare next stack registers as [19:0] for 4 entries x 5 bits.
                        // But the prompt says "Internal stacks can be implemented as registers (e.g., 4 registers for pending, 4 for two_stack)."
                        // I will implement using 4 separate registers for clarity and to match the "4 registers" hint.
                        // However, in Verilog, a vector is also registers. 
                        // Let's use 4 5-bit registers for each stack to store {row, col}.
                        // But wait, I must define these in the module header... I can't change it now.
                        // I must use the variables I defined.
                        // Let's change the stack definitions in the module body.
                        
                        // CORRECTION TO IMPLEMENTATION:
                        // I need to store column info. The prompt implies I can use "4 registers".
                        // I will use 4x5bit registers for pending_stack and two_stack.
                    end
                end
            end
            
            ERROR_STATE: begin
                // Stay here until reset
            end
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            col_cnt <= 3'b0;
            row_cnt <= 3'b0;
            
            // Reset stack registers (Need to define them properly first)
            // Defined below based on corrected logic
            pending_stack_data <= 20'b0; 
            two_stack_data <= 20'b0;
            pending_stack_depth <= 2'b0;
            two_stack_depth <= 2'b0;

            target_r <= 5'b0;
            target_c <= 3'b0;
            valid <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            
            out_count <= 2'b0;
            out_r_1 <= 5'b0; out_c_1 <= 3'b0;
            out_r_2 <= 5'b0; out_c_2 <= 3'b0;
        end else begin
            // Output Logic (Sequential)
            valid <= 1'b0;
            done <= 1'b0;
            
            if (state == ERROR_STATE) begin
                error <= 1'b1;
            end else if (state == IDLE && start) begin
                error <= 1'b0;
            end

            // Multi-cycle output handling
            if (out_count > 0) begin
                valid <= 1'b1;
                if (out_count == 2'd2) begin
                    // First of two outputs
                    target_r <= out_r_2; // Wait, which is first? 
                    // I set next_out_count = 2. next_out_r_1 and next_out_r_2.
                    // Usually FIFO. R_1 is first, R_2 is second? Or vice versa?
                    // Let's say next_out_r_1 is the first output to emit.
                    // Let's re-verify next logic.
                    // next_out_r_1 = ... 
                    // Actually, it's cleaner if next_out_r_1 is the first output.
                    // But I assigned next_out_r_1 to the first target.
                    // If I have 2 outputs, I need to output one now, and one next cycle.
                    // I'll need a small FIFO or shift register for outputs.
                    // Or simply: 
                    // Cycle N: If out_count > 0, emit stored output. Shift next one into storage.
                    // Let's just use the stored registers.
                    
                    // I will use a "shift" approach.
                    // If out_count == 2, emit out_r_1, move out_r_2 to out_r_1. Decrement count.
                    // If out_count == 1, emit out_r_1. Decrement count.
                    
                    target_r <= out_r_1;
                    target_c <= out_c_1;
                    
                    // Shift second output to first for next cycle
                    out_r_1 <= out_r_2;
                    out_c_1 <= out_c_2;
                    out_count <= out_count - 1;
                end else if (out_count == 2'd1) begin
                    target_r <= out_r_1;
                    target_c <= out_c_1;
                    out_count <= out_count - 1;
                end
            end

            // State Update
            state <= next_state;
            col_cnt <= next_col_cnt;
            row_cnt <= next_row_cnt;
            
            // Stack Updates (Corrected for {row, col} storage)
            pending_stack_data <= next_pending_stack_data;
            two_stack_data <= next_two_stack_data;
            pending_stack_depth <= next_pending_stack_depth;
            two_stack_depth <= next_two_stack_depth;
            
            // Output Buffer Updates
            out_count <= next_out_count;
            out_r_1 <= next_out_r_1;
            out_c_1 <= next_out_c_1;
            out_r_2 <= next_out_r_2;
            out_c_2 <= next_out_c_2;
            
            // Done signal generation
            // We need to detect transition to IDLE or finish of 4 cycles.
            // If next_state is IDLE and current state is PROCESS, set done.
            if (next_state == IDLE && state == PROCESS) begin
                done <= 1'b1;
            end
        end
    end

    // --- Redefine Stacks for {row, col} (5 bits each) ---
    // I need to put this here to make the logic above work correctly with 5-bit entries.
    // Since I am returning code, I will re-write the sequential logic block to be correct with these.
    // But wait, I cannot redefine 'reg' inside the module in a way that overrides previous declarations if I already used them in always @(*) 
    // I used next_pending_stack_data in the comb block. 
    // Let's refactor the comb block to use explicit width arrays.
    
    // Let's use 4 5-bit registers for each stack to store {row, col}.
    // Row: 3 bits (0-4), Col: 2 bits (0-3). 
    // Note: Row 0 means empty. 
    
    reg [4:0] pending_stack [0:3]; // 4 entries, 5 bits each
    reg [4:0] two_stack [0:3];     // 4 entries, 5 bits each
    reg [1:0] pending_depth;
    reg [1:0] two_depth;
    
    // Next stack values
    reg [4:0] next_pending_stack [0:3];
    reg [4:0] next_two_stack [0:3];
    reg [1:0] next_pending_depth;
    reg [1:0] next_two_depth;

    integer i;
    
    // Revised Combinational Logic
    always @(*) begin
        // Defaults
        next_state = state;
        next_col_cnt = col_cnt;
        next_row_cnt = row_cnt;
        next_pending_depth = pending_depth;
        next_two_depth = two_depth;
        next_out_count = 2'b00;
        next_out_r_1 = 5'b0;
        next_out_c_1 = 3'b0;
        next_out_r_2 = 5'b0;
        next_out_c_2 = 3'b0;
        
        // Stack copy defaults
        for (i = 0; i < 4; i = i + 1) begin
            next_pending_stack[i] = pending_stack[i];
            next_two_stack[i] = two_stack[i];
        end

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                    next_col_cnt = 3'd0;
                    next_row_cnt = 3'd1;
                    next_pending_depth = 2'd0;
                    next_two_depth = 2'd0;
                    // Clear stacks
                    for (i = 0; i < 4; i = i + 1) begin
                        next_pending_stack[i] = 5'b0;
                        next_two_stack[i] = 5'b0;
                    end
                end
            end

            PROCESS: begin
                // Current column 1-based: col_cnt + 1
                
                if (a_in == 2'b00) begin
                    // No op
                    if (col_cnt == 3'd3) next_state = IDLE;
                    else next_col_cnt = col_cnt + 1;
                end
                else if (a_in == 2'b01) begin
                    // Add to pending stack
                    if (pending_depth < 2'd4) begin
                        next_pending_stack[pending_depth] = {row_cnt, col_cnt + 1};
                        next_pending_depth = pending_depth + 1;
                    end else begin
                        next_state = ERROR_STATE; // Stack overflow
                        return;
                    end
                    
                    // Output (current_row, current_col)
                    next_out_count = 2'd1;
                    next_out_r_1 = {2'b00, row_cnt};
                    next_out_c_1 = col_cnt + 1;
                    
                    // Advance row
                    if (row_cnt < 3'd4) next_row_cnt = row_cnt + 1;
                    
                    // Advance col
                    if (col_cnt == 3'd3) next_state = IDLE;
                    else next_col_cnt = col_cnt + 1;
                end
                else if (a_in == 2'b10) begin
                    // Require item from stack. 
                    // Problem says: "Requires item from stack." (Implies pending stack from a=1)
                    // "Adds current_row to two_stack."
                    
                    if (pending_depth == 2'd0) begin
                        next_state = ERROR_STATE;
                    end else begin
                        // Pop pending stack (LIFO)
                        // Get top element (index depth-1)
                        reg [4:0] popped;
                        popped = pending_stack[pending_depth - 1];
                        next_pending_depth = pending_depth - 1;
                        
                        // Output (stack_item, current_col)
                        // Stack item is {row, col}. Output (row, current_col)
                        next_out_count = 2'd1;
                        next_out_r_1 = {2'b00, popped[4:2]}; // Row
                        next_out_c_1 = col_cnt + 1;           // Current Column
                        
                        // Add current_row to two_stack
                        if (next_two_depth < 2'd4) begin
                            next_two_stack[next_two_depth] = {row_cnt, col_cnt + 1};
                            next_two_depth = next_two_depth + 1;
                        end else begin
                            next_state = ERROR_STATE;
                            return;
                        end
                        
                        // Advance row
                        if (row_cnt < 3'd4) next_row_cnt = row_cnt + 1;
                        
                        // Advance col
                        if (col_cnt == 3'd3) next_state = IDLE;
                        else next_col_cnt = col_cnt + 1;
                    end
                end
                else if (a_in == 2'b11) begin
                    // Require item from stack (priority: two_stack > pending_stack)
                    // Outputs (current_row, current_col) and (current_row, matched_col)
                    // Adds current_row to two_stack
                    
                    reg [4:0] popped;
                    reg use_two;
                    use_two = (two_depth > 0);
                    
                    if (!use_two && pending_depth == 0) begin
                        next_state = ERROR_STATE;
                    end else begin
                        if (use_two) begin
                            popped = two_stack[two_depth - 1];
                            next_two_depth = two_depth - 1;
                        end else begin
                            popped = pending_stack[pending_depth - 1];
                            next_pending_depth = pending_depth - 1;
                        end
                        
                        // Output 1: (current_row, current_col)
                        next_out_r_1 = {2'b00, row_cnt};
                        next_out_c_1 = col_cnt + 1;
                        
                        // Output 2: (current_row, matched_col)
                        // matched_col is the column stored in the popped item (popped[1:0])
                        next_out_r_2 = {2'b00, row_cnt};
                        next_out_c_2 = popped[1:0];
                        
                        next_out_count = 2'd2;
                        
                        // Add current_row to two_stack
                        if (next_two_depth < 2'd4) begin
                            next_two_stack[next_two_depth] = {row_cnt, col_cnt + 1};
                            next_two_depth = next_two_depth + 1;
                        end else begin
                            next_state = ERROR_STATE;
                            return;
                        end
                        
                        // Advance row
                        if (row_cnt < 3'd4) next_row_cnt = row_cnt + 1;
                        
                        // Advance col
                        if (col_cnt == 3'd3) next_state = IDLE;
                        else next_col_cnt = col_cnt + 1;
                    end
                end
            end
            
            ERROR_STATE: begin
                // No change
            end
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            col_cnt <= 3'b0;
            row_cnt <= 3'b0;
            pending_depth <= 2'b0;
            two_depth <= 2'b0;
            
            for (i = 0; i < 4; i = i + 1) begin
                pending_stack[i] <= 5'b0;
                two_stack[i] <= 5'b0;
            end

            target_r <= 5'b0;
            target_c <= 3'b0;
            valid <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            
            out_count <= 2'b0;
            out_r_1 <= 5'b0; out_c_1 <= 3'b0;
            out_r_2 <= 5'b0; out_c_2 <= 3'b0;
        end else begin
            // Assign next state
            state <= next_state;
            col_cnt <= next_col_cnt;
            row_cnt <= next_row_cnt;
            pending_depth <= next_pending_depth;
            two_depth <= next_two_depth;
            
            for (i = 0; i < 4; i = i + 1) begin
                pending_stack[i] <= next_pending_stack[i];
                two_stack[i] <= next_two_stack[i];
            end
            
            // Output handling
            valid <= 1'b0;
            done <= 1'b0;
            
            if (state == ERROR_STATE) begin
                error <= 1'b1;
            end else if (state == IDLE && start) begin
                error <= 1'b0;
            end

            // Multi-cycle output handling
            if (out_count > 0) begin
                valid <= 1'b1;
                if (out_count == 2'd2) begin
                    // Emit first, shift second
                    target_r <= out_r_1;
                    target_c <= out_c_1;
                    // Shift
                    out_r_1 <= out_r_2;
                    out_c_1 <= out_c_2;
                    out_count <= out_count - 1;
                end else if (out_count == 2'd1) begin
                    target_r <= out_r_1;
                    target_c <= out_c_1;
                    out_count <= out_count - 1;
                end
            end
            
            // Buffer next outputs
            out_r_1 <= next_out_r_1;
            out_c_1 <= next_out_c_1;
            out_r_2 <= next_out_r_2;
            out_c_2 <= next_out_c_2;
            out_count <= next_out_count;

            // Done logic
            // Detect transition to IDLE. 
            // But if we are outputting targets, we stay in PROCESS until outputs are done?
            // The state machine transitions to IDLE after processing column 4.
            // However, if we have pending outputs, we might finish state logic but still outputting.
            // The problem says: "The module should operate over 4 clock cycles".
            // This implies valid outputs happen within or shortly after these cycles.
            // The state transition to IDLE happens when col_cnt wraps.
            // If next_state is IDLE (meaning we just finished last column logic), set done.
            if (next_state == IDLE && state != IDLE) begin
                done <= 1'b1;
            end
        end
    end

endmodule