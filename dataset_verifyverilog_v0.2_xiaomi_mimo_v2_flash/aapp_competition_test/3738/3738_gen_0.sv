module robot_path_solver(
    input clk,
    input rst_n,
    input start,
    input [7:0] target_a,
    input [7:0] target_b,
    input [3:0] cmd_addr,
    input [7:0] cmd_char,
    output reg found,
    output reg done
);

    // State encoding
    typedef enum logic [2:0] {
        IDLE,
        LOAD_CMD,
        PROCESS,
        CHECK,
        FINISH
    } state_t;

    state_t current_state, next_state;

    // Internal Registers
    reg [7:0] cmd_mem [0:7]; // 8x8-bit memory for commands
    reg [2:0] load_idx;      // Index for loading commands (0-7)
    
    reg signed [7:0] curr_x;
    reg signed [7:0] curr_y;
    reg [2:0] cmd_ptr;       // Pointer for current command being processed (0-7)
    reg [1:0] rep_count;     // Repetition counter (0-2)
    
    // Control flags
    reg internal_found;
    reg start_q;             // For edge detection
    
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
            // Reset registers
            found <= 1'b0;
            done <= 1'b0;
            load_idx <= 3'b0;
            curr_x <= 8'sd0;
            curr_y <= 8'sd0;
            cmd_ptr <= 3'b0;
            rep_count <= 2'b0;
            internal_found <= 1'b0;
            start_q <= 1'b0;
            // Reset memory content (optional but good practice)
            // cmd_mem default is x unless explicitly assigned
        end else begin
            start_q <= start; // Capture previous start state
            
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    load_idx <= 3'b0;
                    internal_found <= 1'b0;
                    // Waiting for start rising edge
                    if (start && !start_q) begin
                        // Initialize for LOAD_CMD
                        load_idx <= 3'b0;
                    end
                end

                LOAD_CMD: begin
                    // Store the command at the current address
                    if (cmd_addr < 8) begin
                        cmd_mem[cmd_addr] <= cmd_char;
                    end
                    // Increment a local counter to track completion? 
                    // Requirement says "over 8 clock cycles". 
                    // We assume the control logic handles the sequence length.
                    // To ensure 8 cycles, we can check load_idx.
                    // However, the interface relies on external inputs.
                    // We will increment load_idx and transition when it reaches 8.
                    if (load_idx < 7) begin
                        load_idx <= load_idx + 1;
                    end
                end

                PROCESS: begin
                    // Execute command logic
                    case (cmd_mem[cmd_ptr])
                        8'h55, 8'h55: begin // 'U' (ASCII 0x55)
                            curr_y <= curr_y + 1;
                        end
                        8'h44: begin // 'D' (ASCII 0x44)
                            curr_y <= curr_y - 1;
                        end
                        8'h4C: begin // 'L' (ASCII 0x4C)
                            curr_x <= curr_x - 1;
                        end
                        8'h52: begin // 'R' (ASCII 0x52)
                            curr_x <= curr_x + 1;
                        end
                        default: begin
                            // Invalid command, assume no movement
                        end
                    endcase

                    // Check target match immediately after move
                    // Note: This check happens in the same cycle as the update, 
                    // so it uses the *new* coordinates. This is correct for sequential checks.
                    if ( (curr_x == target_a && curr_y == target_b) || 
                         ( ((cmd_mem[cmd_ptr] == 8'h55) ? (curr_y + 1) : 
                            (cmd_mem[cmd_ptr] == 8'h44) ? (curr_y - 1) : curr_y) == target_b &&
                           ((cmd_mem[cmd_ptr] == 8'h52) ? (curr_x + 1) : 
                            (cmd_mem[cmd_ptr] == 8'h4C) ? (curr_x - 1) : curr_x) == target_a ) )
                    begin
                         // The logic above is complex. Let's rely on the fact that 
                         // curr_x/curr_y are updated this cycle.
                         // But standard Verilog blocking vs non-blocking matters.
                         // Since we use non-blocking assignment (<=), curr_x in the check 
                         // refers to the *previous* value.
                         // Let's use a separate combinational check block or handle it in next state.
                         // Simpler: The requirement says "During the loop, if...".
                         // We can check the *result* of the move.
                    end
                end

                CHECK: begin
                    // State to verify final position if not found yet
                end

                FINISH: begin
                    done <= 1'b1;
                    if (internal_found) found <= 1'b1;
                    if (!start) begin
                        // Reset internal flags if start is low
                        // Usually we stay in FINISH until reset or start
                    end
                end
            endcase
            
            // --- Datapath Updates (Sequenced inside always block for clarity) ---
            
            // LOAD_CMD Counter
            if (current_state == LOAD_CMD) begin
                if (load_idx < 7) load_idx <= load_idx + 1;
                else load_idx <= 0; // Reset for next usage
            end
            
            // PROCESS Counter and Logic
            if (current_state == PROCESS) begin
                // Increment command pointer
                if (cmd_ptr < 7) begin
                    cmd_ptr <= cmd_ptr + 1;
                end else begin
                    cmd_ptr <= 0;
                    // End of a sequence (8 commands)
                    if (rep_count < 1) begin // 0 to 1 (Total 2 loops: 0 and 1)
                        rep_count <= rep_count + 1;
                    end else begin
                        rep_count <= 0; // Prepare for next start
                    end
                end
            end else if (current_state == IDLE) begin
                cmd_ptr <= 0;
                rep_count <= 0;
                curr_x <= 0;
                curr_y <= 0;
            end
        end
    end

    // Combinational Logic for Target Checking
    // Since curr_x/curr_y update via non-blocking, we need to check the *next* value
    // or the specific move to be exactly cycle-accurate if needed.
    // However, typical RTL checks the state after update.
    // Let's define a wire for the specific check.
    wire signed [7:0] next_x;
    wire signed [7:0] next_y;
    wire move_match;

    assign next_x = (cmd_mem[cmd_ptr] == 8'h52) ? curr_x + 1 : 
                    (cmd_mem[cmd_ptr] == 8'h4C) ? curr_x - 1 : curr_x;
    assign next_y = (cmd_mem[cmd_ptr] == 8'h55) ? curr_y + 1 : 
                    (cmd_mem[cmd_ptr] == 8'h44) ? curr_y - 1 : curr_y;
    
    assign move_match = (next_x == target_a) && (next_y == target_b);

    // Next State Logic (Combinational)
    always @(*) begin
        next_state = current_state; // Default hold
        
        case (current_state)
            IDLE: begin
                if (start && !start_q) next_state = LOAD_CMD;
            end
            
            LOAD_CMD: begin
                // Transition to PROCESS after 8 cycles (counting 0-7)
                // We use the load_idx which increments in the seq logic.
                // If we just pushed the last valid index (idx 7), we are done.
                // Actually, if load_idx was 7 and we are in this state, we processed addr 7.
                // Let's rely on load_idx value from previous cycle (current state update).
                // If load_idx == 7, next cycle we will be done. 
                // Wait, in the sequential block, load_idx updates.
                // Let's say we are in LOAD_CMD. The previous cycle loaded idx i.
                // To load 8 items, we need to transition after loading item 7.
                // In the seq block: if (load_idx < 7) load_idx++.
                // So when load_idx == 7 (stored in register), we have loaded 8 items.
                // But wait, initial load_idx is 0. We load addr 0.
                // Next cycle, load_idx becomes 1. ... cycle 7, load_idx becomes 7.
                // Cycle 8, load_idx stays 7 (because !<7). 
                // So we need to detect that we finished the sequence.
                // Let's add a logic: if load_idx == 7 and we just updated it.
                // Better: Add a specific counter for this state or use a flag.
                // Let's just check the load_idx register value. 
                // If load_idx is 7 and we have already updated the memory for that index.
                // To simplify: Let's rely on a "load_done" signal in combinational logic.
                // But the instruction says "over 8 clock cycles".
                // Let's make the transition based on the cycle count.
                // We can use a temporary variable or check the index after update.
                // Since we are in combinational block, `load_idx` reflects the value *after* previous clock edge.
                // If `load_idx` is 7 (meaning we just completed index 7), we should transition next.
                // So if load_idx == 7, next_state = PROCESS.
                if (load_idx == 3'd7) next_state = PROCESS; 
            end
            
            PROCESS: begin
                // We need to run 8 commands (0-7) and 2 repetitions (0,1).
                // cmd_ptr goes 0..7. rep_count goes 0..1.
                // When does cmd_ptr increment? In sequential block, it increments every cycle in PROCESS.
                // So when cmd_ptr becomes 7, we are processing the last command.
                // After that, cmd_ptr wraps to 0 (or we check condition).
                // Condition to stay in PROCESS: cmd_ptr != 7 OR (cmd_ptr == 7 AND rep_count < 1)
                // Wait, in the sequential block, we update cmd_ptr <= cmd_ptr + 1.
                // If cmd_ptr was 6, it becomes 7. We process command 7. 
                // If cmd_ptr was 7, it becomes 0, and rep_count increments.
                // So the condition to stay in PROCESS is: 
                // If we are about to finish the 8 commands but haven't reached 2 repetitions yet.
                // If we just finished command 7 (cmd_ptr is 7 in the register from previous cycle), 
                // and we are processing it now, next cycle we wrap to 0 and inc rep.
                // So we need to stay in PROCESS if:
                // (cmd_ptr != 7) OR (cmd_ptr == 7 AND rep_count != 1)
                // BUT, we also check for found condition.
                
                if (move_match) begin
                    next_state = FINISH;
                end else if (cmd_ptr == 3'd7 && rep_count == 2'd1) begin
                    // We are processing the 8th command of the 2nd repetition (index 7, rep 1)
                    // After this cycle, the loop finishes. We go to CHECK.
                    next_state = CHECK;
                end else begin
                    // Continue processing
                    next_state = PROCESS;
                end
            end
            
            CHECK: begin
                // Final check. In PROCESS, we updated curr_x/curr_y with the last move.
                // We need to compare those final coordinates.
                // Since PROCESS updates are non-blocking, by the time we enter CHECK state,
                // curr_x and curr_y hold the final position.
                // Note: The check in PROCESS checked the move *before* it happened (pipeline effect).
                // Actually, PROCESS checked `move_match` based on logic `next_x`.
                // `next_x` depends on `cmd_ptr` (which hasn't incremented for the next cycle yet).
                // So if PROCESS is state S, `cmd_ptr` is P. `next_x` is P's move. Update happens at end of cycle.
                // So `move_match` checks if P's move lands on target.
                // If we land on target, we go to FINISH. 
                // If we finished the sequence and didn't match, we come to CHECK.
                // In CHECK, we compare the accumulated `curr_x`, `curr_y`.
                // Wait, in PROCESS, if we match, we transition to FINISH immediately.
                // So CHECK is only reached if we finished the sequence without matching.
                // Therefore, CHECK should just check the final accumulated position.
                next_state = FINISH;
            end
            
            FINISH: begin
                if (!start) next_state = IDLE; // Reset on start low
                else next_state = FINISH;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output Logic for 'found' in CHECK state
    // Since CHECK leads to FINISH, we need to assert found if the final position matches.
    // However, `found` is a register. We update it in `always @(posedge clk)`.
    // In the sequential block, we handle `found` assignment. 
    // We need to detect the specific condition for CHECK->FINISH.
    // We can check inside the state machine for CHECK.
    
    // Updating the sequential block to handle CHECK specific logic
    // (Modification to the sequential block above)
    // Inside the sequential always block, we need to handle the CHECK state logic.
    // But wait, I wrote the sequential block logic above.
    // Let's fix the sequential block to handle `internal_found` and `found` correctly.
    
    // Let's refine the sequential block logic for FOUND and internal flags.
    // I will rewrite the relevant part of the sequential block in the `code` section to be correct.
    // The provided code below is the corrected version.

    // Corrected Sequential Block logic for this module:
    // We need to ensure 'found' is set if match occurs in PROCESS or if final pos matches in CHECK.
    
    // Re-writing the module with integrated logic:
    // The above code draft is mostly correct, but needs the specific CHECK logic.
    // In CHECK state: if (curr_x == target_a && curr_y == target_b) internal_found = 1.
    // Then in FINISH, found = internal_found.
    // But wait, we might also find a match in PROCESS. In that case, we transition to FINISH.
    // We need to capture that event.

endmodule

// Detailed implementation fixing the state transitions and register updates
module robot_path_solver_v2(
    input clk,
    input rst_n,
    input start,
    input [7:0] target_a,
    input [7:0] target_b,
    input [3:0] cmd_addr,
    input [7:0] cmd_char,
    output reg found,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD_CMD = 3'b001;
    localparam PROCESS = 3'b010;
    localparam CHECK = 3'b011;
    localparam FINISH = 3'b100;

    reg [2:0] state, next_state;
    reg [7:0] cmd_mem [0:7];
    reg signed [7:0] curr_x, curr_y;
    reg [2:0] cmd_ptr;
    reg [1:0] rep_count;
    reg start_q;
    
    // Memory Write Enable (implied by address match in LOAD_CMD)
    // We need to load 8 chars. The interface provides addr/char.
    // We need a counter to count 8 cycles.
    reg [2:0] load_cnt;
    reg load_done;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // Datapath and Control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            found <= 1'b0;
            done <= 1'b0;
            curr_x <= 8'sd0;
            curr_y <= 8'sd0;
            cmd_ptr <= 3'b0;
            rep_count <= 2'b0;
            load_cnt <= 3'b0;
            load_done <= 1'b0;
            start_q <= 1'b0;
        end else begin
            start_q <= start;
            
            case (state)
                IDLE: begin
                    load_cnt <= 3'b0;
                    load_done <= 1'b0;
                    if (start && !start_q) begin
                        // Start loading
                        load_cnt <= 3'd1; // First cycle
                        // Store first command immediately if valid address provided
                        if (cmd_addr < 8) cmd_mem[cmd_addr] <= cmd_char;
                    end
                    done <= 1'b0;
                    found <= 1'b0;
                end

                LOAD_CMD: begin
                    // We need to load 8 commands total.
                    // We can track it with load_cnt.
                    // If we just processed the 8th command (load_cnt reached 8), we stop.
                    // But wait, we need to load 8 commands.
                    // The interface is asynchronous (addr/char change externally).
                    // We sample them every cycle.
                    // Let's use load_cnt to count how many we have stored.
                    if (cmd_addr < 8) cmd_mem[cmd_addr] <= cmd_char;
                    
                    if (load_cnt < 3'd8) begin
                        load_cnt <= load_cnt + 1;
                    end else begin
                        load_done <= 1'b1;
                    end
                end

                PROCESS: begin
                    // Execute command at cmd_ptr
                    case (cmd_mem[cmd_ptr])
                        8'h55: curr_y <= curr_y + 1; // 'U'
                        8'h44: curr_y <= curr_y - 1; // 'D'
                        8'h4C: curr_x <= curr_x - 1; // 'L'
                        8'h52: curr_x <= curr_x + 1; // 'R'
                        default: begin end
                    endcase

                    // Update pointers
                    if (cmd_ptr < 3'd7) begin
                        cmd_ptr <= cmd_ptr + 1;
                    end else begin
                        cmd_ptr <= 3'd0;
                        if (rep_count < 2'd2) begin
                            rep_count <= rep_count + 1;
                        end
                    end
                end

                CHECK: begin
                    // Prepare for next run if needed (done in state transition implicitly)
                    // or specific reset
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (curr_x == target_a && curr_y == target_b) found <= 1'b1;
                    // If we found it earlier, 'found' should have been set, but usually we set it here.
                    // Wait, if we transition from PROCESS to FINISH because of match,
                    // we need to set found. 
                    // Let's handle found in the transition logic or explicitly here.
                    // Easier: Check final position in FINISH.
                    // But requirement says "assert found and transition".
                    // So we need to set found when transitioning.
                    // Or we can rely on a flag.
                    // Let's use the logic: If we are in FINISH, and (curr_x == target...)
                    // But if we found in PROCESS, we transitioned immediately. 
                    // In that transition, we haven't updated curr_y/curr_x yet for that cycle (non-blocking).
                    // So when we enter FINISH, the coordinates reflect the final move.
                    // So checking `curr_x == target` in FINISH covers both cases.
                end
            endcase
        end
    end

    // Combinational Logic for next state
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && !start_q) next_state = LOAD_CMD;
            end
            
            LOAD_CMD: begin
                // We count 8 cycles. In the seq block, we increment load_cnt.
                // We entered LOAD_CMD when load_cnt was 1 (set in IDLE).
                // We stay here until load_cnt reaches 8.
                // When load_cnt becomes 8, we are done with the 8th cycle.
                if (load_cnt == 3'd8) next_state = PROCESS;
            end
            
            PROCESS: begin
                // Logic to check match immediately.
                // We need to predict the next position to check "During the loop".
                wire signed [7:0] next_x = curr_x;
                wire signed [7:0] next_y = curr_y;
                // We can't use combinational logic inside the sequential block easily for this.
                // Let's do it here.
                // Note: curr_x/curr_y are updated by non-blocking assignment.
                // The value of curr_x in this cycle is the OLD value.
                // We want to check if the CURRENT command lands on target.
                
                reg signed [7:0] temp_x, temp_y;
                temp_x = curr_x;
                temp_y = curr_y;
                case (cmd_mem[cmd_ptr])
                    8'h55: temp_y = temp_y + 1;
                    8'h44: temp_y = temp_y - 1;
                    8'h4C: temp_x = temp_x - 1;
                    8'h52: temp_x = temp_x + 1;
                endcase

                // Check match condition
                if (temp_x == target_a && temp_y == target_b) begin
                    next_state = FINISH;
                end else begin
                    // Check if sequence ends
                    // cmd_ptr is the current index being executed.
                    // If cmd_ptr is 7, this is the last command of a sequence.
                    // If rep_count is 1 (currently running the 2nd repetition), then after this, we are done.
                    // Wait, rep_count is updated in seq block after cmd_ptr wraps.
                    // So if cmd_ptr is 7, and rep_count is 1, this is the end of the 2nd repetition.
                    if (cmd_ptr == 3'd7 && rep_count == 2'd1) begin
                        next_state = CHECK;
                    end else begin
                        next_state = PROCESS;
                    end
                end
            end
            
            CHECK: begin
                // Just a cycle to check the accumulated result.
                // In the previous cycle (PROCESS), we updated curr_x/curr_y.
                // We can check it here.
                next_state = FINISH;
            end
            
            FINISH: begin
                if (!start) next_state = IDLE;
                else next_state = FINISH;
            end
        endcase
    end
    
    // Update 'found' signal separately if needed, or handle in seq block
    // The seq block updates 'found' in FINISH.
    // However, if we transition from PROCESS to FINISH, we skip the FINISH clock cycle update logic for 'found' 
    // immediately, but the register will be updated at the end of that cycle.
    // The problem says "assert found and transition to FINISH".
    // To make 'found' valid when in FINISH, we need to set it.
    // The seq block sets found <= 1'b1 in FINISH if curr_x == target.
    // But if we transition to FINISH, we are in the cycle where we detected the match.
    // In that cycle, we are in PROCESS (state machine transition happens).
    // So 'found' will be set in the *next* cycle (when state becomes FINISH).
    // This is acceptable behavior.

    // However, 'found' is asserted only in FINISH. To catch the match in PROCESS (immediate exit),
    // we can add logic:
    
    // Modify the seq block to check `state` and `next_state` or just add an `else if`.
    // Easiest fix: In the seq block, add `else if (next_state == FINISH && state == PROCESS)` begin found <= 1'b1; end
    // Or simply set found <= 1 whenever we go to FINISH.
    // Let's update the seq block for `found`.

    // Final cleanup of the sequential block for 'found' and 'done':
    // We will include the logic: if (next_state == FINISH) found <= 1'b1 (if conditions met)
    // But we need to know why we transitioned.
    // Let's rely on the check in the combinational block.
    
    // Re-writing the sequential block for `found` and `done`.
    // The `found` logic needs to be in the sequential block because it's a register output.
    // We need to detect the transition to FINISH.
    
    // We will add a signal `transition_to_finish`.
    wire transition_to_finish = (next_state == FINISH && state != FINISH);
    
    // Update the main sequential block logic to use this:
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // ... reset code ...
        end else begin
            // ... existing state updates ...
            
            // Handle found assertion
            if (transition_to_finish) begin
                // Check why we transitioned
                // Case A: Match in PROCESS (checked in comb logic)
                // Case B: End of CHECK (checked in comb logic)
                // We need to re-evaluate the condition.
                // Let's use the temp calculation again or just check final curr_x/curr_y
                // but note that curr_x/curr_y haven't updated for the last move yet in PROCESS->FINISH transition.
                // Wait, if transition happens from PROCESS to FINISH, it's because `temp_x == target`.
                // So we should set found <= 1.
                // If transition happens from CHECK to FINISH, we check `curr_x == target`.
                // 
                // So:
                if (state == PROCESS) begin
                     // Verify the move
                     reg signed [7:0] temp_x = curr_x;
                     reg signed [7:0] temp_y = curr_y;
                     case (cmd_mem[cmd_ptr])
                        8'h55: temp_y = temp_y + 1;
                        8'h44: temp_y = temp_y - 1;
                        8'h4C: temp_x = temp_x - 1;
                        8'h52: temp_x = temp_x + 1;
                     endcase
                     if (temp_x == target_a && temp_y == target_b) found <= 1'b1;
                end else if (state == CHECK) begin
                     if (curr_x == target_a && curr_y == target_b) found <= 1'b1;
                end
            end else if (state == IDLE) begin
                found <= 1'b0;
            end
            
            // Handle done
            if (next_state == FINISH && state != FINISH) begin
                // Just entering FINISH
                done <= 1'b1; // Or we can assert done only when *in* FINISH. 
                // Requirement: "In FINISH state, assert done".
                // So if next_state is FINISH, we will be in FINISH next cycle.
            end else if (state == FINISH) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule

// Simplified version to ensure synthesis and correctness without excessive complexity in the response
module robot_path_solver(
    input clk,
    input rst_n,
    input start,
    input [7:0] target_a,
    input [7:0] target_b,
    input [3:0] cmd_addr,
    input [7:0] cmd_char,
    output reg found,
    output reg done
);

    // States
    localparam IDLE = 3'd0;
    localparam LOAD_CMD = 3'd1;
    localparam PROCESS = 3'd2;
    localparam CHECK = 3'd3;
    localparam FINISH = 3'd4;

    reg [2:0] state;
    reg [7:0] cmd_mem [0:7];
    reg signed [7:0] curr_x, curr_y;
    reg [2:0] cmd_ptr;
    reg [1:0] rep_count;
    reg start_dly;
    reg [2:0] load_cnt;
    
    // Helper wires for current command execution
    wire signed [7:0] move_x = (cmd_mem[cmd_ptr] == 8'h52) ? 1 : (cmd_mem[cmd_ptr] == 8'h4C) ? -1 : 0;
    wire signed [7:0] move_y = (cmd_mem[cmd_ptr] == 8'h55) ? 1 : (cmd_mem[cmd_ptr] == 8'h44) ? -1 : 0;
    wire signed [7:0] next_x = curr_x + move_x;
    wire signed [7:0] next_y = curr_y + move_y;
    wire target_hit = (next_x == target_a) && (next_y == target_b);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            found <= 1'b0;
            done <= 1'b0;
            curr_x <= 0;
            curr_y <= 0;
            cmd_ptr <= 0;
            rep_count <= 0;
            load_cnt <= 0;
            start_dly <= 0;
        end else begin
            start_dly <= start;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    load_cnt <= 0;
                    if (start && !start_dly) begin
                        state <= LOAD_CMD;
                        load_cnt <= 1; // Count the current cycle
                        // Load first command immediately if address valid
                        if (cmd_addr < 8) cmd_mem[cmd_addr] <= cmd_char;
                    end
                end

                LOAD_CMD: begin
                    // Store command at provided address
                    if (cmd_addr < 8) cmd_mem[cmd_addr] <= cmd_char;
                    
                    if (load_cnt < 7) begin
                        load_cnt <= load_cnt + 1;
                    end else begin
                        state <= PROCESS;
                        load_cnt <= 0;
                        curr_x <= 0;
                        curr_y <= 0;
                        cmd_ptr <= 0;
                        rep_count <= 0;
                    end
                end

                PROCESS: begin
                    // Update coordinates
                    curr_x <= next_x;
                    curr_y <= next_y;
                    
                    // Check if target hit with this move (Requirement: "During the loop")
                    // We check the 'target_hit' wire which is combinational based on current cmd_ptr
                    if (target_hit) begin
                        state <= FINISH;
                    end else begin
                        // Advance command pointer
                        if (cmd_ptr < 7) begin
                            cmd_ptr <= cmd_ptr + 1;
                        end else begin
                            // End of sequence
                            cmd_ptr <= 0;
                            if (rep_count < 1) begin // 0 and 1 are 2 repetitions
                                rep_count <= rep_count + 1;
                            end else begin
                                // Finished 2 repetitions
                                state <= CHECK;
                            end
                        end
                    end
                end

                CHECK: begin
                    // Final position check. 
                    // curr_x and curr_y hold the position after the last move (from previous cycle).
                    if (curr_x == target_a && curr_y == target_b)
                        found <= 1'b1;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    // found is already set if triggered in CHECK.
                    // If we jumped from PROCESS, found was NOT set yet.
                    // We need to ensure found is set in that case too.
                    // Since PROCESS checks 'target_hit', if true, we transitioned.
                    // However, 'curr_x' is updated with non-blocking. 
                    // So when we enter FINISH, 'curr_x' matches target (if we came from PROCESS).
                    if (curr_x == target_a && curr_y == target_b)
                        found <= 1'b1;
                    
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule
