module max_points_game (
    input clk,
    input rst_n,
    input start,
    input [15:0] data_in,
    input valid_in,
    input done_in,
    output reg [31:0] result,
    output reg done,
    output reg ready
);

    // Parameters
    parameter MAX_ELEMENTS = 16;
    parameter LOG2_MAX_ELEMENTS = 4;
    parameter BUFFER_SIZE = 16; // Fixed size buffer
    
    // State encoding
    localparam IDLE = 3'b001;
    localparam LOAD = 3'b010;
    localparam PROCESS = 3'b100;
    localparam DONE = 3'b1000;
    // Note: We will use PROCESS to handle both main algorithm and remaining calculation
    // to save states. Sub-states within PROCESS will handle the flow.
    
    reg [2:0] current_state;
    reg [2:0] next_state;
    
    // Data buffer (values only)
    reg [7:0] buffer [0:BUFFER_SIZE-1];
    reg [LOG2_MAX_ELEMENTS-1:0] write_ptr;
    reg [LOG2_MAX_ELEMENTS-1:0] element_count; // Actual number of elements
    
    // Processing variables
    reg signed [7:0] stack [0:BUFFER_SIZE-1]; // Stack elements, -1 indicates empty
    reg [LOG2_MAX_ELEMENTS-1:0] sp; // Stack pointer (points to next free slot)
    reg [LOG2_MAX_ELEMENTS-1:0] proc_idx; // Index for iterating through buffer
    reg signed [31:0] current_score;
    reg signed [31:0] score_acc; // Accumulator for adding points
    
    // Temporary variables for combinational logic
    integer i;
    reg signed [7:0] top_val;
    reg signed [7:0] second_top_val;
    reg signed [7:0] curr_val;
    reg signed [31:0] add_val;
    reg signed [31:0] temp_score;
    
    // Remaining calculation state machine
    reg [LOG2_MAX_ELEMENTS-1:0] rem_idx;
    reg signed [7:0] left_val;
    reg signed [7:0] right_val;
    
    // Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // State Transition and Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            ready <= 1'b1;
            done <= 1'b0;
            result <= 32'h0;
            write_ptr <= 4'b0;
            element_count <= 4'b0;
            sp <= 4'b0;
            proc_idx <= 4'b0;
            current_score <= 32'h0;
            score_acc <= 32'h0;
            rem_idx <= 4'b0;
            
            // Reset stack
            for (i = 0; i < BUFFER_SIZE; i = i + 1) begin
                stack[i] <= 8'sd0;
            end
            // Reset buffer (optional but good practice)
            for (i = 0; i < BUFFER_SIZE; i = i + 1) begin
                buffer[i] <= 8'h0;
            end
            
        end else begin
            case (current_state)
                IDLE: begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    result <= 32'h0;
                    write_ptr <= 4'b0;
                    element_count <= 4'b0;
                    sp <= 4'b0;
                    proc_idx <= 4'b0;
                    current_score <= 32'h0;
                    score_acc <= 32'h0;
                    rem_idx <= 4'b0;
                    
                    // Clear stack marker
                    for (i = 0; i < BUFFER_SIZE; i = i + 1) stack[i] <= -8'sd1;
                    
                    if (start) begin
                        next_state <= LOAD;
                        ready <= 1'b0; // Not ready for inputs until start is processed
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD: begin
                    // Buffer loaded with values (index is ignored for logic, only used to verify input sequence if needed)
                    // Data_in[7:0] is value, data_in[15:8] is index
                    if (valid_in && write_ptr < MAX_ELEMENTS) begin
                        buffer[write_ptr] <= data_in[7:0];
                        write_ptr <= write_ptr + 1;
                        // We just load until done_in is high
                    end
                    
                    if (done_in) begin
                        // Calculate actual count (index of last valid input + 1)
                        // Assuming input indices are 0, 1, 2... or we just use write_ptr
                        // The problem says "index in upper byte", implies sequential inputs 0..N-1.
                        // We'll use write_ptr as count.
                        element_count <= write_ptr + (valid_in ? 1'b1 : 1'b0);
                        proc_idx <= 4'b0;
                        sp <= 4'b0;
                        current_score <= 32'h0;
                        
                        // Pre-load first element if exists
                        if ((write_ptr > 0) || valid_in) begin
                            // If we just loaded one or more
                             if (write_ptr == 0 && valid_in) buffer[0] <= data_in[7:0];
                             
                            // Start stack processing logic immediately in next cycle
                            // Initialize stack with first element
                            stack[0] <= (write_ptr > 0 || valid_in) ? ((write_ptr == 0 && valid_in) ? data_in[7:0] : buffer[0]) : 8'sd0;
                            sp <= 4'b1;
                            proc_idx <= 4'b1; // Start from second element
                            
                            // If only 1 element, skip to done (score 0)
                            if ((write_ptr == 0 && valid_in && element_count == 1) || (write_ptr == 1 && !valid_in)) begin
                                // Actually if only 1 element in buffer... wait, need to handle count logic better.
                                // Let's just check count in PROCESS state.
                            end
                        end else begin
                            // Empty array
                            result <= 32'h0;
                            done <= 1'b1;
                            next_state <= DONE;
                            // Wait for start to go low
                            if (!start) next_state <= IDLE;
                            else next_state <= DONE;
                        end
                        
                        next_state <= PROCESS;
                        ready <= 1'b1; // Ready for next transaction (standard practice: ready goes high after done_in)
                    end else begin
                        next_state <= LOAD;
                    end
                end
                
                PROCESS: begin
                    // State machine for processing inside PROCESS state
                    // We use proc_idx to track sub-states effectively
                    // Sub-state 0: Main loop
                    // Sub-state 1: Remaining calculation
                    
                    // Since we need sequential logic for stack updates, we define sub-states implicitly
                    // using proc_idx range or separate flags. Let's use proc_idx.
                    // 0..15: Processing buffer elements (Main Algorithm)
                    // 16..31: Processing remaining stack (Remaining Calc)
                    // We need to handle the transition between these.
                    
                    if (proc_idx < element_count) begin
                        // Main Algorithm Phase (Stack simulation)
                        // Logic: While stack size > 1 AND top <= min(current, second_top)
                        
                        // Fetch current value
                        curr_val <= buffer[proc_idx];
                        
                        // Check stack condition
                        if (sp >= 2) begin
                            top_val <= stack[sp-1];
                            second_top_val <= stack[sp-2];
                            
                            // Evaluate condition: top <= min(current, second_top)
                            // Note: -1 is empty, but we only check if sp >= 2 (valid elements)
                            // We need combinational logic for the loop, but here we do 1 iteration per cycle
                            // Check: top <= (curr < second_top ? curr : second_top)
                            
                            if (stack[sp-1] <= (buffer[proc_idx] < stack[sp-2] ? buffer[proc_idx] : stack[sp-2])) begin
                                // Add points: min(current, second_top)
                                // But wait, the algorithm says add min(current, second_top)?
                                // NO, it says: "Add min(current, second_top) to score"
                                // Actually, typical logic is: while stack top <= min(curr, second_top) pop top and add min(curr, second_top)?
                                // Wait, standard "Stick removal" or similar problems usually:
                                // If Top <= min(Curr, Second), then Top is smaller or equal.
                                // We pop Top. The points gained are min(Top, neighbor) OR min(Curr, Second)?
                                // Let's re-read: "While stack size > 1 AND top <= min(current, second_top): Add min(current, second_top) to score"
                                // This is unusual. Usually points are related to the element being removed.
                                // However, following instructions strictly: Add min(current, second_top).
                                
                                // Calculate min(current, second_top)
                                add_val <= (buffer[proc_idx] < stack[sp-2]) ? buffer[proc_idx] : stack[sp-2];
                                
                                current_score <= current_score + ((buffer[proc_idx] < stack[sp-2]) ? buffer[proc_idx] : stack[sp-2]);
                                
                                // Pop stack
                                sp <= sp - 1;
                                
                                // Do not increment proc_idx, stay on same element to check condition again
                                // But we need to wait for next cycle.
                                // Since we can't do loop in 1 cycle without complex logic, we repeat same proc_idx.
                                // Wait, 'always' block is triggered every cycle. 
                                // To repeat, we must NOT increment proc_idx.
                                // But 'always' block is sequential. We update 'sp' and 'current_score'.
                                // Next cycle, the IF condition (sp >= 2) re-evaluates with new sp.
                                // So we must keep proc_idx same.
                                // BUT, how to express "If we popped, don't move to next element?"
                                // We can use a flag or simply not increment proc_idx in this branch.
                                // However, we are inside 'always'. The update for proc_idx happens at the end or here.
                                // If we don't specify proc_idx <= proc_idx, it stays.
                                // Wait, Verilog blocking vs non-blocking.
                                // We must ensure we don't skip the "Push current" step.
                                // The condition says "WHILE". 
                                // If we popped, we repeat logic for SAME proc_idx element.
                                
                                // To handle the loop properly, we need a way to know "I popped, so next cycle re-evaluate stack vs current element"
                                // We can't easily do a full while loop in one cycle.
                                // We do 1 operation per cycle.
                                // Logic:
                                // If (sp >= 2 && condition) -> Pop, add points, stay on same proc_idx.
                                // Else -> Push current, increment proc_idx.
                                
                                // We need to distinguish between "Condition Met" and "Condition Not Met".
                                // If condition met, we pop. We must stay.
                                // If condition not met, we push. We move next.
                                
                            end else begin
                                // Condition failed, push current
                                stack[sp] <= buffer[proc_idx];
                                sp <= sp + 1;
                                proc_idx <= proc_idx + 1;
                            end
                        end else begin
                            // Stack size < 2, cannot pop, push current
                            stack[sp] <= buffer[proc_idx];
                            sp <= sp + 1;
                            proc_idx <= proc_idx + 1;
                        end
                    end else if (proc_idx == element_count && element_count > 0) begin
                        // Transition to Remaining Calculation Phase
                        // Initialize for remaining calc
                        rem_idx <= 1; // Start from index 1 (second element)
                        // Add first element points? No, points are only for removed ones.
                        // Wait, remaining stack contains elements that were NOT removed.
                        // "For each remaining element (except ends), add min(left, right)"
                        // This implies we need to scan the stack.
                        // The stack is currently in stack[0] to stack[sp-1].
                        // We can just iterate through stack array indices.
                        // Let's use proc_idx to iterate 0 to sp.
                        proc_idx <= 1; // Start at 1
                        // We need to distinguish this phase. 
                        // Since we are inside 'if (proc_idx < element_count)', we need to break out.
                        // We can set proc_idx to a high value, say 20, to mark "Remaining Phase".
                        // But wait, we need to process the stack.
                        // Let's change the condition check.
                        
                        // We are here because proc_idx == element_count.
                        // Let's switch to a special value.
                        proc_idx <= 8'hFF; // Marker for Remaining Phase
                    end else if (proc_idx == 8'hFF) begin
                        // Remaining Calculation Phase
                        // Logic: For idx from 1 to sp-2, add min(stack[idx-1], stack[idx+1])
                        // Actually, stack structure: [0 ... sp-1].
                        // Element at i (where 0 < i < sp-1) has left i-1 and right i+1.
                        
                        if (rem_idx < sp - 1) begin
                            left_val <= stack[rem_idx - 1];
                            right_val <= stack[rem_idx + 1];
                            // Add min(left, right)
                            if (stack[rem_idx - 1] < stack[rem_idx + 1]) begin
                                current_score <= current_score + stack[rem_idx - 1];
                            end else begin
                                current_score <= current_score + stack[rem_idx + 1];
                            end
                            rem_idx <= rem_idx + 1;
                        end else begin
                            // Done
                            result <= current_score;
                            done <= 1'b1;
                            next_state <= DONE;
                        end
                    end else begin
                        // Should not reach here normally, but safety
                        // If element_count == 0
                        result <= 32'h0;
                        done <= 1'b1;
                        next_state <= DONE;
                    end
                end
                
                DONE: begin
                    // Hold result
                    done <= 1'b1;
                    ready <= 1'b0; // Wait for start to go low
                    if (!start) begin
                        next_state <= IDLE;
                    end else begin
                        next_state <= DONE;
                    end
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule
