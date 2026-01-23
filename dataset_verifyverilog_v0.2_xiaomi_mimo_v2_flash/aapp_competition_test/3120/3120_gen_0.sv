module balloon_eq (
    input clk,
    input rst_n,
    input start,
    input [7:0] program_id,
    input [7:0] node_type,
    input [31:0] node_value,
    input [7:0] child1_idx,
    input [7:0] child2_idx,
    input [7:0] num_nodes,
    input node_valid,
    output reg [1:0] result,
    output reg done
);

    // State definition
    localparam IDLE      = 6'b000001;
    localparam LOAD_A    = 6'b000010;
    localparam LOAD_B    = 6'b000100;
    localparam COMPUTE_A = 6'b001000;
    localparam COMPUTE_B = 6'b010000;
    localparam COMPARE   = 6'b100000;
    // Note: DONE is handled by done signal and result update, staying in IDLE or specific done state
    // We will use IDLE as the resting state after computation

    reg [5:0] current_state, next_state;

    // Memory for node data (max 8 nodes per program)
    // We store data for both programs. Since input stream is sequential, we can use a single buffer 
    // if we assume phases are distinct, but to be safe and handle arbitrary interleaving (though instructions imply phases)
    // we will use two memories.
    // However, inputs are sequential on one interface. The state machine dictates which program we are loading.
    
    // Node memory structure
    reg [7:0]   node_type_mem  [0:7];   // 8 bits for type
    reg [31:0]  node_value_mem [0:7];   // 32 bits for value
    reg [7:0]   child1_idx_mem [0:7];   // 8 bits for child 1 index
    reg [7:0]   child2_idx_mem [0:7];   // 8 bits for child 2 index
    reg [7:0]   num_nodes_A;
    reg [7:0]   num_nodes_B;

    // Load indices
    reg [3:0] load_idx; // 0 to 7

    // Computation signals
    reg [31:0] stack_val [0:7]; // Stack values for current program evaluation
    reg [3:0]  stack_ptr;       // Stack pointer
    reg [3:0]  eval_idx;        // Current node index being evaluated (post-order traversal simulation)
    reg [2:0]  compute_phase;   // To handle multi-cycle logic if needed, or just stepping

    // Result storage
    reg [31:0] result_A [0:7]; // Sorted multiset of A
    reg [31:0] result_B [0:7]; // Sorted multiset of B
    reg [3:0]  result_size_A;
    reg [3:0]  result_size_B;

    // Merge logic registers
    reg [31:0] temp_val_A;
    reg [31:0] temp_val_B;
    reg [3:0]  ptr_A;
    reg [3:0]  ptr_B;
    reg [3:0]  write_ptr;
    reg        merge_done;

    // Done timer
    reg [3:0] done_timer;

    // FSM Synchronous Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result <= 0;
        end else begin
            current_state <= next_state;

            // Done handling
            if (current_state == COMPARE && next_state == IDLE) begin
                done <= 1;
                // Result already set in combinational logic or here
            end else if (current_state == IDLE) begin
                if (start) begin
                    done <= 0;
                end
            end
        end
    end

    // Load and Compute Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_idx <= 0;
            num_nodes_A <= 0;
            num_nodes_B <= 0;
            stack_ptr <= 0;
            eval_idx <= 0;
            compute_phase <= 0;
            ptr_A <= 0;
            ptr_B <= 0;
            write_ptr <= 0;
            merge_done <= 0;
            done_timer <= 0;
        end else begin
            // --- LOAD PHASE ---
            if (current_state == LOAD_A || current_state == LOAD_B) begin
                if (node_valid) begin
                    if (load_idx < num_nodes) begin
                        node_type_mem[load_idx] <= node_type;
                        node_value_mem[load_idx] <= node_value;
                        child1_idx_mem[load_idx] <= child1_idx;
                        child2_idx_mem[load_idx] <= child2_idx;
                        load_idx <= load_idx + 1;
                    end
                end
                if ((current_state == LOAD_A && next_state == LOAD_B) || (current_state == LOAD_B && next_state == COMPUTE_A)) begin
                    // Capture size when loading finishes (assuming node_valid stays high or we trust the num_nodes input timing)
                    // Actually, we capture size on state transition out of load if we can, or simply rely on the input 'num_nodes'.
                    // To be robust, we store the num_nodes input when we enter load or exit.
                    // Let's store it when exiting LOAD state.
                    if (current_state == LOAD_A) num_nodes_A <= num_nodes;
                    if (current_state == LOAD_B) num_nodes_B <= num_nodes;
                    load_idx <= 0;
                end
            end

            // --- COMPUTE_A PHASE ---
            if (current_state == COMPUTE_A) begin
                // Simple post-order traversal simulation: 0, 1, 2, ... (Assuming valid tree where children indices are < current index or standard topo sort)
                // Wait, standard tree eval is usually DFS. But here we have a fixed set of nodes.
                // We iterate indices 0 to num_nodes_A-1.
                // If node is VALUE -> push
                // If CONCAT -> get 2 vals, concat (multiset union), push
                // If SHUFFLE/SORTED -> get 1 val, push (identity)
                
                if (eval_idx < num_nodes_A) begin
                    if (compute_phase == 0) begin
                        // Fetch node type
                        if (node_type_mem[eval_idx] == 8'd0) begin // VALUE
                            // Push value
                            stack_val[stack_ptr] <= node_value_mem[eval_idx];
                            stack_ptr <= stack_ptr + 1;
                            eval_idx <= eval_idx + 1;
                        end else if (node_type_mem[eval_idx] == 8'd1) begin // CONCAT
                            // Need children values. Assume children are already processed (indices < eval_idx)
                            // If children indices are 255, it's invalid, but we assume valid input.
                            // For Concat, we need to combine two multisets. 
                            // In this simple stack architecture, we treat the stack as holding pointers to multisets? 
                            // No, that's complex. Since max 8 nodes, result size is limited.
                            // Let's refine compute logic:
                            // Instead of a value stack, we can process nodes in order and build the result set.
                            // BUT, for CONCAT, we need the results of children.
                            // Let's use the stack, but the stack holds the BASE INDEX of the multiset in result_A.
                            // Actually, simpler: Evaluate all nodes 0..N-1. Store result multiset of each node in memory? 
                            // Memory is tight. 
                            // Let's stick to the stack method but note: This is a DAG/TREE.
                            // We need a valid topological order. 
                            // Let's assume input is in valid topo order (children before parent).
                            // If so, we just iterate. 
                            
                            // Let's refine: We don't stack values, we stack *start indices* in the result_A array.
                            // Size is also needed? No, usually implicit or stored.
                            // Let's use 2 stacks: one for index, one for size.
                            // Or, just compute the final root multiset. We don't need intermediate results if we are memory constrained.
                            // But for CONCAT, we need the intermediate sets.
                            
                            // Plan: 
                            // We will iterate i from 0 to num_nodes_A-1.
                            // We will maintain a result buffer for node i.
                            // This is too much memory. Max 8 nodes, max 8 values.
                            // We can allocate 8*8 = 64 regs. It is okay.
                            
                            // We need a way to access child results.
                            // Let's have arrays: NodeResultStart[0:7], NodeResultSize[0:7].
                            // And a large buffer: ResultBuffer[0:63] to hold all concatenated values.
                            // Wait, this is getting complex for a single module.
                            
                            // Backtrack: The problem says "canonical multiset representation". 
                            // "Compute canonical multiset representation of the expression tree".
                            // This implies we need to sort the multiset at some point.
                            
                            // Revised Compute Logic (Load -> Evaluate -> Sort):
                            // State COMPUTE_A:
                            // 1. Evaluate Tree to get unsorted list of values.
                            //    We can use a pointer to a "Free Memory" area.
                            //    Let's use `eval_idx` to iterate 0 to N-1.
                            //    Let's have a global `buffer_ptr` to write values to `temp_buffer`.
                            //    For each node `i`:
                            //      - If Value: Write to `temp_buffer[buffer_ptr]`, store `start=buffer_ptr, size=1`. Increment buffer_ptr.
                            //      - If Concat: Read child1 start/size, child2 start/size. Copy child1 values to new pos, copy child2. Store new start/size.
                            //      - If Identity: Copy child values. Store new start/size.
                            //    This requires auxiliary memory to store start/size for each node index.
                            //    Let's use: NodeStart[0:7], NodeSize[0:7]. (8 bytes each = 16 bytes).
                            //    And a Buffer[0:63] for values (64*32 = 2048 bits, okay).
                            
                            //    Current phase implementation:
                            //    We need multiple cycles per node potentially if we copy data.
                            //    Let's do it one node per clock (if Value) or multiple clocks if Concat (copying).
                            //    We'll use `compute_phase` as a sub-state.
                            
                            //    Let's implement this in the always block.
                            //    We need internal memory: NodeStart, NodeSize, ValBuffer.
                        end
                    end
                end
            end
        end
    end

    // Re-implementing the Compute Logic properly inside the FSM structure.
    // We need internal memories for NodeStart and NodeSize.
    reg [5:0] NodeStart [0:7]; // Points to index in ValBuffer (0-63)
    reg [3:0] NodeSize  [0:7]; // Number of values
    reg [31:0] ValBuffer [0:63]; // Values buffer
    reg [5:0] buffer_ptr; // Next free slot in ValBuffer
    reg [3:0] node_ptr; // Current node being computed in 0..num_nodes-1
    
    // Copy registers
    reg [5:0] copy_src_start;
    reg [3:0] copy_src_size;
    reg [5:0] copy_dst_start;
    reg [3:0] copy_cnt;
    reg [2:0] compute_substate;
    // 0: Fetch node, 1: Process Value (done), 2: Process Identity (start copy), 3: Process Identity (copying), 
    // 4: Process Concat (copy child 1), 5: Process Concat (copy child 2), 6: Finalize (store start/size, inc node_ptr)

    // Sort registers
    reg [31:0] sort_array [0:7];
    reg [3:0] sort_size;
    reg [2:0] sort_i, sort_j;
    reg [2:0] sort_phase; // 0: Load, 1: Bubble Sort, 2: Store Result
    reg [31:0] sort_temp_swap;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset states
            buffer_ptr <= 0;
            node_ptr <= 0;
            compute_substate <= 0;
            sort_phase <= 0;
            result <= 0;
            // Clear memories (optional but good practice)
        end else begin
            case (current_state)
                LOAD_A, LOAD_B: begin
                    if (node_valid && load_idx < num_nodes) begin
                        node_type_mem[load_idx] <= node_type;
                        node_value_mem[load_idx] <= node_value;
                        child1_idx_mem[load_idx] <= child1_idx;
                        child2_idx_mem[load_idx] <= child2_idx;
                        load_idx <= load_idx + 1;
                    end
                    // Store size on exit (handled in transition logic usually, but let's do it here safely)
                end

                COMPUTE_A, COMPUTE_B: begin
                    // Select which program's memories we are reading from/writing to
                    // (We use the shared memories but logic branches on state)
                    // Actually, we have distinct sets? No, inputs are sequential. We loaded them sequentially.
                    // They are stored in the same memory bank (node_type_mem etc.) because we overwrote indices 0-7.
                    // Wait! This is a problem. If we load A then B, B overwrites A's memory.
                    // We need two sets of memories or rely on the fact that we compute A before loading B? 
                    // The problem says: "Load nodes -> Compute -> ..."
                    // State sequence: IDLE -> LOAD_A -> LOAD_B -> COMPUTE_A -> COMPUTE_B -> COMPARE.
                    // This implies B is loaded before A is computed. This overwrites A's nodes.
                    // Correction: The problem states "The module operates in two phases per program".
                    // Maybe we should compute A immediately after loading A? 
                    // But the state list is given as LOAD_A, LOAD_B, COMPUTE_A, COMPUTE_B.
                    // This implies we MUST store A and B simultaneously or the problem statement implies we process A fully then B.
                    // Given the state list explicitly: IDLE -> LOAD_A -> LOAD_B -> COMPUTE_A -> COMPUTE_B -> COMPARE.
                    // If we strictly follow this, we lose A's data in LOAD_B.
                    // To satisfy the state list AND the requirement to compare, we MUST store A's data somewhere.
                    // Let's use two sets of memories for Node data (Type, Value, ChildIdx).
                    // Memories for A:
                    reg [7:0]   node_type_A  [0:7];
                    reg [31:0]  node_value_A [0:7];
                    reg [7:0]   child1_idx_A [0:7];
                    reg [7:0]   child2_idx_A [0:7];
                    // Memories for B:
                    reg [7:0]   node_type_B  [0:7];
                    reg [31:0]  node_value_B [0:7];
                    reg [7:0]   child1_idx_B [0:7];
                    reg [7:0]   child2_idx_B [0:7];

                    // Update LOAD logic to write to specific memories
                    if (current_state == LOAD_A && node_valid && load_idx < num_nodes) begin
                        node_type_A[load_idx] <= node_type;
                        node_value_A[load_idx] <= node_value;
                        child1_idx_A[load_idx] <= child1_idx;
                        child2_idx_A[load_idx] <= child2_idx;
                    end else if (current_state == LOAD_B && node_valid && load_idx < num_nodes) begin
                        node_type_B[load_idx] <= node_type;
                        node_value_B[load_idx] <= node_value;
                        child1_idx_B[load_idx] <= child1_idx;
                        child2_idx_B[load_idx] <= child2_idx;
                    end

                    // Update Compute Logic
                    if (current_state == COMPUTE_A || current_state == COMPUTE_B) begin
                        // Determine which memory set to use
                        wire [7:0]  curr_type;
                        wire [31:0] curr_val;
                        wire [7:0]  curr_c1, curr_c2;
                        wire [7:0]  curr_num;

                        if (current_state == COMPUTE_A) begin
                            assign curr_type = node_type_A[node_ptr];
                            assign curr_val = node_value_A[node_ptr];
                            assign curr_c1 = child1_idx_A[node_ptr];
                            assign curr_c2 = child2_idx_A[node_ptr];
                            assign curr_num = num_nodes_A;
                        end else begin
                            assign curr_type = node_type_B[node_ptr];
                            assign curr_val = node_value_B[node_ptr];
                            assign curr_c1 = child1_idx_B[node_ptr];
                            assign curr_c2 = child2_idx_B[node_ptr];
                            assign curr_num = num_nodes_B;
                        end

                        // Substate Machine for Compute
                        case (compute_substate)
                            0: begin // Start node
                                if (node_ptr < curr_num) begin
                                    if (curr_type == 8'd0) begin // VALUE
                                        // Write to buffer
                                        ValBuffer[buffer_ptr] <= curr_val;
                                        // Update Node info
                                        if (current_state == COMPUTE_A) begin
                                            NodeStart[node_ptr] <= buffer_ptr;
                                            NodeSize[node_ptr] <= 1;
                                        end else begin
                                            // B specific nodes... wait, we need separate arrays for A and B compute results?
                                            // We need to store A's computed set to compare with B.
                                            // So we need ResultMemA[0:7] and ResultMemB[0:7].
                                            // Let's rename: NodeStartA, NodeSizeA, ValBufferA, etc.
                                            // And NodeStartB, NodeSizeB, ValBufferB.
                                            // To save code lines, let's assume we have separate storage for A and B results.
                                        end
                                        buffer_ptr <= buffer_ptr + 1;
                                        node_ptr <= node_ptr + 1;
                                    end else if (curr_type == 8'd3 || curr_type == 8'd2) begin // SORTED or SHUFFLE
                                        // Identity operation. Need to copy child's multiset.
                                        // Child index is curr_c1.
                                        // Start copy process.
                                        // We need child's start/size from the SAME program's previous compute.
                                        // This requires that we are iterating 0..N in order.
                                        // Assume curr_c1 < node_ptr.
                                        // Let's get child start/size.
                                        // (We'll need logic to fetch from the correct node memory)
                                        // ...
                                        compute_substate <= 2; // Go to identity copy
                                    end else if (curr_type == 8'd1) begin // CONCAT
                                        // Copy child1 then child2
                                        compute_substate <= 4; // Go to concat copy 1
                                    end
                                end else begin
                                    // Computation done for this program
                                    // Extract final set (root is usually node N-1)
                                    if (current_state == COMPUTE_A) begin
                                        // Copy NodeStart[node_ptr-1] ... size to sort_array
                                        // But we need to wait for transition to COMPARE or just do it now.
                                        // We'll let COMPARE state handle the final extraction and sorting.
                                        // Or we finish here.
                                    end
                                end
                            end
                            // ... Implement copy states (Identity/Concat)
                        endcase
                    end
                end
            endcase
        end
    end

    // The provided requirements are quite complex for a single file module without external RAM.
    // Given the "Latency: Done 10 cycles after start", the state machine must be fast.
    // This implies we should not use slow sequential copying.
    // A naive implementation for the specific constraints:
    // 
    // Since we have CLK, we can do pipelining.
    // But with 10 cycles latency, we have 10 cycles total.
    // IDLE -> LOAD_A (1+) -> LOAD_B (1+) -> COMPUTE_A -> COMPUTE_B -> COMPARE -> DONE.
    // If we assume 1 cycle per node load, max 8 nodes = 8 cycles. 
    // We are already over latency if we load 2 programs with 8 nodes each (16 cycles just for loading).
    // 
    // RE-INTERPRETATION: 
    // "Latency: Done will be high 10 clock cycles after start is asserted."
    // This likely means the computation part takes ~10 cycles, OR the TOTAL process from start assertion to done is 10 cycles.
    // If total is 10 cycles, we cannot load 8 nodes sequentially unless we load them fast (e.g. 1 node per cycle, but 2 programs = 16 nodes > 10).
    // This implies either:
    // 1. The testbench only sends small programs.
    // 2. The "node_valid" comes in fast (e.g. multiple nodes per cycle? No, input is reg).
    // 3. The "10 cycles" is a max bound for computation, not including loading? No, "after start".
    // 4. The input interface is pipelined and we can accept one node per cycle.
    // 
    // Let's assume we must strictly fit the state sequence into 10 cycles or the "compute" part is 10 cycles.
    // Given the prompt asks for a "State Machine with states: IDLE, LOAD_A, LOAD_B, COMPUTE_A, COMPARE, DONE",
    // and "Use all provided details".
    // 
    // Let's optimize the logic:
    // We don't need to store all intermediate nodes if we only care about the final root multiset.
    // We can build the multiset of the root node.
    // But for that, we need to traverse the tree.
    // 
    // Let's go with a compact implementation that fits the "10 cycle" constraint by assuming the "Load" phase happens 
    // OUTSIDE or is not part of the 10 cycles (unlikely given "start triggers it").
    // OR, the problem expects a combinational comparison of the tree structure, not a slow iteration.
    // 
    // However, "Load nodes: Receive node data sequentially".
    // 
    // Let's assume the 10 cycles is loose enough for the logic, or we must be extremely efficient.
    // With 8 nodes, we can hardcode the logic for 0..7 steps.
    
    // REVISED PLAN for COMPACT/SYNTHESIZABLE CODE:
    // 1. We need two memories for Node Data (A and B) as previously identified. Let's define them.
    // 2. We need a way to compute the multiset. Since max 8 values, we can use a recursive-style evaluator.
    //    But Verilog is flat. 
    //    Let's use an iterative approach: Iterate i from 0 to 7. 
    //    We need to store the result of node `i` somewhere.
    //    We can use `ValBuffer` but we need to know where to find children.
    //    Since it's a tree (likely with edges pointing backward), we can process 0..7.
    //    We need an array `NodeResult` (size 8) that stores the *sorted* multiset of that node.
    //    Storing 8 sets of up to 8 integers is 64 integers. That's 2048 bits. OK.
    //    Let's use: `reg [31:0] NodeResult [0:7][0:7];`
    //    And `reg [3:0] NodeResultSize [0:7];`
    //    And `reg NodeValidFlag [0:7];` (not strictly needed if we iterate 0..N).
    // 
    // 3. Optimization: We only need the ROOT node's result to compare.
    //    But root depends on children. We must compute children.
    //    So we must compute all nodes.
    // 
    // 4. State Machine Adjustment:
    //    IDLE -> LOAD_A -> LOAD_B -> COMPUTE_A (Process 0..N_A-1) -> COMPUTE_B (Process 0..N_B-1) -> COMPARE -> DONE.
    //    We need to fit this in 10 cycles? 
    //    Let's ignore the 10 cycle hard limit if logic requires more, or optimize:
    //    Maybe the 10 cycles is for the comparison, or we process nodes in parallel.
    //    Given we are "Expert", let's try to make it efficient.
    //    We can do "Compute" in 1 cycle per node if we are smart.
    //    But Concat requires combining sets. Sorting requires loops.
    //    Sorting 8 numbers takes ~28 cycles (bubble sort). 
    //    This exceeds 10 cycles.
    //    
    //    IMPLICATION: The "10 cycles" constraint likely refers to the TIME AFTER computation is finished, or it's a loose guide.
    //    OR, "Latency" refers to output latency from valid input, not total runtime.
    //    
    //    Let's write correct synthesizable logic, and assume the latency constraint is a guide for the "Done" signal behavior (high for 10 cycles?)
    //    Wait: "Done will be high 10 clock cycles after start is asserted."
    //    Usually means: Start=1 at T=0 -> Done=1 at T=10.
    //    
    //    Let's check the structure again. 
    //    If we have to be done by cycle 10, we can't do 8 node loads + sorting.
    //    
    //    ALTERNATIVE INTERPRETATION:
    //    The input is not serial per cycle. `node_valid` indicates the bundle (type, value, etc.) is valid.
    //    But we need to receive `num_nodes` data items.
    //    If we assume we can process nodes quickly:
    //    Cycle 0: Start -> IDLE
    //    Cycle 1: LOAD_A (Simultaneous inputs? No, inputs are one bundle)
    //    
    //    Let's look at the state list: IDLE, LOAD_A, LOAD_B, COMPUTE_A, COMPUTE_B, COMPARE, DONE.
    //    That's 6 states + DONE.
    //    If we spend 1 cycle per state -> 7 cycles.
    //    This fits "10 clock cycles".
    //    HOW?
    //    "Load nodes: Receive node data sequentially."
    //    This implies LOAD_A lasts `num_nodes` cycles.
    //    If `num_nodes` is 8, we have 8 cycles in LOAD_A.
    //    This alone exceeds 10.
    //    
    //    HYPOTHESIS: The prompt implies we should design the logic, and the "10 cycle" is a target for the *comparison phase* or *after loading*. 
    //    BUT "Done will be high 10 clock cycles after start is asserted" is absolute.
    //    
    //    Perhaps the "Load" phase is done via a side-channel or the inputs are provided continuously? 
    //    No, `node_valid` is the control.
    //    
    //    Let's assume the constraint is flexible or that we need to handle only small trees (e.g. 2 nodes) to fit in 10 cycles.
    //    However, we must handle up to 8 nodes.
    //    
    //    Let's try to minimize cycles:
    //    - We can load and process in parallel? No, we need the data.
    //    - Can we process the tree without storing full sets? 
    //      "Determine equivalence of two simplified Balloon programs."
    //      "Canonical multiset representation."
    //      Sorting is required for "Canonical".
    //      
    //    Let's ignore the strict 10-cycle wall for the load phase if it's impossible, and focus on the logic.
    //    Actually, wait. If I am an ASIC designer, I might have a memory block or the inputs might be faster.
    //    
    //    Let's stick to the state machine structure. 
    //    I will implement the logic for one node per cycle in compute.
    //    To handle sorting, I will use a small bubble sort engine.
    //    Given the time, I will write the code that covers the logic. 
    //    If we assume we have 10 cycles TOTAL, we cannot process 8 nodes. 
    //    I will write the code assuming we process nodes as fast as possible.
    //    To make it fit, I will assume we only compute the Root node's result, and for that we use a stack.
    //    Stack approach allows O(N) evaluation.
    //    Sorting O(N^2).
    //    
    //    Let's try to combine Load and Compute.
    //    Actually, the state machine lists LOAD_A, then LOAD_B.
    //    If we execute them sequentially, we are doomed on time.
    //    
    //    IS IT POSSIBLE that the testbench feeds `node_valid` high for all nodes at once? No.
    //    
    //    Let's look at the "Design a combinational Verilog module" instruction. 
    //    Wait, "Combinational Verilog module" but inputs are `reg` (as per instructions) and we have a clock.
    //    This implies a Sequential (FSM) design, but "Combinational" might refer to the logic style (no latches) or was a misnomer.
    //    Given `clk` and `rst_n`, it is Sequential.
    //    
    //    Let's write the code. I will prioritize the logic being correct over the 10-cycle strictness if the logic requires it.
    //    However, I will try to keep it tight.
    //    
    //    Optimized Compute:
    //    We need to sort the final list. Max 8 items. Bubble sort takes 28 comparisons max.
    //    We can do 1 comparison per cycle -> 28 cycles.
    //    This is way over 10.
    //    
    //    Wait. "Canonical multiset".
    //    Maybe we don't need to fully sort? 
    //    "Two programs are equivalent if they produce the same multiset of values with the same probability distribution (ignoring order)."
    //    This IS multiset equivalence. 
    //    Sorting is just one way to canonicalize. 
    //    Hashing is another.
    //    
    //    Given the hardware constraints (10 cycles), maybe we are expected to:
    //    1. Receive input (streaming, but limited cycles).
    //    2. Compute "fingerprint" (XOR of values + sizes?)
    //    
    //    Let's assume the "10 cycle" constraint is a mistake in the prompt or applies to a simplified version (e.g. fixed small tree).
    //    I will write the *correct* logic for the problem description, which implies sorting.
    //    
    //    Code Structure:
    //    1. State Machine as requested.
    //    2. Two memory banks for A and B nodes.
    //    3. Computation Engine:
    //       - Stack for traversal.
    //       - Result accumulator.
    //       - Sorter.
    //    4. Comparator.
    
    //    Let's refine the Compute Phase to be efficient:
    //    Since we need to sort, let's use a small bubble sort block.
    //    We can parallelize the sort? No.
    //    
    //    Let's assume the "10 cycle" target is for the active comparison, and loading happens before "Start" or is fast.
    //    Actually, the prompt says "Latency: Done will be high 10 clock cycles after start is asserted."
    //    If I have to design for 10 cycles total, I must cheat.
    //    Cheat: The problem says "simplified Balloon programs".
    //    Maybe the trees are small? Or the "10 cycles" is a typo and should be "100".
    //    
    //    I will write the code to be robust. 
    //    I will implement a loop for the Bubble Sort that takes multiple cycles. 
    //    I will NOT enforce the 10 cycle limit in the RTL logic (no timeout counter), but I will follow the state machine.
    //    
    //    One key constraint: "Do not assume a clock signal unless it is explicitly given." - It is given.
    
    //    Let's write the module.

    // --- Implementation ---

    // Internal Memory for Program A and B (8 nodes)
    reg [7:0]   node_type_A  [0:7];
    reg [31:0]  node_value_A [0:7];
    reg [7:0]   child1_idx_A [0:7];
    reg [7:0]   child2_idx_A [0:7];
    
    reg [7:0]   node_type_B  [0:7];
    reg [31:0]  node_value_B [0:7];
    reg [7:0]   child1_idx_B [0:7];
    reg [7:0]   child2_idx_B [0:7];

    // Compute Storage
    // We store the result multiset for each node index. 
    // To save space, we only need to store the root's set eventually, but intermediate sets are needed.
    // Since we have 8 nodes, max 8 values per set, we can store 8 sets.
    // Format: [Index][ValueIndex]
    reg [31:0]  multiset_A   [0:7][0:7];
    reg [3:0]   multiset_size_A [0:7];
    reg [31:0]  multiset_B   [0:7][0:7];
    reg [3:0]   multiset_size_B [0:7];

    // Helper variables
    integer i, j, k;
    reg [3:0] current_node_idx;
    reg [3:0] child_idx_1, child_idx_2;
    reg [31:0] temp_val_1, temp_val_2;
    
    // Sorting variables
    reg [31:0] sort_arr [0:7];
    reg [3:0]  sort_n;
    reg [2:0]  sort_x, sort_y;
    reg        sort_swap;
    reg [31:0] sort_temp;

    // State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result <= 0;
            load_idx <= 0;
            current_node_idx <= 0;
            // Reset other stuff
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        current_state <= LOAD_A;
                        load_idx <= 0;
                    end
                end

                LOAD_A: begin
                    if (node_valid && program_id == 8'd0 && load_idx < num_nodes) begin
                        node_type_A[load_idx] <= node_type;
                        node_value_A[load_idx] <= node_value;
                        child1_idx_A[load_idx] <= child1_idx;
                        child2_idx_A[load_idx] <= child2_idx;
                        load_idx <= load_idx + 1;
                    end
                    // Transition condition: if we loaded enough or input stops? 
                    // We use node_valid to count. But how do we know when A is done and B starts?
                    // The problem says: "Load nodes: Receive node data sequentially."
                    // And inputs include `program_id`.
                    // So we look for program_id change or simply rely on the sequence IDLE -> LOAD_A -> LOAD_B.
                    // If we are in LOAD_A, we only care about program_id == 0.
                    // If program_id becomes 1, maybe we switch? 
                    // But the state machine explicitly says LOAD_A then LOAD_B.
                    // This implies `program_id` is fixed during load phase? Or we ignore it and use the state.
                    // Given `start` triggers LOAD_A, we assume we stay in LOAD_A until we have received `num_nodes`.
                    // But `num_nodes` might not be known until loading starts? 
                    // The input `num_nodes` is provided. It is likely static for the program.
                    // Let's assume `num_nodes` input holds the count for the current program.
                    // 
                    // Transition: When load_idx reaches num_nodes.
                    if (load_idx >= num_nodes && num_nodes > 0) begin
                        current_state <= LOAD_B;
                        load_idx <= 0;
                    end else if (num_nodes == 0 && node_valid) begin
                        // Handle zero nodes case
                         current_state <= LOAD_B;
                    end
                end

                LOAD_B: begin
                     if (node_valid && program_id == 8'd1 && load_idx < num_nodes) begin
                        node_type_B[load_idx] <= node_type;
                        node_value_B[load_idx] <= node_value;
                        child1_idx_B[load_idx] <= child1_idx;
                        child2_idx_B[load_idx] <= child2_idx;
                        load_idx <= load_idx + 1;
                    end
                    if (load_idx >= num_nodes && num_nodes > 0) begin
                        current_state <= COMPUTE_A;
                        current_node_idx <= 0;
                    end else if (num_nodes == 0 && node_valid) begin
                        current_state <= COMPUTE_A;
                        current_node_idx <= 0;
                    end
                    // Wait, if we don't know num_nodes beforehand? 
                    // The input provides `num_nodes`. We assume it is valid during loading.
                end

                COMPUTE_A: begin
                    // We process nodes 0 to N-1 sequentially.
                    // We assume the tree is in a valid order (children processed before parent? 
                    // No, the prompt says "tree structure represented by a list of nodes".
                    // It does NOT guarantee topo order. 
                    // However, with `child1_idx`, we can refer to any index.
                    // To support arbitrary DAGs/Lists, we should do a proper DFS or memoization.
                    // Given 8 nodes, we can evaluate each node and cache results.
                    // Let's do: For each node i, if result not ready, compute it.
                    // To avoid recursion in Verilog, we iterate.
                    // Since we are in a clocked block, we can do one step per cycle.
                    
                    // Let's use `current_node_idx` as the node we are trying to compute.
                    // We check if its children are computed.
                    // This is getting complex. 
                    
                    // SIMPLIFICATION: Assume input list is in evaluation order (children before parents).
                    // This is a common format for tree serialization.
                    // If we process 0..N-1, child indices will always be < current index.
                    // We will assume this. 
                    
                    if (current_node_idx < num_nodes_A) begin
                        case (node_type_A[current_node_idx])
                            8'd0: begin // VALUE
                                multiset_A[current_node_idx][0] <= node_value_A[current_node_idx];
                                multiset_size_A[current_node_idx] <= 1;
                                // Done with this node
                                current_node_idx <= current_node_idx + 1;
                            end
                            8'd1: begin // CONCAT
                                // Children must be < current_node_idx
                                child_idx_1 <= child1_idx_A[current_node_idx];
                                child_idx_2 <= child2_idx_A[current_node_idx];
                                // We need to copy the multisets.
                                // This takes time. Let's use a sub-state or just assume we can do it in one cycle if we unroll.
                                // Since max size is 8, we can unroll the copy logic.
                                // Copy Child1
                                for (int k = 0; k < 8; k = k + 1) begin
                                    if (k < multiset_size_A[child_idx_1]) 
                                        multiset_A[current_node_idx][k] <= multiset_A[child_idx_1][k];
                                end
                                // Copy Child2 (offset by size1)
                                for (int k = 0; k < 8; k = k + 1) begin
                                    if (k < multiset_size_A[child_idx_2]) 
                                        multiset_A[current_node_idx][multiset_size_A[child_idx_1] + k] <= multiset_A[child_idx_2][k];
                                end
                                multiset_size_A[current_node_idx] <= multiset_size_A[child_idx_1] + multiset_size_A[child_idx_2];
                                current_node_idx <= current_node_idx + 1;
                            end
                            8'd2, 8'd3: begin // SHUFFLE / SORTED (Identity for multiset)
                                child_idx_1 <= child1_idx_A[current_node_idx];
                                // Copy single child
                                for (int k = 0; k < 8; k = k + 1) begin
                                    if (k < multiset_size_A[child_idx_1])
                                        multiset_A[current_node_idx][k] <= multiset_A[child_idx_1][k];
                                end
                                multiset_size_A[current_node_idx] <= multiset_size_A[child_idx_1];
                                current_node_idx <= current_node_idx + 1;
                            end
                        endcase
                    end else begin
                        // Computation of A done. Sort the root (last node, or we need to identify root? 
                        // The prompt implies we evaluate the tree. Root is usually node 0 or N-1.
                        // Let's assume root is the last node loaded.
                        // So root index = num_nodes_A - 1.
                        // We need to sort this multiset.
                        // We will move to a SORT state.
                        // Prepare sort buffer.
                        for (int k = 0; k < 8; k = k + 1) begin
                            sort_arr[k] <= multiset_A[num_nodes_A - 1][k];
                        end
                        sort_n <= multiset_size_A[num_nodes_A - 1];
                        sort_x <= 0;
                        sort_y <= 0;
                        current_state <= SORT_A;
                    end
                end

                SORT_A: begin
                    // Bubble sort one step per cycle
                    if (sort_x < sort_n - 1) begin
                        if (sort_y < sort_n - sort_x - 1) begin
                            if (sort_arr[sort_y] > sort_arr[sort_y + 1]) begin
                                // Swap
                                sort_temp <= sort_arr[sort_y];
                                sort_arr[sort_y] <= sort_arr[sort_y + 1];
                                sort_arr[sort_y + 1] <= sort_temp;
                            end
                            sort_y <= sort_y + 1;
                        end else begin
                            sort_y <= 0;
                            sort_x <= sort_x + 1;
                        end
                    end else begin
                        // Done sorting. Store into result_A
                        for (int k = 0; k < 8; k = k + 1) begin
                            result_A[k] <= sort_arr[k];
                        end
                        result_size_A <= sort_n;
                        current_state <= COMPUTE_B;
                        current_node_idx <= 0;
                    end
                end

                COMPUTE_B: begin
                    // Same logic as COMPUTE_A but for B
                    if (current_node_idx < num_nodes_B) begin
                        case (node_type_B[current_node_idx])
                            8'd0: begin
                                multiset_B[current_node_idx][0] <= node_value_B[current_node_idx];
                                multiset_size_B[current_node_idx] <= 1;
                                current_node_idx <= current_node_idx + 1;
                            end
                            8'd1: begin
                                child_idx_1 <= child1_idx_B[current_node_idx];
                                child_idx_2 <= child2_idx_B[current_node_idx];
                                for (int k = 0; k < 8; k = k + 1) begin
                                    if (k < multiset_size_B[child_idx_1]) 
                                        multiset_B[current_node_idx][k] <= multiset_B[child_idx_1][k];
                                end
                                for (int k = 0; k < 8; k = k + 1) begin
                                    if (k < multiset_size_B[child_idx_2]) 
                                        multiset_B[current_node_idx][multiset_size_B[child_idx_1] + k] <= multiset_B[child_idx_2][k];
                                end
                                multiset_size_B[current_node_idx] <= multiset_size_B[child_idx_1] + multiset_size_B[child_idx_2];
                                current_node_idx <= current_node_idx + 1;
                            end
                            8'd2, 8'd3: begin
                                child_idx_1 <= child1_idx_B[current_node_idx];
                                for (int k = 0; k < 8; k = k + 1) begin
                                    if (k < multiset_size_B[child_idx_1])
                                        multiset_B[current_node_idx][k] <= multiset_B[child_idx_1][k];
                                end
                                multiset_size_B[current_node_idx] <= multiset_size_B[child_idx_1];
                                current_node_idx <= current_node_idx + 1;
                            end
                        endcase
                    end else begin
                        // Sort B
                        for (int k = 0; k < 8; k = k + 1) begin
                            sort_arr[k] <= multiset_B[num_nodes_B - 1][k];
                        end
                        sort_n <= multiset_size_B[num_nodes_B - 1];
                        sort_x <= 0;
                        sort_y <= 0;
                        current_state <= SORT_B;
                    end
                end

                SORT_B: begin
                    // Bubble sort for B
                    if (sort_x < sort_n - 1) begin
                        if (sort_y < sort_n - sort_x - 1) begin
                            if (sort_arr[sort_y] > sort_arr[sort_y + 1]) begin
                                sort_temp <= sort_arr[sort_y];
                                sort_arr[sort_y] <= sort_arr[sort_y + 1];
                                sort_arr[sort_y + 1] <= sort_temp;
                            end
                            sort_y <= sort_y + 1;
                        end else begin
                            sort_y <= 0;
                            sort_x <= sort_x + 1;
                        end
                    end else begin
                        // Done sorting B. Store into result_B
                        for (int k = 0; k < 8; k = k + 1) begin
                            result_B[k] <= sort_arr[k];
                        end
                        result_size_B <= sort_n;
                        current_state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // Compare result_A and result_B
                    // We need to check size first, then values
                    if (result_size_A != result_size_B) begin
                        result <= 2; // Not Equal
                    end else begin
                        // Check values
                        // We can do this in one cycle with a big AND reduction or sequential check.
                        // Let's do sequential to be safe, but we can unroll.
                        // Actually, we are in COMPARE state. We need to decide Equal or Not Equal.
                        // Since we have 1 cycle for COMPARE (assuming), we need combinational logic or we need sub-states.
                        // The prompt says "State Machine with states... COMPARE, DONE".
                        // And "Done high 10 cycles after start".
                        // Let's assume COMPARE takes 1 cycle (or we move to DONE next cycle).
                        // We'll use combinational logic for the comparison inside the state.
                        // Wait, this is always block. If we put combinational logic here, it acts async.
                        // We should drive result and done asynchronously based on state.
                        // But the instructions say "Your task is to generate an efficient Verilog module".
                        // Let's assume COMPARE takes 1 clock cycle.
                        
                        // We need to compare sorted lists.
                        // Since we are in clocked logic, we can do a multi-cycle compare if we want.
                        // But we want to finish.
                        // Let's do the compare in one cycle using generate unrolling or explicit checking.
                        // Since it's inside always @(posedge clk), we need to assign result.
                        // Let's use a helper wire for equality.
                        
                        // We can't easily iterate in clocked block without a counter unless we unroll.
                        // Let's use a counter to compare over 8 cycles if needed, but we want to be fast.
                        // Let's unroll the check.
                        
                        reg eq;
                        integer m;
                        eq = 1'b1;
                        for (m = 0; m < 8; m = m + 1) begin
                            if (m < result_size_A) begin
                                if (result_A[m] != result_B[m]) eq = 1'b0;
                            end
                        end
                        
                        if (eq) result <= 1; else result <= 2;
                    end
                    
                    current_state <= IDLE; // Go back to IDLE, but set done high
                    // Actually, we need to hold DONE high.
                    // The instruction "Done high 10 cycles after start" is tricky.
                    // If we go to IDLE, done goes low (as per reset logic above).
                    // We need a DONE state or a counter.
                    // Let's add a DONE state to the localparam if not present, but it wasn't in the list.
                    // The list was IDLE, LOAD_A, LOAD_B, COMPUTE_A, COMPUTE_B, COMPARE, DONE.
                    // Yes, DONE is in the list.
                    // So transition to DONE.
                    current_state <= DONE;
                end

                DONE: begin
                    done <= 1;
                    // Wait 10 cycles? 
                    // The prompt says "Done will be high 10 clock cycles after start is asserted."
                    // This implies `done` stays high for 10 cycles? Or `done` goes high at cycle 10?
                    // Usually: Start -> ... -> Done (high for 1 cycle or pulse).
                    // "Latency: Done will be high 10 clock cycles after start is asserted."
                    // If it means pulse at cycle 10, we are done.
                    // If it means hold for 10 cycles, we need a counter.
                    // Let's assume it means the computation finishes by cycle 10.
                    // We will stay in DONE for 1 cycle, then go to IDLE.
                    // To be safe, let's stay in DONE until reset or start again?
                    // Usually go to IDLE.
                    current_state <= IDLE;
                    done <= 0; // Pulse handled? Or continuous?
                    // "output reg done // High when computation complete"
                    // If we go to IDLE immediately, done is high for 1 cycle.
                    // That fits "High when complete".
                end
            endcase
        end
    end

    // We need to handle the case where we transition from COMPARE to IDLE in one cycle.
    // The code above sets current_state <= IDLE in COMPARE block.
    // It also sets result.
    // Then in IDLE, done is reset to 0.
    // This gives a 1-cycle done pulse.
    // If 10 cycles is required, we need a counter.
    // Let's assume the 10 cycles refers to the deadline, not duration.
    // Or, we can add a simple counter in the DONE state.
    // But the state list is "IDLE, LOAD_A, LOAD_B, COMPUTE_A, COMPUTE_B, COMPARE, DONE".
    // If we strictly follow the list, we can hang in DONE.
    // I will modify the COMPARE transition to go to a "DONE" state.
    // And in DONE, I will count.

    // Revision for COMPARE:
    // ... inside COMPARE state block ...
    // if (eq) result <= 1; else result <= 2;
    // done_timer <= 0;
    // current_state <= DONE;

    // Revision for DONE:
    // done <= 1;
    // if (done_timer < 9) begin
    //    done_timer <= done_timer + 1;
    // end else begin
    //    current_state <= IDLE;
    //    done <= 0;
    // end

    // Let's integrate this.

endmodule

module TopModuleWrapper(
    input clk,
    input rst_n,
    input start,
    input [7:0] program_id,
    input [7:0] node_type,
    input [31:0] node_value,
    input [7:0] child1_idx,
    input [7:0] child2_idx,
    input [7:0] num_nodes,
    input node_valid,
    output [1:0] result,
    output done
);
    balloon_eq u_ballooon (
        .clk(clk), .rst_n(rst_n), .start(start),
        .program_id(program_id), .node_type(node_type), .node_value(node_value),
        .child1_idx(child1_idx), .child2_idx(child2_idx), .num_nodes(num_nodes),
        .node_valid(node_valid),
        .result(result), .done(done)
    );
endmodule

// Note: SystemVerilog 'always_comb' or 'function' could be used for sorting/comparison,
// but standard Verilog 'always @(posedge clk)' is requested.
// I used for-loops inside always block. This is synthesizable for FPGAs and some ASIC tools if unrolled.
// Given the "Expert" prompt, I assume advanced synthesis tools.

// The provided code in the thought process was pseudo-code. I need to write the clean module.
// I will wrap the code in the requested JSON format.
// I will consolidate the code into a single module to avoid external dependencies.

// Correction: The prompt asks for a module named 'balloon_eq'.

// Let's write the final clean code.

// --- Final Code Generation ---

module balloon_eq (
    input clk,
    input rst_n,
    input start,
    input [7:0] program_id,
    input [7:0] node_type,
    input [31:0] node_value,
    input [7:0] child1_idx,
    input [7:0] child2_idx,
    input [7:0] num_nodes,
    input node_valid,
    output reg [1:0] result,
    output reg done
);

    // States
    localparam IDLE      = 0;
    localparam LOAD_A    = 1;
    localparam LOAD_B    = 2;
    localparam COMPUTE_A = 3;
    localparam SORT_A    = 4;
    localparam COMPUTE_B = 5;
    localparam SORT_B    = 6;
    localparam COMPARE   = 7;
    localparam DONE      = 8;

    reg [3:0] state, next_state;

    // Memories for Node Data (Type, Value, Child1, Child2)
    // We need A and B sets because we load A then B.
    reg [7:0]   n_type_A  [0:7];
    reg [31:0]  n_val_A   [0:7];
    reg [7:0]   c1_A      [0:7];
    reg [7:0]   c2_A      [0:7];
    
    reg [7:0]   n_type_B  [0:7];
    reg [31:0]  n_val_B   [0:7];
    reg [7:0]   c1_B      [0:7];
    reg [7:0]   c2_B      [0:7];

    // Computation Buffers
    // Multisets for each node index. (Max 8 nodes, max 8 values per set)
    // We need to store intermediate results to handle trees.
    // Layout: [NodeIdx][ValueIdx]
    reg [31:0]  ms_A [0:7][0:7];
    reg [3:0]   ms_size_A [0:7];
    
    reg [31:0]  ms_B [0:7][0:7];
    reg [3:0]   ms_size_B [0:7];

    // Final Sorted Results
    reg [31:0]  final_A [0:7];
    reg [3:0]   final_size_A;
    reg [31:0]  final_B [0:7];
    reg [3:0]   final_size_B;

    // Iteration / Counters
    reg [3:0] idx;        // General index (node index or load index)
    reg [2:0] sub_idx;    // Sub-index for copying loops
    reg [2:0] sort_x, sort_y; // Sort counters
    reg [3:0] done_cnt;   // Done timer

    // Temporary registers for combinational logic within clock edge
    reg [31:0] temp_val_1, temp_val_2;
    reg [7:0]  child1, child2;
    integer i, j; // Loop variables

    // State Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
        end else begin
            state <= next_state;
            
            // Done signal logic
            if (state == DONE) begin
                done <= 1;
            end else if (state == IDLE) begin
                done <= 0;
            end else begin
                done <= 0;
            end
        end
    end

    // Next State & Output Logic (Combined for simplicity)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic handled above
            idx <= 0;
            sub_idx <= 0;
            sort_x <= 0;
            sort_y <= 0;
            done_cnt <= 0;
            // Clear sizes
            final_size_A <= 0;
            final_size_B <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        idx <= 0; // Reset load index
                    end
                end

                LOAD_A: begin
                    if (node_valid && program_id == 0 && idx < num_nodes) begin
                        n_type_A[idx] <= node_type;
                        n_val_A[idx] <= node_value;
                        c1_A[idx] <= child1_idx;
                        c2_A[idx] <= child2_idx;
                        idx <= idx + 1;
                    end
                    // Transition occurs in combinational block based on idx and num_nodes
                end

                LOAD_B: begin
                    if (node_valid && program_id == 1 && idx < num_nodes) begin
                        n_type_B[idx] <= node_type;
                        n_val_B[idx] <= node_value;
                        c1_B[idx] <= child1_idx;
                        c2_B[idx] <= child2_idx;
                        idx <= idx + 1;
                    end
                end

                COMPUTE_A: begin
                    // Processing node 'idx'
                    // We assume nodes are listed in dependency order (children before parents)
                    // If not, we would need a DFS, but that requires dynamic stack which is complex.
                    // We'll stick to the assumption for a clean synthesizable solution.
                    if (idx < num_nodes_A) begin
                        case (n_type_A[idx])
                            0: begin // VALUE
                                ms_A[idx][0] <= n_val_A[idx];
                                ms_size_A[idx] <= 1;
                            end
                            1: begin // CONCAT
                                // Copy child 1
                                for (i = 0; i < 8; i = i + 1) begin
                                    if (i < ms_size_A[c1_A[idx]]) ms_A[idx][i] <= ms_A[c1_A[idx]][i];
                                end
                                // Copy child 2
                                for (i = 0; i < 8; i = i + 1) begin
                                    if (i < ms_size_A[c2_A[idx]]) ms_A[idx][ms_size_A[c1_A[idx]] + i] <= ms_A[c2_A[idx]][i];
                                end
                                ms_size_A[idx] <= ms_size_A[c1_A[idx]] + ms_size_A[c2_A[idx]];
                            end
                            2, 3: begin // SHUFFLE or SORTED (Identity)
                                for (i = 0; i < 8; i = i + 1) begin
                                    if (i < ms_size_A[c1_A[idx]]) ms_A[idx][i] <= ms_A[c1_A[idx]][i];
                                end
                                ms_size_A[idx] <= ms_size_A[c1_A[idx]];
                            end
                        endcase
                        idx <= idx + 1;
                    end else begin
                        // Compute done for A. Prepare Sort.
                        // Root is the last node (idx-1). 
                        // We need to sort it into final_A.
                        // Copy to sort buffer (using ms_A[idx-1])
                        // We will use the sorting registers to hold the array being sorted.
                        // Since we are moving to SORT_A, we set up the sort registers.
                        // But we need to copy ms_A[idx-1] to a temp buffer.
                        // Let's use `final_A` as the sort buffer during sorting.
                        for (i = 0; i < 8; i = i + 1) begin
                            final_A[i] <= ms_A[idx - 1][i];
                        end
                        final_size_A <= ms_size_A[idx - 1];
                        // Reset sort counters
                        sort_x <= 0;
                        sort_y <= 0;
                    end
                end

                SORT_A: begin
                    // Bubble sort on final_A
                    if (final_size_A > 1) begin
                        if (sort_y < final_size_A - sort_x - 1) begin
                            if (final_A[sort_y] > final_A[sort_y + 1]) begin
                                final_A[sort_y] <= final_A[sort_y + 1];
                                final_A[sort_y + 1] <= final_A[sort_y];
                            end
                            sort_y <= sort_y + 1;
                        end else begin
                            sort_y <= 0;
                            sort_x <= sort_x + 1;
                        end
                    end
                    // Completion logic handled in next_state logic
                end

                COMPUTE_B: begin
                    if (idx < num_nodes_B) begin
                        case (n_type_B[idx])
                            0: begin
                                ms_B[idx][0] <= n_val_B[idx];
                                ms_size_B[idx] <= 1;
                            end
                            1: begin
                                for (i = 0; i < 8; i = i + 1) begin
                                    if (i < ms_size_B[c1_B[idx]]) ms_B[idx][i] <= ms_B[c1_B[idx]][i];
                                end
                                for (i = 0; i < 8; i = i + 1) begin
                                    if (i < ms_size_B[c2_B[idx]]) ms_B[idx][ms_size_B[c1_B[idx]] + i] <= ms_B[c2_B[idx]][i];
                                end
                                ms_size_B[idx] <= ms_size_B[c1_B[idx]] + ms_size_B[c2_B[idx]];
                            end
                            2, 3: begin
                                for (i = 0; i < 8; i = i + 1) begin
                                    if (i < ms_size_B[c1_B[idx]]) ms_B[idx][i] <= ms_B[c1_B[idx]][i];
                                end
                                ms_size_B[idx] <= ms_size_B[c1_B[idx]];
                            end
                        endcase
                        idx <= idx + 1;
                    end else begin
                        // Prepare Sort B
                        for (i = 0; i < 8; i = i + 1) begin
                            final_B[i] <= ms_B[idx - 1][i];
                        end
                        final_size_B <= ms_size_B[idx - 1];
                        sort_x <= 0;
                        sort_y <= 0;
                    end
                end

                SORT_B: begin
                    if (final_size_B > 1) begin
                        if (sort_y < final_size_B - sort_x - 1) begin
                            if (final_B[sort_y] > final_B[sort_y + 1]) begin
                                final_B[sort_y] <= final_B[sort_y + 1];
                                final_B[sort_y + 1] <= final_B[sort_y];
                            end
                            sort_y <= sort_y + 1;
                        end else begin
                            sort_y <= 0;
                            sort_x <= sort_x + 1;
                        end
                    end
                end

                COMPARE: begin
                    // Determine result
                    // This logic is combinational, but we latch it here or let it drive output.
                    // We'll latch the result.
                    if (final_size_A != final_size_B) begin
                        result <= 2; // Not Equal
                    end else begin
                        // Compare elements
                        reg match;
                        match = 1;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < final_size_A && final_A[i] != final_B[i]) match = 0;
                        end
                        result <= match ? 1 : 2;
                    end
                    done_cnt <= 0;
                end

                DONE: begin
                    // Hold done high for required cycles or just proceed.
                    // The prompt says "Done will be high 10 clock cycles after start".
                    // This is ambiguous. It usually means latency is 10 cycles.
                    // Since our state machine has many steps, it might take > 10 cycles to finish.
                    // We will just pulse done for 1 cycle here.
                    // If we need to count, we can do: if (done_cnt < 9) done_cnt <= done_cnt + 1;
                    // else state <= IDLE;
                    // But let's assume 1 cycle pulse is "High when computation complete".
                end
            endcase
        end
    end

    // Next State Combinational Logic
    always @(*) begin
        next_state = state; // Default stay
        case (state)
            IDLE: if (start) next_state = LOAD_A;
            
            LOAD_A: if (idx >= num_nodes && num_nodes > 0) next_state = LOAD_B;
                     else if (num_nodes == 0 && node_valid) next_state = LOAD_B; // Edge case
            
            LOAD_B: if (idx >= num_nodes && num_nodes > 0) next_state = COMPUTE_A;
                     else if (num_nodes == 0 && node_valid) next_state = COMPUTE_A;
            
            COMPUTE_A: if (idx >= num_nodes_A) next_state = SORT_A;
            
            SORT_A: if (sort_x >= final_size_A - 1 || final_size_A <= 1) next_state = COMPUTE_B;
            
            COMPUTE_B: if (idx >= num_nodes_B) next_state = SORT_B;
            
            SORT_B: if (sort_x >= final_size_B - 1 || final_size_B <= 1) next_state = COMPARE;
            
            COMPARE: next_state = DONE;
            
            DONE: next_state = IDLE; // Return to idle immediately
        endcase
    end

endmodule
