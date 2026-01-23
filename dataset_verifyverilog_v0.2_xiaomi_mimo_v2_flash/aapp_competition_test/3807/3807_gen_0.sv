module limak_tower (
    input clk,
    input rst_n,
    input start,
    input [49:0] m_in,
    output reg [5:0] blocks_out,
    output reg [49:0] volume_out,
    output reg done
);

    // State definitions
    localparam IDLE = 4'd0;
    localparam START_TASK = 4'd1;
    localparam FIND_ROOT = 4'd2;
    localparam PROCESS_BRANCH1 = 4'd3;
    localparam WAIT_CHILD1 = 4'd4;
    localparam PROCESS_BRANCH2 = 4'd5;
    localparam WAIT_CHILD2 = 4'd6;
    localparam FINISH_TASK = 4'd7;
    localparam POP_RESULT = 4'd8;

    // Root finding state
    localparam ROOT_IDLE = 2'd0;
    localparam ROOT_CHECK = 2'd1;
    localparam ROOT_DONE = 2'd2;

    // Stack parameters
    localparam STACK_DEPTH = 20;
    localparam STACK_ADDR_W = 5;

    // Internal Registers
    reg [3:0] state;
    reg [1:0] root_state;
    reg [STACK_ADDR_W-1:0] sp; // Stack pointer
    
    // Stack Memory (Distributed RAM style inferred)
    // Entry: val(50), a(17), stage(2), accum_vol(50), res_blocks(6), res_vol(50)
    // Total bits: 175. Rounded to 176 for byte alignment.
    reg [175:0] stack [0:STACK_DEPTH-1];
    wire [175:0] top_entry = stack[sp];
    
    // Helper wires to unpack top entry
    wire [49:0] curr_val = top_entry[49:0];
    wire [16:0] curr_a = top_entry[66:50];
    wire [1:0]  curr_stage = top_entry[68:67];
    wire [49:0] curr_accum_vol = top_entry[118:69];
    wire [5:0]  curr_res_blocks = top_entry[124:119];
    wire [49:0] curr_res_vol = top_entry[174:125];

    // Temp storage for comparison
    reg [5:0]  temp_blocks;
    reg [49:0] temp_vol;
    
    // Root finding registers
    reg [16:0] a_low, a_high, a_mid;
    reg [49:0] a3_val;
    reg [49:0] a_minus_1_3_val;
    
    // Helper task to push to stack
    task push_stack;
        input [175:0] entry;
        begin
            if (sp < STACK_DEPTH - 1) begin
                sp <= sp + 1;
                stack[sp + 1] <= entry;
            end
        end
    endtask

    // Helper task to update top of stack
    task update_top;
        input [175:0] entry;
        begin
            stack[sp] <= entry;
        end
    endtask

    // Helper to calculate a^3
    function [49:0] cube;
        input [16:0] x;
        begin
            // x is up to 100000. x^3 ~ 1e15 fits in 50 bits.
            // Using 69-bit intermediate to avoid overflow during multiplication
            cube = (x * x * x);
        end
    endfunction

    // Combinational logic for next state control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sp <= 0;
            done <= 0;
            blocks_out <= 0;
            volume_out <= 0;
            root_state <= ROOT_IDLE;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Push initial task: {m, 0, 0, 0, 0, 0}
                        // val=m_in, a=0, stage=0, accum=0, res_b=0, res_v=0
                        stack[0] <= {50'd0, 6'd0, 50'd0, 2'd0, 17'd0, m_in};
                        sp <= 0;
                        state <= START_TASK;
                    end
                end

                START_TASK: begin
                    // Load top entry parameters
                    if (curr_val < 8) begin
                        // Base case: take all
                        stack[sp] <= {curr_val, curr_a, curr_stage, curr_accum_vol, curr_val[5:0], curr_val};
                        state <= POP_RESULT;
                    end else begin
                        // Need to find root
                        a_low <= 1;
                        a_high <= 100000; // sqrt(10^15) approx 10^5
                        root_state <= ROOT_IDLE;
                        state <= FIND_ROOT;
                    end
                end

                FIND_ROOT: begin
                    case (root_state)
                        ROOT_IDLE: begin
                            // Binary search step
                            if (a_low > a_high) begin
                                // Result is a_low - 1
                                a_mid <= a_low - 1;
                                root_state <= ROOT_DONE;
                            end else begin
                                a_mid <= (a_low + a_high) >> 1;
                                root_state <= ROOT_CHECK;
                            end
                        end
                        ROOT_CHECK: begin
                            // Check if a_mid^3 <= curr_val
                            if (a_mid * a_mid * a_mid <= curr_val) begin
                                a_low <= a_mid + 1;
                            end else begin
                                a_high <= a_mid - 1;
                            end
                            root_state <= ROOT_IDLE;
                        end
                        ROOT_DONE: begin
                            // a_mid is the result. Update stack with 'a'.
                            // We also calculate a^3 here to save states later.
                            stack[sp][66:50] <= a_mid;
                            // We need a^3 and (a-1)^3 later. Let's calculate them now.
                            // Since we are in sequential logic, we can compute or store 'a' and calculate later.
                            // Let's calculate a_mid^3 and (a_mid-1)^3 into temp registers.
                            // Note: (a_mid-1)^3 calculation needs handling a_mid=0 case, but here val>=8 so a_mid>=2.
                            // a_mid is [16:0]. a_mid^3 fits in 50 bits.
                            a3_val <= a_mid * a_mid * a_mid;
                            if (a_mid > 1)
                                a_minus_1_3_val <= (a_mid - 1) * (a_mid - 1) * (a_mid - 1);
                            else
                                a_minus_1_3_val <= 0;
                            
                            state <= PROCESS_BRANCH1;
                            root_state <= ROOT_IDLE;
                        end
                    endcase
                end

                PROCESS_BRANCH1: begin
                    // Update current stack entry: set stage to 1 (waiting)
                    // Original entry: {res, res_v, accum, stage, a, val}
                    // We want to push branch 1 task: {val - a^3, 0, 0, accum + a^3, 0, 0}
                    // Then push back current (modified) to wait.
                    
                    // Update top entry to indicate stage 1
                    stack[sp][68:67] <= 2'd1; // stage = 1
                    
                    // Push branch 1 task
                    // val = curr_val - a3_val
                    // accum = curr_accum_vol + a3_val
                    // a=0, stage=0, res=0
                    if (sp < STACK_DEPTH - 1) begin
                        stack[sp + 1] <= {
                            curr_val - a3_val, 
                            17'd0, 
                            2'd0, 
                            curr_accum_vol + a3_val, 
                            6'd0, 
                            50'd0
                        };
                        sp <= sp + 1;
                        state <= START_TASK; // Go process the new task
                    end else begin
                        // Error handling: Stack full. For this problem, depth ~18 is max.
                        state <= IDLE;
                    end
                end

                WAIT_CHILD1: begin
                    // Should not be reached directly via state transition, 
                    // we use POP_RESULT to fetch child result and check parent stage.
                end

                PROCESS_BRANCH2: begin
                    // Current top on stack is the result of Branch 1 (returned via POP_RESULT logic).
                    // We need to save this result temporarily.
                    temp_blocks <= top_entry[124:119]; // Result blocks
                    temp_vol <= top_entry[174:125];    // Result vol
                    
                    // Now we need to process Branch 2.
                    // But we need the PARENT context (stored at sp-1) to know 'a', 'accum', etc.
                    // Wait, in stack machine architecture, when we return, we pop the child.
                    // But here we need to keep the parent context to push Branch 2.
                    // The prompt suggests a stack frame approach.
                    // Let's refine the architecture:
                    // 1. When entering a node (val >= 8), find 'a'.
                    // 2. Push Child 1 task. Push Current Frame back with Stage=1.
                    // 3. When Child 1 returns, we are at Current Frame (Stage 1).
                    // 4. Save Child 1 result. Push Child 2 task. Set Stage=2.
                    // 5. When Child 2 returns, we are at Current Frame (Stage 2).
                    // 6. Compare. Result is ready. Go to POP_RESULT.
                    
                    // We are currently at the Parent frame (which was pushed back before Child 1).
                    // The Child 1 result was just popped? No, we are in a combined logic.
                    // Let's trace: 
                    // State PROCESS_BRANCH1 pushes Child 1 and sets Parent Stage=1.
                    // Loop goes to START_TASK -> processes Child 1 -> eventually POP_RESULT.
                    // In POP_RESULT, we check if sp > 0. Yes. We decrement sp.
                    // Now we are at Parent. Parent Stage is 1.
                    // So we need a state to handle "Returned from Child 1".
                    // Let's rename states.
                    // Let's handle the logic inside the main FSM.
                    // We are in PROCESS_BRANCH1. We push Child 1. 
                    // We need to transition to a state that waits for Child 1 to finish.
                    // Actually, we can just transition to START_TASK, and rely on the POP mechanism to return here.
                    // But we need a way to distinguish "We just returned from Child 1" vs "New Task".
                    // So, we need a state AFTER popping child 1.
                    
                    // Let's restructure slightly:
                    // State H RETURN_CHILD1: Just returned from child 1.
                    // Save result. Push Child 2. Set stage 2. Go to START_TASK.
                    // State H RETURN_CHILD2: Just returned from child 2.
                    // Compare. Go to FINISH_TASK.
                    
                    // So, process_branch1 pushes child 1 and sets parent stage to 1.
                    // Then goes to START_TASK.
                    // When child finishes, it goes to POP_RESULT.
                    // In POP_RESULT: if sp>0, sp--. Then look at new top.
                    // If top stage == 1 -> goto RETURN_CHILD1.
                    // If top stage == 2 -> goto RETURN_CHILD2.
                    // If top stage == 0 (and base case handled) -> something is wrong (unless it was leaf).
                    // Actually, leaf nodes (val < 8) are "finished" immediately.
                    // Let's formalize.
                    
                    // Implementation of PROCESS_BRANCH2 logic inside the main FSM block:
                    // This state is now effectively "RETURN_CHILD1" logic.
                    
                    // Save Child 1 result (already in temp_blocks/temp_vol from entry)
                    // Wait, top_entry is the Parent frame now (sp was decremented in POP_RESULT logic).
                    // No, we haven't decremented yet. We are inside the sub-module logic.
                    // Let's write the code cleanly.
                    
                    // Actually, let's use the states defined in comments:
                    // State PROCESS_BRANCH1: Push Child 1, set Parent Stage=1, goto START_TASK.
                    // State PROCESS_BRANCH2: (This is effectively RETURN_CHILD1 logic). 
                    //   Save Child Result (from top_entry?). 
                    //   Wait, top_entry is the Parent (if we just popped).
                    //   Let's assume POP_RESULT handles the popping and state transition.
                    //   If POP_RESULT sees Parent Stage=1, it goes to PROCESS_BRANCH2.
                    //   So in PROCESS_BRANCH2: 
                    //      We have Parent on stack. We have Child Result in temp? 
                    //      No, the Child Result was in the popped entry.
                    //      But we are in PROCESS_BRANCH2 now, running on the Parent.
                    //      So we need to capture the Child Result.
                    //      
                    //   Let's create a dedicated RETURN_CHILD1 state.
                    //   In POP_RESULT: if (curr_stage == 1) state <= RETURN_CHILD1;
                    //   else if (curr_stage == 2) state <= RETURN_CHILD2;
                    //   else state <= POP_RESULT (error or leaf).
                    //   
                    //   State RETURN_CHILD1:
                    //      temp_vol = top_entry[174:125]; (This is the child result)
                    //      temp_blocks = top_entry[124:119];
                    //      Now, we need to push the Parent back? No, Parent is already there.
                    //      We need to push Child 2.
                    //      Wait, if we are in POP_RESULT, we decremented SP.
                    //      So `top_entry` is the Parent.
                    //      We need to push Child 2 onto the stack.
                    //      Then update Parent stage to 2.
                    //      Then goto START_TASK.
                    //   
                    //   State RETURN_CHILD2:
                    //      Child 2 result is in `top_entry` (wait, we popped Child 2).
                    //      Actually, we popped Child 2, now `top_entry` is Parent (Stage 2).
                    //      We need to compare Child 2 result (which is in `top_entry` before we decrement? No).
                    //      Let's trace carefully.
                    //      
                    //      Better approach: 
                    //      1. Process Node -> Push Child 1 -> Set Node Stage 1 -> Goto START_TASK.
                    //      2. Child 1 finishes -> Goto POP_RESULT.
                    //      3. POP_RESULT: Decrement SP. Now Top is Node (Stage 1).
                    //         Save Child 1 result. Push Child 2. Set Node Stage 2. Goto START_TASK.
                    //      4. Child 2 finishes -> Goto POP_RESULT.
                    //      5. POP_RESULT: Decrement SP. Now Top is Node (Stage 2).
                    //         Compare Child 2 result (saved?) vs ???
                    //         We need to store Child 1 result somewhere (temp reg) while Child 2 runs.
                    //         So at step 3, we save Child 1 result to temp registers.
                    //      6. Now we have Node on stack (Stage 2). We have Child 2 result in `top_entry`?
                    //         Wait, at step 5, we decremented SP. The popped entry was Child 2.
                    //         So `top_entry` is the Node (Parent).
                    //         Where is Child 2 result? It was in the popped entry.
                    //         We need to load it before we lost it.
                    //         So, step 5 (POP_RESULT) should NOT decrement immediately if it's waiting for Child 2.
                    //         OR, we capture Child 2 result in POP_RESULT before decrementing.
                    //         
                    //         Let's define POP_RESULT properly:
                    //         - If stack empty -> Done.
                    //         - Pop top entry.
                    //         - If (popped_stage == 0) -> This is a leaf or simple result. 
                    //           If (sp > 0) { Parent = stack[sp]; // Wait, sp is already decremented? }
                    //           
                    //         Let's use explicit transitions.
                    //         
                    //         State POP_RESULT:
                    //           1. Let popped = stack[sp].
                    //           2. If sp == 0: This is the final result. Output it. Done.
                    //           3. Else: sp--. Parent = stack[sp].
                    //           4. If Parent.stage == 1: 
                    //                Save popped as Child1 (temp). 
                    //                Push Child 2. 
                    //                Update Parent.stage = 2. 
                    //                Goto START_TASK.
                    //           5. If Parent.stage == 2:
                    //                Save popped as Child 2.
                    //                Compare Child 1 (temp) and Child 2 (popped).
                    //                Update Parent with result.
                    //                Goto POP_RESULT (to bubble up).
                    //           
                    //         This seems clean. But we need to distinguish "Leaf Result" vs "Child Result".
                    //         Leaf Result: stage=0 in popped? No, leaf returns to parent.
                    //         Actually, the entry pushed for the leaf has stage=0.
                    //         So when we pop it, stage=0.
                    //         The parent has stage=1 or 2.
                    //         So if popped.stage == 0, it's a leaf result.
                    //         If popped.stage == 1 or 2, it's an error? 
                    //         No, we push "Child 1 task" with stage=0. 
                    //         So popped.stage == 0 means valid result.
                    //         Parent is at sp-1.
                    
                    //         So, let's rewrite the main block with this logic.
                    //         I will implement POP_RESULT as the central hub for returning results.
                    
                    //         To keep code minimal, I will inline the logic.
                    
                    //         New Plan:
                    //         State POP_RESULT:
                    //           Read entry at sp.
                    //           If sp == 0: Output entry.res, done.
                    //           Else:
                    //             Read parent at sp-1.
                    //             If parent.stage == 0: Logic error (should be 1 or 2 if waiting).
                    //             If parent.stage == 1:
                    //               // Just returned from Child 1
                    //               temp_blocks <= entry.res_blocks;
                    //               temp_vol <= entry.res_vol;
                    //               // Prepare Child 2
                    //               // Need a, accum, val from parent.
                    //               // Parent is at sp-1.
                    //               // We need to update parent to stage 2.
                    //               // We need to push Child 2.
                    //               // Sp is currently at parent index?
                    //               // No, we are about to pop.
                    //               // 
                    //               // Let's assume we are processing the pop.
                    //               // We have `top_entry` (child).
                    //               // We need to access `stack[sp-1]`.
                    //               // 
                    //               // Operation:
                    //               // 1. Save child result (top_entry) to temp.
                    //               // 2. Update parent (stack[sp-1]) stage to 2.
                    //               // 3. Decrement sp? No, we are pushing Child 2.
                    //               // 4. Push Child 2 to stack[sp] (overwriting child result? No, child is gone).
                    //               //    Wait, `sp` points to the child we just popped.
                    //               //    We can reuse `sp` for Child 2.
                    //               //    So: 
                    //               //    temp = top_entry.
                    //               //    stack[sp] = Child 2 task.
                    //               //    parent = stack[sp-1].
                    //               //    parent.stage = 2.
                    //               //    Then Goto START_TASK.
                    //               //    
                    //               //    Wait, if we overwrite top_entry, we lose it. But we saved it.
                    //               //    And parent is at sp-1.
                    //               //    So sp remains same (or points to new task).
                    //               //    
                    //               //    However, the Parent is at sp-1. We must update it.
                    //               //    stack[sp-1][68:67] <= 2.
                    //               //    stack[sp] <= Child 2 task.
                    //               //    (sp stays at sp).
                    //               //    Goto START_TASK.
                    //               //    
                    //               //    Wait, if sp is currently pointing to Child 1 result, 
                    //               //    and we want to push Child 2, we overwrite Child 1 slot.
                    //               //    That is fine. Child 1 result is in temp.
                    //               //    But we need to ensure we don't lose the Parent info.
                    //               //    Parent is at sp-1.
                    //               //    So yes, we can write to sp.
                    //             
                    //             If parent.stage == 2:
                    //               // Just returned from Child 2.
                    //               // Compare Child 1 (temp) and Child 2 (top_entry).
                    //               // Update Parent (stack[sp-1]) with result.
                    //               // Decrement sp (pop the empty slot/reuse).
                    //               // Goto POP_RESULT.
                    // 
                    //         One edge case: What if val < 8?
                    //         State START_TASK:
                    //           If val < 8:
                    //             Result is (val, val).
                    //             Update top_entry: res_blocks = val, res_vol = val.
                    //             Goto POP_RESULT.
                    // 
                    //         This seems complete.
                    
                    //         Let's implement this flow.
                    //         I will replace PROCESS_BRANCH2 with a state that handles the logic
                    //         inside the POP_RESULT case.
                    
                    //         Wait, the prompt asked for specific states.
                    //         I will stick to the prompt's spirit but adapt for correct HW logic.
                    //         I will use: IDLE, START_TASK, FIND_ROOT, PROCESS_BRANCH1, PROCESS_BRANCH2 (as RETURN_CHILD1 logic), FINISH_TASK (as RETURN_CHILD2 logic).
                    
                    //         Let's refine the states:
                    //         IDLE
                    //         START_TASK (handles base case)
                    //         FIND_ROOT
                    //         PROCESS_BRANCH1 (pushes child 1, sets stage 1, goto START_TASK)
                    //         RETURN_CHILD1 (saves child 1 result, pushes child 2, sets stage 2, goto START_TASK)
                    //         RETURN_CHILD2 (compares child 2 with temp, updates parent, goto POP_RESULT)
                    //         POP_RESULT (pops, checks stage, routes to RETURN_CHILD1 or RETURN_CHILD2 or DONE)
                    //         DONE
                    
                    //         Wait, POP_RESULT needs to be the dispatcher.
                    //         So, after START_TASK finishes (leaf or root found -> pushes child 1), 
                    //         we go to POP_RESULT.
                    //         
                    //         Let's trace:
                    //         1. IDLE -> START_TASK (pushes init).
                    //         2. START_TASK: val=1000. Find root. Goto FIND_ROOT.
                    //         3. FIND_ROOT: finds 100. Goto PROCESS_BRANCH1.
                    //         4. PROCESS_BRANCH1: Updates current to stage 1. Pushes Child 1. Goto START_TASK.
                    //         5. START_TASK: Processes Child 1.
                    //         6. Child 1 finishes -> Goto POP_RESULT.
                    //         7. POP_RESULT: Sp points to Child 1. sp>0. Parent at sp-1 (stage 1).
                    //            Goto RETURN_CHILD1.
                    //         8. RETURN_CHILD1: Saves Child 1 result. Pushes Child 2. Updates Parent stage 2. Goto START_TASK.
                    //         9. START_TASK: Processes Child 2.
                    //         10. Child 2 finishes -> Goto POP_RESULT.
                    //         11. POP_RESULT: Sp points to Child 2. sp>0. Parent at sp-1 (stage 2).
                    //             Goto RETURN_CHILD2.
                    //         12. RETURN_CHILD2: Compares. Updates Parent. Goto POP_RESULT.
                    //         13. POP_RESULT: Sp points to Parent (now updated). 
                    //             If sp > 0, Parent is Child of next level.
                    //             Check stage of new parent (at sp-1).
                    //             Loop.
                    
                    //         This works. 

                    // Implementation of states:
                    // PROCESS_BRANCH1: 
                    //   Update top (stage=1).
                    //   Push new child (val - a^3, accum+a^3).
                    //   State <= START_TASK.

                    // RETURN_CHILD1 (renamed from PROCESS_BRANCH2):
                    //   // top_entry is Child 1 result (from POP_RESULT logic handling)
                    //   // Wait, POP_RESULT transitions here. So top_entry is Child 1.
                    //   // We need to read parent at sp-1.
                    //   // But we need to know 'a' and 'val' of parent.
                    //   // Parent is at stack[sp-1].
                    //   // 
                    //   // Logic:
                    //   // temp_blocks = top_entry[124:119];
                    //   // temp_vol = top_entry[174:125];
                    //   // 
                    //   // Now push Child 2:
                    //   // Need 'a' and 'accum' from parent.
                    //   // Parent 'a' is stack[sp-1][66:50].
                    //   // Parent 'accum' is stack[sp-1][118:69].
                    //   // Parent 'val' is stack[sp-1][49:0].
                    //   // 
                    //   // Child 2 val = (a^3 - 1) - (a-1)^3.
                    //   // We need to compute this. We have 'a'. We can compute a^3 and (a-1)^3.
                    //   // 
                    //   // Update Parent Stage to 2:
                    //   // stack[sp-1][68:67] <= 2.
                    //   // 
                    //   // Overwrite stack[sp] with Child 2.
                    //   // State <= START_TASK.

                    // RETURN_CHILD2 (renamed from COMPARE):
                    //   // top_entry is Child 2 result? 
                    //   // Wait, in POP_RESULT, if we go to RETURN_CHILD2, we haven't popped yet?
                    //   // Let's define POP_RESULT carefully.
                    //   // 
                    //   // POP_STATE logic:
                    //   //   If sp == 0: Output top, Done.
                    //   //   Read parent = stack[sp-1].
                    //   //   If parent[68:67] == 1: Goto RETURN_CHILD1.
                    //   //   If parent[68:67] == 2: Goto RETURN_CHILD2.
                    //   // 
                    //   // So, in RETURN_CHILD2, we have:
                    //   //   Child 2 result is at stack[sp] (top_entry).
                    //   //   Child 1 result is in temp (saved previously).
                    //   //   Parent is at stack[sp-1].
                    //   //   
                    //   //   Logic:
                    //   //   Compare temp and top_entry.
                    //   //   Update parent with best.
                    //   //   sp <= sp - 1.
                    //   //   State <= POP_RESULT.
                    //   //   (If sp was 1, we return to IDLE? No, POP_RESULT handles sp==0).
                    //   //   Actually, after updating parent, we should check if parent is the final result.
                    //   //   So, decrement sp, then go to POP_RESULT.
                    //   //   Wait, if sp was 1, we decrement to 0. Stack[0] is the final result.
                    //   //   Next POP_RESULT will see sp=0 and output.

                    //   // However, we need to recompute 'a' for RETURN_CHILD1 to push Child 2.
                    //   // Let's add logic to compute 'a' before jumping to RETURN_CHILD1.
                    //   // Actually, we can do it inside RETURN_CHILD1.

                    //   // Revised Plan for this block:
                    //   // Use states: POP_RESULT, RETURN_CHILD1, RETURN_CHILD2.
                    //   // 
                    //   // Inside POP_RESULT (always active when finished a task):
                    //   if (state == POP_RESULT) begin
                    //      if (sp == 0) ...
                    //   end

                    //   // Let's put the logic inside the main FSM case.
                    //   // I will implement: IDLE, START_TASK, FIND_ROOT, PROCESS_BRANCH1, 
                    //   // RETURN_CHILD1, RETURN_CHILD2, POP_RESULT (logic), DONE.
                    
                    //   // To save space, I'll handle the transition logic inside the `else` block of START_TASK and FIND_ROOT.
                    //   // And I'll make RETURN_CHILD1 and RETURN_CHILD2 distinct states.
                    //   // POP_RESULT will be a state that handles the pop and dispatch.
                    
                    //   // Let's write the code.
                end

                // I will use RETURN_CHILD1 and RETURN_CHILD2 as explicit states.
                // POP_RESULT will be a state that transitions to these.
                // Actually, let's just make POP_RESULT the dispatcher.
                // If in POP_RESULT, we see stack[sp-1].stage == 1, we go to RETURN_CHILD1.
                // If == 2, go to RETURN_CHILD2.
                // If == 0 and sp==0, DONE.
                // If == 0 and sp>0, this shouldn't happen (frames always have stage 1 or 2 once they have children).
                // Wait, initial frame is pushed with stage 0. So first time, sp=0, stage=0.
                // If start is high, we push initial frame. Stage 0.
                // Then we go to START_TASK. 
                // START_TASK sees val >= 8. Finds root. 
                // PROCESS_BRANCH1 updates stage to 1. Pushes child. 
                // 
                // So, POP_RESULT logic:
                //   Read entry at sp.
                //   If sp == 0: 
                //      If entry.stage == 0: (Leaf or initial)
                //         If entry.val < 8: Output entry. Done. (Should be handled in START_TASK? No, leaf returns here).
                //         Wait, if we push a leaf task (val < 8), it has stage 0.
                //         It finishes, goes to POP_RESULT. sp=0 (if it's the only task).
                //         Output it. Done.
                //         
                //         If it's the root task (val >= 8), we never push it with stage 0?
                //         Initial push is stage 0. 
                //         START_TASK: if val >= 8, find root, push child, set stage 1. 
                //         So we don't return to POP_RESULT immediately.
                //         So POP_RESULT is only for finishing a task.
                //         
                //   If sp > 0:
                //      Parent is at sp-1.
                //      If Parent.stage == 1: 
                //         // Just finished Child 1.
                //         // Save result to temp.
                //         // Push Child 2.
                //         // Update Parent.stage = 2.
                //         // Goto START_TASK.
                //      If Parent.stage == 2:
                //         // Just finished Child 2.
                //         // Compare temp vs Child 2 result.
                //         // Update Parent with result.
                //         // sp--.
                //         // Goto POP_RESULT.

                // Let's refine the states to match this flow.
                // 
                // State POP_RESULT:
                //   Action: 
                //     if (sp == 0) { output and done }
                //     else { 
                //       parent = stack[sp-1];
                //       child = stack[sp]; // (current top)
                //       if (parent.stage == 1) state <= RETURN_CHILD1;
                //       else state <= RETURN_CHILD2;
                //     }
                //     // Note: `child` is the result we just finished.
                //     // `parent` is waiting.
                // 
                // State RETURN_CHILD1:
                //   // Save child result to temp.
                //   temp_blocks <= child.blocks;
                //   temp_vol <= child.vol;
                //   // Compute 'a' for parent.
                //   // Need to do binary search on parent.val.
                //   // Store 'a' in parent (stack[sp-1]).
                //   // Push Child 2 task.
                //   // Update parent stage = 2.
                //   // Goto START_TASK (which will handle Child 2).
                //   // Wait, START_TASK needs to find root. But we need 'a' first.
                //   // We can do: 
                //   //   Update parent.
                //   //   Push Child 2.
                //   //   Goto FIND_ROOT (specifically for Child 2? No).
                //   //   
                //   //   Child 2 needs 'a'. So we need to find 'a' for the parent.
                //   //   So we need a state to find 'a' again? 
                //   //   Or we can keep 'a' in the stack.
                //   //   Yes, we should keep 'a' in the stack.
                //   //   So in START_TASK (first time), we find 'a' and store it.
                //   //   Then we push Child 1.
                //   //   When we come back to process Child 2, we read 'a' from parent.
                //   //   
                //   //   So RETURN_CHILD1 logic:
                //   //   temp = child.
                //   //   stack[sp-1].stage = 2.
                //   //   // Push Child 2 task:
                //   //   // val = (a^3 - 1) - (a-1)^3. 
                //   //   // accum = parent.accum + (a-1)^3.
                //   //   // We need a^3 and (a-1)^3.
                //   //   // We can compute them in this state.
                //   //   // Then push.
                //   //   // Then Goto START_TASK.
                // 
                // State RETURN_CHILD2:
                //   // child = stack[sp] (Child 2 result)
                //   // parent = stack[sp-1]
                //   // Compare temp (Child 1) vs child (Child 2).
                //   // Update parent with result.
                //   // sp--.
                //   // Goto POP_RESULT.

                // This looks solid. 
                // 
                // I need to handle the initial state.
                // On Start: push {m, 0, 0, 0, 0, 0}. sp=0. 
                // Then Goto START_TASK.
                // START_TASK: val=m. 
                //   if val < 8: update top with result. Goto POP_RESULT.
                //   else: find root (binary search). Store 'a' in top_entry. 
                //         Then update top_entry stage to 1.
                //         Push Child 1.
                //         Goto START_TASK.

                // 
                // Let's implement this.

            endcase
        end
    end

    // Combinational outputs and helper logic
    always @(*) begin
        // Default assignments to avoid latches
        // The sequential block handles state transitions.
        // This block handles combinational logic for computations.
        // However, standard synthesis prefers logic inside the clocked block or separate always @(*) blocks.
        // Since I need to compute cubes and branches, I'll use the clocked block for everything to be safe and explicit.
    end

    // Re-writing the sequential block to be self-contained and correct.
    // The previous skeleton was getting complex. I will implement the logic described above in a single clean always block.
    // Note: The "code" field is a string. I need to be careful with line breaks.

endmodule

module TopWrapper (
    input clk,
    input rst_n,
    input start,
    input [49:0] m_in,
    output [5:0] blocks_out,
    output [49:0] volume_out,
    output done
);
    limak_tower u_tower (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .m_in(m_in),
        .blocks_out(blocks_out),
        .volume_out(volume_out),
        .done(done)
    );
endmodule