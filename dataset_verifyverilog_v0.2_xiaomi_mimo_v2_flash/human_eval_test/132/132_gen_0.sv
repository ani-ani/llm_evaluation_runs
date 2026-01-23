module bracket_nested_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0][7:0] char_array,
    output reg result,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Registers for state and data processing
    reg [1:0] state, next_state;
    reg [3:0] index, next_index;          // Counter for 8 characters (0-7)
    reg [3:0] depth, next_depth;          // Stack depth counter
    reg next_nested_flag;                 // Flag to track nesting
    reg next_valid_flag;                  // Flag to track validity
    reg next_result, next_done;           // Output registers

    // State Transition and Data Path Logic (Synchronous)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            depth <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
            // Flags are cleared on reset implicitly by the next_state logic,
            // but explicit assignment ensures clean state
        end else begin
            state <= next_state;
            index <= next_index;
            depth <= next_depth;
            result <= next_result;
            done <= next_done;
        end
    end

    // Combinational Logic for Next State and Outputs
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_index = index;
        next_depth = depth;
        next_result = result;
        next_done = done;
        
        // Internal flags defaults (preserving values unless updated)
        // We use a separate combinational block logic to calculate flags based on current char
        // but since the specification requires tracking state across cycles, we handle updates here.
        // To be safe and clear: we define intermediate variables based on current cycle inputs
        
        // Default outputs for specific states
        next_done = (state == DONE) ? 1'b1 : 1'b0;
        
        case (state)
            IDLE: begin
                next_done = 1'b0;
                next_result = 1'b0;
                if (start) begin
                    next_state = PROCESSING;
                    next_index = 4'd0;
                    next_depth = 4'd0;
                    // We need to maintain flags across PROCESSING state.
                    // In standard FSM style without sub-registers for flags, we must use localvars or infer logic.
                    // However, logic below handles state-specific updates.
                    // We must initialize flags here to 0 for the start of computation
                    // But they are not registers in this block. 
                    // Let's use explicit flags in the always block.
                end else begin
                    next_state = IDLE;
                end
            end

            PROCESSING: begin
                next_done = 1'b0;
                // We need to check the current character
                // char_array is indexed [7:0][7:0]. Index 0 is usually the first element.
                // Let's assume standard indexing: char_array[index] accesses the char.
                // However, in Verilog unpacked arrays, it depends. Assuming packed or unpacked logic.
                // The spec says [7:0][7:0]. Usually this implies unpacked array of 8 vectors.
                // Let's access char_array[index].
                
                // Logic to handle flags persistently:
                // We need to carry over the flags from the previous cycle.
                // Since we are in the combinational block referencing current state values,
                // we need to calculate the NEXT flag values.
                
                // To track flags properly in a single always block FSM:
                // We treat flags as implicit state variables. 
                // Let's define temporary variables for flag updates based on the character being processed.
                
                // Since this block is combinational and runs whenever inputs/regs change,
                // we must calculate the new depth and flags based on the CURRENT index's char.
                // Wait, in PROCESSING state, we are about to consume index 'index'.
                // So we look at char_array[index].
                
                // Handling persistent flags (nested_flag, valid_flag):
                // These aren't explicit outputs but affect the final result.
                // We can track them by adding them to the state register or 
                // simply updating 'next_result' logic or use local variables if we were in a loop.
                // In hardware FSM, we need registers for them.
                // Let's add implicit logic for nested_flag and valid_flag.
                // We will use the `next_depth` and current `depth` for logic.
                
                // However, 'nested_flag' and 'valid_flag' are specific requirements.
                // Let's assume we need registers for them. But the prompt asked for specific output registers.
                // The prompt implies tracking them as part of the internal state.
                // Let's add two more registers to the state: nested_flag_reg, valid_flag_reg.
                
                // Check the current character
                // Using current index to select char
                // Note: char_array is 8x8 bit. indexing [index] gives 8 bits.
                
                // Logic update:
                // If index < 8:
                //   Process char_array[index]
                //   Update depth, flags
                //   Increment index
                // Else:
                //   Move to DONE
                
                if (index < 8) begin
                    // Process character
                    if (char_array[index] == 8'h5B) begin // '['
                        // Increment depth
                        next_depth = depth + 1;
                        // If depth was 0, new depth is 1. No nesting yet.
                        // If depth was > 0, we are nesting inside something.
                        // Wait, definition: "if depth > 0 then set nested_flag".
                        // This check usually refers to the state BEFORE incrementing or after?
                        // "If '[': increment depth, if depth > 0 then set nested_flag"
                        // Usually implies we are inside a pair. 
                        // Example "[[]]":
                        // 1. '[': depth 0->1. Check depth before? 0. No nest.
                        // 2. '[': depth 1->2. Check depth before? 1. Yes nest.
                        // So we check CURRENT depth (before increment) > 0.
                        
                        // For nested_flag:
                        // It is an OR operation over cycles. So we need to preserve it.
                        // In this block, we can't easily reference 'nested_flag_reg' unless we add it to state.
                        // Let's add it to the state register implicitly.
                        // We will assume the existence of `nested_flag` and `valid_flag` registers.
                        // To make this work within the prompt's `reg` list limitation (implied),
                        // I will define them as separate registers.
                        
                        // Let's refine the FSM to handle this cleanly.
                    end else if (char_array[index] == 8'h5D) begin // ']'
                        // Decrement depth
                        next_depth = depth - 1;
                        // Check if depth goes negative (underflow)
                        // If depth was 0, we go to -1 (or 1111 in 4-bit). This is invalid.
                    end
                    // Other characters? Spec says only brackets present.
                    
                    // Increment index
                    next_index = index + 1;
                    next_state = PROCESSING;
                end else begin
                    // End of array
                    next_state = DONE;
                    next_index = index;
                    next_depth = depth;
                end
            end

            DONE: begin
                // Stay here until reset or new start
                // Outputs are already set by default or specific logic
                next_state = IDLE; // Auto-return to IDLE or wait? Usually wait for reset or start.
                // Prompt says "done high when complete". Usually stays high.
                // Let's stay in DONE until reset or new start.
                if (start) begin
                    // Restart if start is asserted again
                    next_state = PROCESSING;
                    next_index = 4'd0;
                    next_depth = 4'd0;
                    next_done = 1'b0;
                    // Reset result until computed again
                    next_result = 1'b0;
                end else begin
                    next_state = DONE;
                    next_done = 1'b1;
                end
            end
            
            default: begin
                next_state = IDLE;
                next_done = 1'b0;
                next_index = 4'd0;
                next_depth = 4'd0;
            end
        endcase
    end

    // Separating the flag tracking logic to handle the persistence requirement cleanly.
    // The previous block calculated next_state and next_depth. 
    // We need to calculate `next_result` (which encodes valid_flag AND nested_flag AND depth==0).
    // However, the prompt asks to track specific flags. 
    // Let's refine the ALWAYS block to include these flags as part of the state transition logic.
    
    // Re-writing the combinational block to be more explicit about flag tracking.
    // We will use local variables to calculate the next values for flags, then assign them to next_ regs.
    // But wait, `nested_flag` and `valid_flag` are not in the port list, so they must be internal.
    // Let's declare them as internal regs to hold the state.
    
    reg nested_flag_int, valid_flag_int;
    // We need to make them sequential to hold state across cycles, or calculate combinationally.
    // Given the requirement "Track whether any nesting occurred" (stateful), 
    // we need registers for them.
    
    // Let's assume we added these to the sequential block.
    // But the user prompt doesn't specify them as outputs. 
    // However, the "Behavioral Description" section says "Track...".
    // In the sequential block, we will update them.
    
    // To make this robust, I will create a single always block that handles everything.
    
    // Redefining internal state registers needed:
    reg [2:0] state_reg;
    reg [3:0] idx_reg;
    reg [3:0] depth_reg;
    reg nested_reg;
    reg valid_reg;
    
    // Local parameters for state
    localparam S_IDLE = 3'b000;
    localparam S_PROC = 3'b001;
    localparam S_DONE = 3'b010;

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= S_IDLE;
            idx_reg <= 4'd0;
            depth_reg <= 4'd0;
            nested_reg <= 1'b0;
            valid_reg <= 1'b1; // Assume valid until proven invalid
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state_reg)
                S_IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        state_reg <= S_PROC;
                        idx_reg <= 4'd0;
                        depth_reg <= 4'd0;
                        nested_reg <= 1'b0;
                        valid_reg <= 1'b1;
                    end
                end

                S_PROC: begin
                    if (idx_reg < 8) begin
                        // Process char
                        if (char_array[idx_reg] == 8'h5B) begin // '['
                            // Check nesting condition BEFORE incrementing depth
                            // "If '[': increment depth, if depth > 0 then set nested_flag"
                            // This implies: if (current_depth > 0) nested_flag = 1;
                            if (depth_reg > 0)
                                nested_reg <= 1'b1;
                            
                            depth_reg <= depth_reg + 1;
                        end else if (char_array[idx_reg] == 8'h5D) begin // ']'
                            // Decrement depth
                            if (depth_reg == 0) begin
                                // Would go negative, invalid
                                valid_reg <= 1'b0;
                                depth_reg <= 4'hF; // Underflow to avoid wrap issues in logic, though not strictly needed if valid is low
                            end else begin
                                depth_reg <= depth_reg - 1;
                            end
                        end
                        idx_reg <= idx_reg + 1;
                    end else begin
                        // Finished processing array
                        state_reg <= S_DONE;
                        
                        // Evaluate Result
                        // Result = valid_flag AND nested_flag AND (depth == 0)
                        if (valid_reg && nested_reg && (depth_reg == 0)) begin
                            result <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                        done <= 1'b1;
                    end
                end

                S_DONE: begin
                    // Wait in done state
                    // If start is asserted again, restart
                    if (start) begin
                        state_reg <= S_PROC;
                        idx_reg <= 4'd0;
                        depth_reg <= 4'd0;
                        nested_reg <= 1'b0;
                        valid_reg <= 1'b1;
                        done <= 1'b0;
                        result <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule