module friend_group_checker #(
    parameter MAX_N = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,          // number of nodes (1 to MAX_N)
    input wire [3:0] p,          // max group size
    input wire [3:0] q,          // max cross-edges per group
    input wire [7:0] adj [0:MAX_N-1], // adjacency matrix rows (8 bits each, only first n columns used)
    output reg done,
    output reg valid,
    output reg [2:0] group_id [0:MAX_N-1] // group assignment for each node (0..7)
);

// Behavior:
// - When start is asserted (1 cycle), the module begins computation.
// - The module asserts done when finished (within a few thousand cycles for n≤8).
// - If valid is high, a partition exists and group_id[i] holds the group number for node i.
// - Groups are numbered consecutively from 0.
// - If valid is low, no partition exists; group_id is undefined.
// - Reset: rst_n=0 clears all state, done=0, valid=0, group_id=0.
// - The module uses a DP-over-subsets algorithm:
//     1. Precompute for each subset mask (1..(1<<n)-1) whether it is a valid group:
//        - Size (popcount) ≤ p
//        - Cross-edges ≤ q (sum over nodes in subset of edges to nodes outside)
//     2. DP: dp[mask] = 1 if there exists a submask s of mask such that s is valid and dp[mask\s]=1.
//     3. If dp[(1<<n)-1] = 1, reconstruct partition via stored predecessor submask.
//     4. Output group_id for each node.
// - The module must handle variable n (1..8). Only the lowest n bits of each adj row are considered.
// - The adjacency matrix is symmetric (but not verified).
// - Implementation must be synthesizable; loops can be unrolled for fixed MAX_N.
// - Timing: after start, done will be asserted within a bounded number of cycles (e.g., < 10,000).

// The testbench will provide adj as an array of 8-bit values, one per node, with bits representing friends.
// Example: if node 0 is friends with node 1, then adj[0][1] = 1.

// State declarations
localparam [2:0] IDLE = 3'd0;
localparam [2:0] PRECOMPUTE = 3'd1;
localparam [2:0] DP = 3'd2;
localparam [2:0] RECONSTRUCT = 3'd3;
localparam [2:0] OUTPUT = 3'd4;
localparam [2:0] DONE_STATE = 3'd5;

// Internal registers
reg [2:0] state;
reg [2:0] next_state;

// Cycle counter to prevent infinite loops
reg [13:0] cycle_count;
localparam [13:0] MAX_CYCLES = 14'd10000;

// For subset iteration
reg [7:0] current_mask;
reg [7:0] sub_mask;
reg [3:0] mask_idx;
reg [3:0] sub_idx;
reg [3:0] i_idx;
reg [3:0] j_idx;

// Valid group array (indexed by mask)
reg valid_group [0:255];

// DP arrays
reg dp [0:255];
reg [7:0] pred [0:255];

// Temporary registers for computation
reg [3:0] size;
reg [3:0] cross_edges;
reg [7:0] temp_mask;
reg [3:0] node_idx;
reg [7:0] friend_mask;
reg found;
reg [2:0] group_counter;

// Initialize valid_group and dp arrays
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialize all array elements to 0
        for (i_idx = 8'd0; i_idx < 8'd255; i_idx = i_idx + 1) begin
            valid_group[i_idx] <= 1'b0;
            dp[i_idx] <= 1'b0;
            pred[i_idx] <= 8'd0;
        end
        valid_group[0] <= 1'b0; // Empty set is not a valid group
    end
end

// Main FSM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        valid <= 1'b0;
        cycle_count <= 14'd0;
        current_mask <= 8'd0;
        sub_mask <= 8'd0;
        mask_idx <= 4'd0;
        sub_idx <= 4'd0;
        size <= 4'd0;
        cross_edges <= 4'd0;
        temp_mask <= 8'd0;
        node_idx <= 4'd0;
        found <= 1'b0;
        group_counter <= 3'd0;
        for (i_idx = 8'd0; i_idx < 8'd8; i_idx = i_idx + 1) begin
            group_id[i_idx] <= 3'd0;
        end
    end else begin
        state <= next_state;
        
        // Increment cycle counter unless in IDLE or DONE_STATE
        if (state != IDLE && state != DONE_STATE) begin
            cycle_count <= cycle_count + 14'd1;
        end else begin
            cycle_count <= 14'd0;
        end
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                // Initialize group_id to 0 on start
                for (i_idx = 4'd0; i_idx < 4'd8; i_idx = i_idx + 1) begin
                    group_id[i_idx] <= 3'd0;
                end
                // Reset internal state for new computation
                current_mask <= 8'd0;
                sub_mask <= 8'd0;
                mask_idx <= 4'd0;
                sub_idx <= 4'd0;
                // Reset DP and valid_group arrays for the current run (n will be used)
                // Clear dp array for masks up to (1<<n)-1
                for (i_idx = 8'd0; i_idx < 8'd255; i_idx = i_idx + 1) begin
                    dp[i_idx] <= 1'b0;
                    pred[i_idx] <= 8'd0;
                end
                // Clear valid_group array for masks up to (1<<n)-1
                for (i_idx = 8'd0; i_idx < 8'd255; i_idx = i_idx + 1) begin
                    valid_group[i_idx] <= 1'b0;
                end
                dp[0] <= 1'b1; // Base case: empty set is reachable
            end
            
            PRECOMPUTE: begin
                // Precompute valid_group for mask = mask_idx (1 to (1<<n)-1)
                // Count size (popcount) and cross_edges
                if (mask_idx < (8'd1 << n) && mask_idx > 8'd0) begin
                    size <= 4'd0;
                    cross_edges <= 4'd0;
                    node_idx <= 4'd0;
                end
            end
            
            DP: begin
                // DP transition: dp[mask] = 1 if exists sub_mask s of mask such that dp[mask\s]=1 and valid_group[s]=1
                // sub_idx iterates through submasks of mask_idx
                // Check if dp[mask_idx - sub_idx] is set and valid_group[sub_idx] is set
                if (sub_idx < (8'd1 << n) && sub_idx > 8'd0) begin
                    if ((mask_idx & sub_idx) == sub_idx) begin // Check if sub_idx is submask of mask_idx
                        if (dp[mask_idx ^ sub_idx] && valid_group[sub_idx]) begin
                            dp[mask_idx] <= 1'b1;
                            pred[mask_idx] <= sub_idx;
                            // We only need one valid submask
                            sub_idx <= (8'd1 << n); // Stop iteration
                        end
                    end
                end
            end
            
            RECONSTRUCT: begin
                // Reconstruct partition from dp[(1<<n)-1]
                // Assign group_id from pred chain
                temp_mask <= (8'd1 << n) - 8'd1;
                group_counter <= 3'd0;
            end
            
            OUTPUT: begin
                // Assign group numbers based on pred array
                // Start from full_mask, follow pred
                // For each sub_mask in pred chain, assign group_counter to all nodes in sub_mask
                // Then subtract sub_mask from temp_mask
                // Continue until temp_mask is 0
                if (temp_mask > 8'd0) begin
                    sub_mask <= pred[temp_mask]; // The group to assign
                    temp_mask <= temp_mask ^ pred[temp_mask]; // Remove from remaining
                    group_counter <= group_counter + 3'd1;
                end
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                // valid is set in next_state logic
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

// Combinational next state logic and internal sub-process logic
always @(*) begin
    next_state = state;
    
    case (state)
        IDLE: begin
            if (start) begin
                next_state = PRECOMPUTE;
                mask_idx = 4'd1; // Start checking masks from 1
            end
        end
        
        PRECOMPUTE: begin
            if (mask_idx >= (8'd1 << n)) begin
                // Done with precompute, move to DP
                next_state = DP;
                mask_idx = 4'd1; // Start DP from mask 1
                sub_idx = 4'd0;
            end else begin
                // Compute size and cross_edges for current mask_idx
                size = 4'd0;
                cross_edges = 4'd0;
                // Check each node i in mask
                for (i_idx = 0; i_idx < MAX_N; i_idx = i_idx + 1) begin
                    if (i_idx < n && (mask_idx & (8'd1 << i_idx))) begin
                        size = size + 4'd1;
                        // Count edges to nodes NOT in mask
                        for (j_idx = 0; j_idx < MAX_N; j_idx = j_idx + 1) begin
                            if (j_idx < n && j_idx != i_idx) begin
                                // Check if node j is friend of i
                                if (adj[i_idx][j_idx]) begin
                                    // If j is NOT in mask, it's a cross edge
                                    if (!(mask_idx & (8'd1 << j_idx))) begin
                                        cross_edges = cross_edges + 4'd1;
                                    end
                                end
                            end
                        end
                    end
                end
                // Result valid if size <= p AND cross_edges <= q
                valid_group[mask_idx] = (size <= p) && (cross_edges <= q);
                mask_idx = mask_idx + 8'd1;
            end
        end
        
        DP: begin
            if (mask_idx >= (8'd1 << n)) begin
                // Done with DP, check if full mask is reachable
                if (dp[(8'd1 << n) - 8'd1]) begin
                    next_state = RECONSTRUCT;
                end else begin
                    next_state = DONE_STATE;
                end
            end else begin
                // Generate submasks for current mask_idx
                // sub_idx starts at 0 in PRECOMPUTE->DP transition
                // We iterate sub_idx from 1 to mask_idx
                if (sub_idx == 4'd0) begin
                    sub_idx = 4'd1;
                end else if (sub_idx < mask_idx) begin
                    // Check if sub_idx is submask of mask_idx
                    // If dp[mask_idx ^ sub_idx] && valid_group[sub_idx], set dp[mask_idx]
                    // We set dp and pred in sequential block if condition met
                    // Iterate sub_idx
                    sub_idx = sub_idx + 8'd1;
                end else begin
                    // Done with this mask
                    mask_idx = mask_idx + 8'd1;
                    sub_idx = 4'd0;
                end
            end
        end
        
        RECONSTRUCT: begin
            // Just transition to OUTPUT to handle the loop
            next_state = OUTPUT;
        end
        
        OUTPUT: begin
            // Loop to assign groups
            if (temp_mask > 8'd0) begin
                next_state = OUTPUT; // Stay in OUTPUT while reconstructing
                // Assign group_id for nodes in sub_mask
                // We need to do this in combinational or sequential?
                // The sequential block updates sub_mask and group_counter.
                // We need to assign group_id array elements here or in sequential?
                // Can't assign array elements in combinational block.
                // Must assign in sequential block.
                // We'll use a flag to trigger assignment in sequential block.
                // Actually, we can just use sub_mask and group_counter from previous cycle.
                // Logic in sequential block will assign based on current sub_mask.
                // Wait, we need to identify which nodes are in sub_mask.
                // We'll do that in the sequential block's OUTPUT state.
                // To keep it simple: stay in OUTPUT state until temp_mask is 0.
                // In the cycle where we enter OUTPUT (from RECONSTRUCT), temp_mask is full.
                // In the next cycle, we read pred[temp_mask], set sub_mask, update temp_mask.
                // In the cycle AFTER that, we need to assign group_id.
                // This requires a 2-step OUTPUT or a different structure.
                // Let's refine OUTPUT state logic.
            end else begin
                next_state = DONE_STATE;
            end
        end
        
        DONE_STATE: begin
            next_state = IDLE; // Return to IDLE after one cycle of done
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
    
    // Timeout protection
    if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
        next_state = DONE_STATE;
    end
end

// Array assignment logic for OUTPUT state
// We need to handle the assignment of group_id.
// The sequential block updates 'sub_mask' when in OUTPUT state.
// 'sub_mask' holds the group mask to assign.
// 'group_counter' holds the group number.
always @(posedge clk or negedge rst_n) begin
    if (rst_n) begin
        if (state == OUTPUT) begin
            // Assign group_id for nodes in sub_mask
            // This runs continuously while in OUTPUT, but sub_mask only changes on transitions.
            // To avoid multiple assignments in one cycle for the same node,
            // we check if sub_mask changed or just loop through it.
            // Since sub_mask is updated in the previous cycle's sequential logic,
            // it is valid here.
            // We only want to assign once per sub_mask.
            // Actually, the sub_mask update happens in the NEXT cycle after we enter OUTPUT.
            // Sequence:
            // 1. State = RECONSTRUCT, temp_mask = Full. sub_mask = 0.
            // 2. Next cycle: State = OUTPUT. Logic sees temp_mask > 0. 
            //    It sets sub_mask = pred[Full], temp_mask = Full ^ sub_mask.
            //    It sets group_counter = 1.
            // 3. Next cycle: State = OUTPUT. Logic sees temp_mask > 0.
            //    We should now assign group_id for nodes in sub_mask.
            //    But sub_mask is already updated to the NEXT group.
            //    So we missed the assignment for the first group.
            // Correction: We need to assign group_id for 'sub_mask' *before* updating 'sub_mask' to the next one.
            // OR, we can use a pipeline register for assignment.
            // Let's use a flag 'assign_group' that is high for one cycle after sub_mask is determined.
            // 
            // Revised OUTPUT logic in combinational block:
            // If temp_mask > 0:
            //   sub_mask_next = pred[temp_mask];
            //   group_counter_next = group_counter + 1;
            //   temp_mask_next = temp_mask ^ sub_mask_next;
            //   assign_flag = 1;
            // 
            // In sequential block:
            // If (state == OUTPUT && assign_flag) begin
            //   loop i: if sub_mask[i] -> group_id[i] <= group_counter;
            //   update temp_mask, sub_mask, group_counter.
            // end
            // 
            // Let's implement this.
            // We need 'assign_flag' as a reg.
        end
    end
end

// Re-implement OUTPUT state logic with 'assign_flag'
reg assign_flag;
reg [7:0] sub_mask_to_assign;
reg [2:0] group_num_to_assign;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        assign_flag <= 1'b0;
        sub_mask_to_assign <= 8'd0;
        group_num_to_assign <= 3'd0;
    end else begin
        if (state == OUTPUT) begin
            // We want to trigger assignment when temp_mask changes or initially.
            // Actually, we want to trigger when we have a valid sub_mask from pred.
            // The combinational logic below calculates sub_mask_next.
            // We can just use that.
            // To sync with sequential logic:
            // The combinational block calculates 'sub_mask_next' based on current 'temp_mask'.
            // The sequential block updates 'temp_mask' to 'temp_mask_next' and 'sub_mask' to 'sub_mask_next'.
            // Then in the NEXT cycle, we have 'sub_mask' valid. We need to assign it.
            // So we need a delayed flag.
            // 
            // Let's try a different approach: 
            // In OUTPUT state, stay there until temp_mask is 0.
            // Use a 'processed' flag for the current sub_mask.
            // If !processed and sub_mask != 0: assign group, set processed=1.
            // When moving to next sub_mask: reset processed=0.
            // 
            // Simpler: Use a specific cycle for assignment.
            // Cycle 0 (entering OUTPUT): sub_mask = pred[temp_mask], group = group_counter + 1.
            // Cycle 1: Assign group_id using sub_mask and group.
            // Cycle 2: Update temp_mask = temp_mask ^ sub_mask.
            // Cycle 3: Loop if temp_mask > 0.
            // 
            // Let's use the 'assign_flag' approach combined with sub_mask update.
            // We will update sub_mask and temp_mask only when assign_flag is low.
            // When assign_flag is high, we perform the assignment.
            
            if (!assign_flag && temp_mask > 8'd0) begin
                // Calculate next values
                sub_mask_to_assign <= pred[temp_mask];
                group_num_to_assign <= group_counter + 3'd1;
                assign_flag <= 1'b1;
                // Update temp_mask immediately? No, wait for assignment.
                // But we need to know when to stop (temp_mask becomes 0).
                // Let's update temp_mask to the NEXT value now, but keep a copy.
                // 
                // Actually, let's just use the standard state machine update pattern.
                // We update 'temp_mask' and 'sub_mask' in the combinational next_state logic.
                // We use a signal 'capture_sub_mask' to latch the sub_mask for assignment.
                // 
                // REWIND: 
                // Combinational OUTPUT logic calculates sub_mask_next based on temp_mask.
                // Sequential block: 
                // If (state == OUTPUT && temp_mask > 0) begin
                //   group_id assignment loop (using sub_mask_next from combinational)
                //   temp_mask <= temp_mask ^ sub_mask_next;
                //   group_counter <= group_counter + 1;
                // end
                // 
                // Note: sub_mask_next is available now.
                // Let's implement this cleanly.
            end else if (assign_flag) begin
                assign_flag <= 1'b0;
            end
        end else begin
            assign_flag <= 1'b0;
        end
    end
end

// Combinational logic for OUTPUT state (clean version)
reg [7:0] next_sub_mask;
reg [2:0] next_group_counter;
reg [7:0] next_temp_mask;

always @(*) begin
    if (state == OUTPUT) begin
        if (temp_mask > 8'd0) begin
            next_sub_mask = pred[temp_mask];
            next_temp_mask = temp_mask ^ next_sub_mask;
            next_group_counter = group_counter + 3'd1;
            // Assign group_id for nodes in next_sub_mask
            // We can't do this in combinational block directly if it affects outputs.
            // But 'group_id' is a reg output.
            // We can't assign to reg array in combinational always block.
            // So we must do it in the sequential block.
            // We need to signal the sequential block to update.
            // We'll use 'next_sub_mask' and 'next_group_counter' as inputs to the sequential block.
            // And 'next_temp_mask'.
            // We'll add a 'load_group' signal.
            // 
            // Wait, the constraint says "Only return Verilog code that's synthesizable."
            // Assigning to 'group_id' array in a loop inside a sequential block is fine.
            // 
            // Let's define the logic in the sequential block again, but cleaner.
            // 
            // In SEQUENTIAL block:
            // if (state == OUTPUT && temp_mask > 0) begin
            //    sub_mask = pred[temp_mask]; // Compute this in combinational or sequential?
            //    // Better to compute in combinational to avoid inference issues.
            //    // Let's use the combinational block to set 'next_sub_mask' etc.
            //    // And set a 'update_output' flag.
            // end
            // 
            // Actually, since we are in a loop, let's just use a single cycle per group assignment.
            // Cycle 1: Calculate sub_mask. 
            // Cycle 2: Assign group_id.
            // Cycle 3: Update temp_mask.
            // 
            // Or simpler: calculate sub_mask in combinational.
            // In sequential block:
            //   if (state == OUTPUT && temp_mask > 0) begin
            //      // Use pred[temp_mask] directly (it's a lookup, available this cycle? No, sequential).
            //      // pred is a reg array. Access is synchronous in FPGA block RAM style, 
            //      // but in logic it's combinational if small. 
            //      // Let's assume combinational access for small arrays.
            //      // 
            //      // Okay, let's stick to the 3-cycle approach for OUTPUT state.
            //      // State OUTPUT has sub-states? No, just use cycle count.
            //   end
            // 
            // Let's refine the OUTPUT logic in the SEQUENTIAL block.
            // We need a small internal state for OUTPUT.
            // 
            // Let's add 'output_phase' reg.
        end
    end
end

// Refined Sequential Logic for OUTPUT
reg [1:0] output_phase; // 0: idle/wait, 1: calc, 2: assign

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        output_phase <= 2'd0;
        // Reset group_id
        for (i_idx = 4'd0; i_idx < 4'd8; i_idx = i_idx + 1) begin
            group_id[i_idx] <= 3'd0;
        end
    end else begin
        if (state == OUTPUT) begin
            case (output_phase)
                2'd0: begin
                    if (temp_mask > 8'd0) begin
                        output_phase <= 2'd1; // Go to calculate
                    end
                end
                2'd1: begin
                    // Calculate sub_mask (done in combinational logic ideally, but we can do it here)
                    // pred is a reg array, so reading it takes a cycle or is combinational.
                    // Let's assume combinational read for now (synthesis will handle it as logic).
                    // If pred is LUT, it's combinational. If BRAM, need register slice.
                    // For MAX_N=8, it's small, likely LUT.
                    sub_mask <= pred[temp_mask];
                    output_phase <= 2'd2;
                end
                2'd2: begin
                    // Assign group_id for nodes in sub_mask
                    // sub_mask is now valid
                    for (i_idx = 0; i_idx < MAX_N; i_idx = i_idx + 1) begin
                        if (i_idx < n && sub_mask[i_idx]) begin
                            group_id[i_idx] <= group_counter + 3'd1;
                        end
                    end
                    // Update temp_mask and group_counter
                    temp_mask <= temp_mask ^ sub_mask;
                    group_counter <= group_counter + 3'd1;
                    // Return to phase 0 to check if more groups exist
                    output_phase <= 2'd0;
                end
            endcase
        end else begin
            output_phase <= 2'd0;
        end
    end
end

// Update Combinational OUTPUT logic to match new phase logic
always @(*) begin
    if (state == OUTPUT) begin
        // Logic handled in sequential block with phases
    end
end

// Update DONE_STATE logic to set valid
always @(*) begin
    if (state == DONE_STATE) begin
        valid = dp[(8'd1 << n) - 8'd1];
    end else begin
        valid = 1'b0;
    end
end

endmodule