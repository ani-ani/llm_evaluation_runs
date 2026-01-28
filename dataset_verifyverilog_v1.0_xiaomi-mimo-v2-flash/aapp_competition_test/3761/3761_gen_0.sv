module robot_nav (
    input clk,
    input rst_n,
    input start,
    input [7:0] instruction,
    input signed [15:0] target_x,
    input signed [15:0] target_y,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] PARSE      = 3'd1;
    localparam [2:0] DP_X_START = 3'd2;
    localparam [2:0] DP_X_PROC  = 3'd3;
    localparam [2:0] DP_Y_START = 3'd4;
    localparam [2:0] DP_Y_PROC  = 3'd5;
    localparam [2:0] CHECK      = 3'd6;
    localparam [2:0] FINISHED   = 3'd7;

    // Constants
    localparam OFFSET = 16'd8000;
    localparam MAX_BITSET = 16001; // 0 to 16000
    localparam [15:0] MAX_COORD = 16'd8000;
    localparam MAX_INSTR_LEN = 16'd8000;
    localparam MAX_MOVES = 16'd4000; // Approximate

    // Internal signals and registers
    reg [2:0] state, next_state;
    reg [15:0] instr_cnt;
    reg [15:0] turn_cnt;
    reg [15:0] run_len;
    reg signed [15:0] target_dp;
    reg is_first_fixed_reg;
    
    // Move lists (packed arrays for efficiency)
    // We store up to MAX_MOVES moves. Each move is 16-bit signed.
    // We use two separate memories for X and Y moves.
    reg signed [15:0] moves_x [0:1023]; // Reduced size for synthesis
    reg signed [15:0] moves_y [0:1023];
    reg [10:0] move_idx_x;
    reg [10:0] move_idx_y;
    reg [10:0] proc_idx;
    reg [10:0] move_count;

    // Bitset for DP
    // We need a bitset of size 16001. 
    // In Verilog, we can model this as a large register array or a memory.
    // To be synthesizable and efficient, we will use a single bit vector.
    // However, 16001 bits is large for a single vector shift operation.
    // We will use a bitset represented as an array of words.
    // Let's use 32-bit words. 16001 bits / 32 = 501 words (500 full, 1 partial).
    localparam NUM_WORDS = 16'd501;
    reg [31:0] dp_set [0:500];
    reg [15:0] move_val;
    reg [15:0] abs_move;
    reg signed [15:0] signed_move;
    
    // DP helper signals
    reg [8:0] dp_idx; // Index for bitset iteration (0 to 16000)
    reg dp_update_done;
    reg [15:0] bit_offset;
    
    // Loop counters
    integer i;

    // FSM State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            instr_cnt <= 16'd0;
            turn_cnt <= 16'd0;
            run_len <= 16'd0;
            move_idx_x <= 11'd0;
            move_idx_y <= 11'd0;
            result <= 1'b0;
            done <= 1'b0;
            proc_idx <= 11'd0;
            dp_idx <= 9'd0;
            dp_update_done <= 1'b0;
            for (i = 0; i < 501; i = i + 1) begin
                dp_set[i] <= 32'd0;
            end
            // Initialize move arrays to 0
            for (i = 0; i < 1024; i = i + 1) begin
                moves_x[i] <= 16'd0;
                moves_y[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    instr_cnt <= 16'd0;
                    turn_cnt <= 16'd0;
                    run_len <= 16'd0;
                    move_idx_x <= 11'd0;
                    move_idx_y <= 11'd0;
                end
                
                PARSE: begin
                    // Process one character per cycle
                    if (instruction == 8'd70) begin // 'F'
                        run_len <= run_len + 16'd1;
                    end else if (instruction == 8'd84) begin // 'T'
                        // Flush run length to appropriate list
                        if (run_len > 0) begin
                            if ((turn_cnt & 16'd1) == 16'd0) begin // Even turns (X axis)
                                if (move_idx_x < 1024) begin
                                    moves_x[move_idx_x] <= (turn_cnt == 0) ? run_len : run_len; // X moves are all positive in our list, but sign handled by selection in DP
                                    move_idx_x <= move_idx_x + 11'd1;
                                end
                            end else begin // Odd turns (Y axis)
                                if (move_idx_y < 1024) begin
                                    moves_y[move_idx_y] <= run_len;
                                    move_idx_y <= move_idx_y + 11'd1;
                                end
                            end
                        end
                        turn_cnt <= turn_cnt + 16'd1;
                        run_len <= 16'd0;
                    end
                    // Note: Testbench handles end of string condition by deasserting start or sending null
                end
                
                DP_X_START: begin
                    // Initialize DP for X
                    for (i = 0; i < 501; i = i + 1) begin
                        dp_set[i] <= 32'd0;
                    end
                    proc_idx <= 11'd0;
                    
                    if (move_idx_x > 0) begin
                        // First move logic
                        bit_offset <= OFFSET + moves_x[0];
                        // Set bit at offset + moves_x[0]
                        dp_set[bit_offset[15:5]] <= 32'd1 << bit_offset[4:0];
                        proc_idx <= 11'd1; // Start from second move
                    end else begin
                        // No moves on X? Check if target is 0 (relative to start)
                        // If no moves, reachable sum is only 0.
                        dp_set[OFFSET[15:5]] <= 32'd1 << OFFSET[4:0];
                    end
                end
                
                DP_X_PROC: begin
                    if (proc_idx < move_idx_x) begin
                        signed_move <= moves_x[proc_idx];
                        abs_move <= (moves_x[proc_idx][15]) ? -moves_x[proc_idx] : moves_x[proc_idx];
                        dp_update_done <= 1'b0;
                        dp_idx <= 9'd0;
                    end
                end
                
                DP_Y_START: begin
                    // Initialize DP for Y
                    for (i = 0; i < 501; i = i + 1) begin
                        dp_set[i] <= 32'd0;
                    end
                    proc_idx <= 11'd0;
                    // Y always starts from 0 (no fixed first move)
                    dp_set[OFFSET[15:5]] <= 32'd1 << OFFSET[4:0];
                end
                
                DP_Y_PROC: begin
                    if (proc_idx < move_idx_y) begin
                        signed_move <= moves_y[proc_idx];
                        abs_move <= (moves_y[proc_idx][15]) ? -moves_y[proc_idx] : moves_y[proc_idx];
                        dp_update_done <= 1'b0;
                        dp_idx <= 9'd0;
                    end
                end
                
                CHECK: begin
                    // Check if target bit is set
                    // X check
                    if (target_x >= -MAX_COORD && target_x <= MAX_COORD) begin
                        bit_offset <= target_x + OFFSET;
                    end else begin
                        bit_offset <= 16'hFFFF; // Invalid
                    end
                end
                
                FINISHED: begin
                    done <= 1'b1;
                    // Result set in combinational logic or here
                end
            endcase

            // Bitset Update Logic (Sequential per word or bit)
            // Since we cannot shift a 16001-bit vector efficiently in one cycle,
            // we perform the update over multiple cycles, iterating through the bitset.
            if (state == DP_X_PROC || state == DP_Y_PROC) begin
                if (!dp_update_done) begin
                    // We process one index (dp_idx) per cycle to keep timing feasible.
                    // New_dp[i] = Old_dp[i] | Old_dp[i - move] | Old_dp[i + move]
                    // We need to read from the SAME dp_set array, so we must be careful.
                    // To avoid complex read-after-write issues in a single array,
                    // we will implement a bit-by-bit update logic or use a shadow register.
                    // Here, we iterate through the indices. 
                    // Optimization: We only need to check indices where Old_dp is 1.
                    // But for simplicity in hardware, we iterate all indices in range.
                    
                    // To support OR-shift, we need to access bits at `dp_idx - abs_move` and `dp_idx + abs_move`.
                    // Since we update in place, we should probably use a secondary array or
                    // use a dedicated logic structure. 
                    // Given constraints, we will use a shadow array approach or
                    // simple bit-by-bit update if we assume moves are sparse (but they aren't).
                    // Let's use a shadow array for stability.
                    
                    // Actually, for 16001 bits, we can just use a parallel update logic
                    // synthesized into LUTs. But the prompt implies sequential.
                    // Let's stick to the sequential loop over indices 0 to 16000.
                    // We update the bitset in-place by shifting.
                    // However, in-place shifting is problematic.
                    // We will use a temporary array for the next state.
                    // BUT, the prompt asks for a synthesizable module. 
                    // We will implement a simple loop that iterates through the bitset words.
                    // Wait, we can't iterate 16001 times in one cycle. 
                    // We need `dp_idx` to count cycles.
                    
                    // Current logic: Update bit `dp_idx` based on OLD bitset values.
                    // We need to read bit (dp_idx - move) and (dp_idx + move) from the OLD state.
                    // Since we update dp_set in place, we must save the OLD state before the move processing starts.
                    // However, to save registers, we can just process move by move with a shadow copy.
                    
                    // Let's refine: At state DP_X_PROC, we have a current dp_set (from previous move or init).
                    // We want to produce a new dp_set.
                    // We will iterate `dp_idx` from 0 to 16000.
                    // For each `dp_idx`, we compute the new bit and write it to `dp_set`.
                    // But `dp_set[dp_idx]` might be used later for `dp_idx + move`.
                    // So we must use a separate storage for the next move's result.
                    // Let's use `dp_set_next` array (shadow).
                    // Since we are in a cycle-by-cycle update for the bitset, we need `dp_set_next`.
                end
            end
        end
    end

    // Combinational Logic for DP Update and Next State
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = PARSE;
            end
            
            PARSE: begin
                // Assuming external logic knows when string ends.
                // We'll assume instruction == 0 (null terminator) or testbench stops start.
                // For this specific module, we rely on a fixed length or a separate termination.
                // Since `start` is asserted for 1 cycle, we process the whole string in PARSE state?
                // No, 1 char per cycle.
                // We need a way to know the string is done.
                // Let's assume the testbench sets `instruction` to 0 when done.
                if (instruction == 8'd0) begin
                    next_state = DP_X_START;
                end else begin
                    next_state = PARSE;
                end
            end
            
            DP_X_START: begin
                next_state = DP_X_PROC;
            end
            
            DP_X_PROC: begin
                if (proc_idx >= move_idx_x) begin
                    next_state = DP_Y_START;
                end else if (dp_update_done) begin
                    next_state = DP_X_PROC; // Wait for next move processing to start
                    // Actually, if dp_update_done is high, we increment proc_idx in sequential block?
                    // No, let's control proc_idx here.
                end else begin
                    next_state = DP_X_PROC;
                end
            end
            
            DP_Y_START: begin
                next_state = DP_Y_PROC;
            end
            
            DP_Y_PROC: begin
                if (proc_idx >= move_idx_y) begin
                    next_state = CHECK;
                end else if (dp_update_done) begin
                    next_state = DP_Y_PROC;
                end else begin
                    next_state = DP_Y_PROC;
                end
            end
            
            CHECK: begin
                next_state = FINISHED;
            end
            
            FINISHED: begin
                if (!start) next_state = IDLE;
                else next_state = FINISHED;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // DP Update Logic Implementation
    // We need a shadow bitset to avoid read-after-write hazards during the shift operation.
    reg [31:0] dp_set_next [0:500];
    reg signed [15:0] current_move;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset shadow
            for (i = 0; i < 501; i = i + 1) dp_set_next[i] <= 32'd0;
            dp_update_done <= 1'b0;
            dp_idx <= 9'd0;
        end else begin
            if (state == DP_X_PROC || state == DP_Y_PROC) begin
                if (proc_idx < (state == DP_X_PROC ? move_idx_x : move_idx_y)) begin
                    // We are processing a specific move
                    if (dp_idx == 0) begin
                        // Initialize shadow with current dp_set (before shift)
                        for (i = 0; i < 501; i = i + 1) begin
                            dp_set_next[i] <= dp_set[i];
                        end
                        current_move <= signed_move;
                        dp_idx <= 9'd1; // Start checking from index 1
                        dp_update_done <= 1'b0;
                    end else if (dp_idx <= 16'd16000) begin
                        // Iterate through indices 1 to 16000
                        // For each index i, we set bit i if (old_bit[i-move] == 1 OR old_bit[i+move] == 1)
                        // We read from `dp_set` (old) and write to `dp_set_next`.
                        // Note: `dp_idx` here represents the index we are evaluating.
                        // We need to check bounds: i-move and i+move must be within [0, 16000].
                        
                        // We perform the update bit-by-bit.
                        // This is computationally expensive but synthesizable.
                        // We need to access bits at `dp_idx - abs_move` and `dp_idx + abs_move`.
                        // Wait, `dp_idx` is 9 bits (0-511). We need to iterate up to 16000.
                        // Let's use `dp_idx` as a 15-bit counter actually.
                        // But 15-bit counter in logic is heavy.
                        // Let's optimize: We only care if the bit at `dp_idx` should be set.
                        // It should be set if:
                        // 1. It was already set (OR with old)
                        // 2. Bit at (dp_idx - move) was set
                        // 3. Bit at (dp_idx + move) was set
                        
                        // Since we iterate linearly, we can just check the three conditions.
                        // Accessing arbitrary bits in the array is O(1) with index math.
                        
                        // Check bit at `dp_idx - move`
                        // Check bit at `dp_idx + move`
                        // Check bit at `dp_idx` (from old set)
                        
                        // Optimization: We iterate `dp_idx` from `abs_move` to `16000 - abs_move` for the shift parts.
                        // But let's stick to the simple loop 0 to 16000.
                        
                        // To make this fit in hardware, we might need to reduce the loop iterations.
                        // However, the spec says 16001 bits is feasible.
                        // Let's assume we iterate 16000 times (16000 cycles per move).
                        // With max 4000 moves, this is 64M cycles, which is too slow.
                        // We need parallelism.
                        
                        // CORRECTION: Bitset shifts in hardware are usually parallel.
                        // We can use `dp_set << move` and `dp_set >> move` in Verilog.
                        // This will be synthesized into a barrel shifter or wired logic.
                        // 16001 bits is ~500 32-bit words. Shifting a 500-word array is heavy but doable in FPGA LUTs.
                        // It will take many cycles to complete the shift operation logic-wise in simulation, 
                        // but physically it's combinational.
                        
                        // Given the "sequential DP" instruction, but also "efficient hardware",
                        // let's implement the shift using Verilog array operations.
                        // This is the most hardware-efficient way (parallel shift).
                        
                        // We will skip the manual bit iteration loop and use vector operations.
                        // We handle one move per clock cycle (the shift operation itself takes 1 cycle logic delay).
                        
                        // Logic:
                        // shifted_left = dp_set << move_val
                        // shifted_right = dp_set >> move_val
                        // dp_set_next = dp_set | shifted_left | shifted_right
                        
                        // We must handle bounds (discard bits that shift out of range).
                        // And we must handle the sign of the move (if we treat all moves as positive in the list).
                        // Actually, for Y-axis, moves can be +/-.
                        // But the problem says "set of lengths to be added/subtracted".
                        // So for each length `d`, we do `dp | (dp << d) | (dp >> d)`.
                        // This handles both +d and -d reachable from current set.
                        
                        // Let's implement this parallel shift logic.
                        // We need to be careful with array slicing assignments (not supported in Icarus).
                        // We will use a for-loop to perform the shift word-by-word manually.
                        
                        // However, we are in a sequential block. We can't assign `dp_set_next` based on combinational
                        // shifts of `dp_set` and then assign `dp_set <= dp_set_next` in the same cycle without
                        // creating a combinational loop or timing issue if not careful.
                        // The standard way is: next state logic computes the new values, which are registered.
                        
                        // Let's move the shift logic to a separate combinational block triggered by `state`.
                    end
                end
            end
        end
    end

    // Combinational Shift Logic
    // This block performs the bitset update when state is DP_X_PROC or DP_Y_PROC.
    // We compute `dp_set_next` based on `dp_set` and the current move.
    reg [31:0] shift_left [0:500];
    reg [31:0] shift_right [0:500];
    
    integer w; // word index
    integer b; // bit index
    reg [31:0] temp_word;
    reg [31:0] next_temp_word;
    
    always @(*) begin
        // Default: keep current dp_set
        for (i = 0; i < 501; i = i + 1) begin
            dp_set_next[i] = dp_set[i];
        end
        
        if ((state == DP_X_PROC || state == DP_Y_PROC) && (proc_idx < (state == DP_X_PROC ? move_idx_x : move_idx_y))) begin
            // Perform the shift operations
            // We treat `abs_move` for the shift amount.
            // We need to handle the 16001-bit vector shift.
            
            // Shift Left Logic
            // Bit i becomes bit (i - move) from original
            // Range: move to 16000
            // We iterate words
            
            // Since we cannot use array slicing, we must iterate bits or words.
            // Iterating 16001 bits sequentially in combinational logic is bad (large delay).
            // But for simulation it works. For synthesis, tools will flatten it.
            
            // Let's try a word-based shift with carry propagation.
            // This is complex. 
            
            // Alternative: Use `for` loop to copy bits.
            // We cannot use `dp_set << abs_move` directly on array.
            // But we can define `dp_set` as a single vector if we can't use unpacked arrays.
            // `reg [16000:0] dp_set;` is valid Verilog (though large).
            // The Icarus restriction applies to unpacked arrays (like `dp_set[500]`).
            // A large packed array `[16000:0]` is fine.
            
            // Let's redefine dp_set as a packed vector.
        end
    end

    // REVISION: Using a packed vector for the bitset to enable shift operations
    // and avoid unpacked array issues.
    reg [16000:0] bitset_x;
    reg [16000:0] bitset_y;
    reg [16000:0] active_bitset;
    reg [16000:0] next_bitset;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bitset_x <= 16001'd0;
            bitset_y <= 16001'd0;
            proc_idx <= 11'd0;
            dp_update_done <= 1'b0;
        end else begin
            if (state == DP_X_START) begin
                bitset_x <= 16001'd0;
                if (move_idx_x > 0) begin
                    bitset_x[OFFSET + moves_x[0]] <= 1'b1;
                    proc_idx <= 11'd1;
                end else begin
                    bitset_x[OFFSET] <= 1'b1;
                end
            end else if (state == DP_X_PROC) begin
                if (proc_idx < move_idx_x) begin
                    // Process move
                    // We update bitset_x in place? 
                    // No, we should use a combinational update then register it.
                    // But we are in a sequential block.
                    // Let's use the `next_bitset` logic.
                    // Since `dp_update_done` is single cycle, we assume the shift is fast enough or we just register the result.
                    
                    // Logic: next_bitset = bitset_x | (bitset_x << move) | (bitset_x >> move)
                    // We need to handle signed moves? No, list contains lengths. 
                    // For X, if turn_cnt > 0, moves can be +/-.
                    // Wait, the spec says: "The first move is fixed. Subsequent moves... added/subtracted".
                    // This implies the direction (sign) is chosen.
                    // So for each move `d`, we update: `S_new = S_old + d` or `S_new = S_old - d`.
                    // In bitset terms: `S_new = S_old << d | S_old >> d` (if `d` is magnitude and we support both signs).
                    // If moves list contains signed values, we shift by magnitude.
                    
                    // If `moves_x` stores signed values:
                    // If positive: shift left by val. If negative: shift right by val.
                    // But we want to support *both* additions and subtractions for subsequent moves?
                    // "set of lengths to be added/subtracted" implies we can choose + or - for each move.
                    // So `S_new = S_old + d` OR `S_old - d`.
                    // This is `S_old << d | S_old >> d` (for magnitude `d`).
                    
                    // Let's compute `next_bitset`.
                    // We need to handle the case where `moves_x[proc_idx]` is signed.
                    // But the list stores lengths (magnitudes). 
                    // Actually, the description says "set of lengths".
                    // So we use `abs_move` for the shift amount.
                    
                    // However, for X-axis, the first move direction is fixed (positive X).
                    // Subsequent moves can be +X or -X relative to current facing.
                    // So we allow both directions.
                    
                    // Combinational update:
                    // `next_bitset = active_bitset | (active_bitset << abs_move) | (active_bitset >> abs_move);`
                    // This is a huge combinational path. But we assume FPGA can handle 16001 LUTs.
                    
                    // Wait, we need to be careful with array slicing in combinational logic too.
                    // `bitset_x << abs_move` is valid on a packed vector.
                    
                    // We must truncate to 16001 bits to discard overflow.
                    // `active_bitset` is 16001 bits wide.
                    // `active_bitset << abs_move` generates a wider vector.
                    // We slice it: `[16000:0]`.
                    
                    active_bitset <= (state == DP_X_PROC) ? bitset_x : bitset_y;
                    // Compute next bitset
                    // But we can't assign `next_bitset` inside the `always @(posedge)` block directly from combinational logic without driving a wire.
                    // Let's move the logic to a combinational block.
                    
                    // Instead, let's just perform the assignment directly if we assume it's combinational within the cycle.
                    // This might fail timing for large strings, but logic is correct.
                    
                    if (!dp_update_done) begin
                        // We need to handle the shift carefully to avoid wide vectors.
                        // 16001 bit shift is large but valid.
                        
                        // We update the bitset.
                        // We need to capture the current bitset before the update to avoid reading/writing same cycle issues if we do it blockingly.
                        // Since this is sequential logic, we are registering the result. 
                        // The expression `active_bitset | (active_bitset << abs_move)` is evaluated on the previous cycle's value (if we use non-blocking <= correctly, though standard practice is combinational block for complex logic).
                        
                        // Let's do this:
                        // We will compute the update in a separate combinational `always @(*)` block.
                        // But for simplicity and to keep it in one block (since we can't rely on `automatic` logic for `always @(*)` with large loops in Icarus):
                        
                        // We will skip the intermediate block and just register the result of the shift.
                        // This implies the shift logic is part of the previous cycle's computation.
                        // To make it work, we assume the move is available.
                        
                        // Actually, the safest way for Icarus is to use a for-loop to perform the shift manually on the bitset.
                        // But `active_bitset << abs_move` is standard Verilog.
                        
                        // Let's try: Update the bitset in place over multiple cycles? No, that's slow.
                        // Let's do: one move per cycle, combinational shift, registered output.
                        
                        // We need to declare `abs_move` as a parameter-like constant or variable for the shift.
                        // `abs_move` is 16 bits. Shift amount in Verilog can be variable.
                        
                        // We need to handle the fact that `active_bitset` might be `bitset_x` or `bitset_y`.
                        // We can use a wire for the computation.
                    end
                    dp_update_done <= 1'b1; // Done processing this move in this cycle
                    proc_idx <= proc_idx + 11'd1;
                end
            end
            // Similar for Y
        end
    end

    // Combinational Update Logic
    wire [16000:0] next_x;
    wire [16000:0] next_y;
    
    // Helper function for absolute value
    function [15:0] abs_val;
        input signed [15:0] val;
        abs_val = (val < 0) ? -val : val;
    endfunction

    always @(*) begin
        // Default: keep current
        next_x = bitset_x;
        next_y = bitset_y;
        
        if (state == DP_X_PROC && proc_idx < move_idx_x && !dp_update_done) begin
            // Compute new bitset for X
            // Note: `moves_x` is stored as signed, but we treat them as magnitudes for the shift (since we allow +/-)
            // However, the first move in X is fixed direction.
            // If `proc_idx == 0` (first move), we handled initialization in DP_X_START.
            // So here we process subsequent moves.
            // For X, if `turn_cnt > 0`, moves can be added or subtracted.
            // Wait, if `turn_cnt == 0`, the robot faces +X. First move is +X.
            // The spec says: "The first move (if starting with 'F') is fixed."
            // So for X-axis, if `turn_cnt == 0`, the first move is always positive (right shift? no, left shift for positive sum).
            // Let's assume `moves_x` stores the magnitude. 
            // Actually, for X-axis, subsequent moves can be + or -.
            // So we use `abs_move`.
            
            // We need to get the move value. `signed_move` is available in the sequential block.
            // We need to pass it to combinational logic.
            // We can use a `reg` that holds the current move value, updated when we enter a new move.
        end
    end
    
    // To properly implement the combinational update, we need to trigger it when `signed_move` changes.
    // Since we are in a big FSM, let's just do the shift inline using a function or wire assignment.
    
    // We will use a wire for the shift result.
    // We need to handle the wide vector shift.
    
    // Since we are restricted by Icarus, let's try to minimize vector width usage.
    // We can use 500 32-bit words.
    // Shift left by D: 
    // Word i receives bits from word (i - D/32) and (i - D/32 - 1).
    // This is manual barrel shifting.
    // Given the complexity, we will use the packed vector approach and hope Icarus handles 16001 bit vectors.
    // Modern Verilog parsers (like Yosys) handle this fine.

    // Re-defining the update logic properly in the sequential block to avoid multi-driver issues.
    // We will compute the next bitset and register it.
    
    reg [16000:0] current_bs;
    reg [15:0] move_amount;
    
    always @(*) begin
        // Determine which bitset is active
        if (state == DP_X_PROC) begin
            current_bs = bitset_x;
            // If first move, we shouldn't be here (we start at proc_idx=1)
            // If not first move, we allow +/-
            // move_amount = abs_val(moves_x[proc_idx]);
            // But we need to access `moves_x` from combinational logic.
            // `moves_x` is a register array. Access is synchronous? No, it's static.
            // Accessing `moves_x[proc_idx]` is combinational read (assuming no clock enable).
            move_amount = abs_val(moves_x[proc_idx]);
        end else if (state == DP_Y_PROC) begin
            current_bs = bitset_y;
            move_amount = abs_val(moves_y[proc_idx]);
        end else begin
            current_bs = 0;
            move_amount = 0;
        end
        
        // Compute shifted versions
        // We must handle the case where shift amount > 16000 (should be 0)
        // But max move length is limited by string length (8000), so shift amount <= 8000.
        
        // To prevent huge vector creation in simulation, we slice explicitly.
        // `current_bs << move_amount` creates a vector of size 16001 + move_amount.
        // We slice [16000:0].
        
        // Note: Verilog shift operators on variable amounts are supported.
        
        // However, we must ensure we don't index out of bounds.
        // If `proc_idx` is out of range, we don't update.
        
        // We need to update `next_bitset` in the sequential block.
    end

    // Actually, let's simplify the shift logic for synthesis and Icarus compatibility.
    // We will update the bitset over MULTIPLE cycles, bit-by-bit.
    // This avoids the massive combinational path and is very FPGA friendly (using shift registers logic).
    // Since we have `dp_idx` counter in the sequential block, let's use it.
    
    // Revised DP Update Logic in Sequential Block:
    // When entering DP_X_PROC for a new move:
    // 1. Copy `bitset_x` to `dp_set_next` (shadow).
    // 2. Iterate `dp_idx` from `move_amount` to `16000 - move_amount`.
    // 3. In each cycle, check if `bitset_x[dp_idx - move_amount]` OR `bitset_x[dp_idx + move_amount]` is 1.
    // 4. If so, set `dp_set_next[dp_idx] = 1`. (Or OR it in).
    // 5. After iterating all indices, update `bitset_x = dp_set_next`.
    // 
    // Wait, this logic is flawed because `bitset_x` is the OLD state.
    // We need to read from OLD and write to NEW (shadow).
    // We already have `dp_set_next` logic.
    // We need to iterate `dp_idx` from 0 to 16000.
    
    // Let's use the `dp_idx` counter we defined earlier (9-bit was too small, need 15-bit).
    // Let's use a 16-bit `dp_idx` (0 to 16000).
    
    reg [15:0] dp_idx_16;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bitset_x <= 0;
            bitset_y <= 0;
            dp_idx_16 <= 0;
            proc_idx <= 0;
            dp_update_done <= 0;
        end else begin
            if (state == DP_X_START) begin
                bitset_x <= 0;
                if (move_idx_x > 0) begin
                    bitset_x[OFFSET + moves_x[0]] <= 1'b1;
                    proc_idx <= 11'd1;
                end else begin
                    bitset_x[OFFSET] <= 1'b1;
                end
            end else if (state == DP_X_PROC) begin
                if (proc_idx < move_idx_x) begin
                    if (dp_idx_16 == 0) begin
                        // Start of new move processing
                        // Initialize shadow with OLD bitset
                        // We need a shadow array. Let's reuse `dp_set_next` (32-bit words) or declare a shadow bitset.
                        // Let's declare `shadow_bitset` as `reg [16000:0]`.
                        // We copy `bitset_x` to `shadow_bitset`.
                        // But copying 16001 bits takes 1 cycle or we just read from `bitset_x` directly during update.
                        // If we read from `bitset_x` and write to `shadow_bitset`, we are safe.
                        // We will write to `shadow_bitset`.
                        
                        // However, `shadow_bitset` needs to be initialized to `bitset_x` before we start modifying it.
                        // We can't modify it bit-by-bit because we need to read from the ORIGINAL `bitset_x`.
                        // So `shadow_bitset` starts as `bitset_x`. Then we OR in the shifted bits.
                        // Wait, `bitset_x << move` produces a NEW set. We want `bitset_x | (bitset_x << move) | (bitset_x >> move)`.
                        // So `shadow_bitset` should be initialized to `bitset_x`.
                        // Then we iterate `i` and if `bitset_x[i]` is 1, we set `shadow_bitset[i + move]` and `shadow_bitset[i - move]`.
                        // This is sparse update. We can't iterate all 16001 indices to find 1s efficiently without a priority encoder.
                        // So we iterate all 16001 indices.
                        // For each `i` in 0..16000:
                        // `shadow_bitset[i]` should be 1 if:
                        // 1. `bitset_x[i]` was 1 (already copied)
                        // 2. `bitset_x[i - move]` was 1
                        // 3. `bitset_x[i + move]` was 1
                        
                        // We can update `shadow_bitset` in place if we iterate in a specific order?
                        // No, because we read from `bitset_x` (old) and write to `bitset_x` (new).
                        // So we need to keep `bitset_x` untouched until the move is fully processed.
                        // We will use `shadow_bitset` as a temporary storage.
                        // We will iterate `dp_idx_16` from 0 to 16000.
                        // In each cycle, we evaluate the condition for `dp_idx_16` and set a bit in `shadow_bitset`.
                        // 
                        // To save area, we can just use `bitset_x` as the OLD storage and `bitset_y` or some other register as NEW storage?
                        // Or we can use a single `dp_set` array (packed) and a `next_dp_set` (packed).
                        // Let's use `bitset_x` as OLD and `next_bitset_x` as NEW.
                        // We initialize `next_bitset_x` to `bitset_x`.
                        // Then iterate. 
                        // But `next_bitset_x` is a vector. We can't assign it element-wise easily in a loop without unpacking.
                        // We can do: `next_bitset_x[i] = bitset_x[i] | bitset_x[i-move] | bitset_x[i+move];`
                        // This requires unpacking or using bit-select on the vector.
                        // `next_bitset_x[i]` is valid.
                        
                        // So, we need `next_bitset_x` (packed vector).
                        // Initialize `next_bitset_x = bitset_x`.
                        // Loop `i` 0 to 16000:
                        // `next_bitset_x[i] = next_bitset_x[i] | bitset_x[i-move] | bitset_x[i+move];` (Using next_bitset_x for accumulated OR is okay if we iterate forward).
                        // Actually, `bitset_x[i-move]` refers to the OLD state. We should use `bitset_x` explicitly.
                        // 
                        // This loop takes 16001 cycles. With 4000 moves, that's 64M cycles. Too slow.
                        // We need to parallelize.
                        // 
                        // Let's go back to the combinational shift.
                        // `next_bitset_x = bitset_x | (bitset_x << move) | (bitset_x >> move);`
                        // This is the standard hardware implementation.
                        // We will compute this in combinational logic and register it.
                        // To avoid timing issues, we assume the move processing takes 1 cycle (the shift logic is combinational).
                        // Since the bitset is large, we might need multiple pipeline stages or just accept the long critical path.
                        // For this exercise, we assume the target FPGA can handle the 16001-bit shift in 1 cycle (using LUTs).
                        
                        // So, we don't need the loop over `dp_idx_16`.
                        // We just need to compute the shift combinationaly and register it.
                        // We need a combinational block that computes `next_bitset_x`.
                        // And we need to trigger it when `proc_idx` increments.
                        // 
                        // We will update `bitset_x <= next_bitset_x` when we finish processing a move.
                        // But `next_bitset_x` depends on `move_val`.
                        // 
                        // Let's implement the combinational shift logic using a separate `always @(*)` block.
                        // Since we can't use unpacked arrays in combinational blocks easily (Icarus issues), we use packed vectors.
                        // 
                        // Wait, `moves_x` is an unpacked array. We can't access it in combinational block easily.
                        // We must pass the move value to the combinational block via a register (`current_move_reg`).
                        
                        // Let's stick to the sequential update but make it faster.
                        // We can update 32 bits per cycle (one word of the bitset).
                        // We have 501 words.
                        // For each word `w`, we compute `new_word` based on `old_word` and neighbors.
                        // Shift left/right by `move` bits affects word boundaries.
                        // This is getting very complex for a "simple" answer.
                        // 
                        // Given the constraints, the most robust way for Icarus is:
                        // 1. Use packed vectors for bitsets.
                        // 2. Use a combinational block for the shift update.
                        // 3. Use a register to hold the current move value.
                        
                        // We will output the combinational logic in the `always @(*)` block below.
                        // And the sequential block will register the result.
                    end
                end
            end
        end
    end

    // Combinational Logic for Shift Update
    reg [16000:0] next_bs_x;
    reg [16000:0] next_bs_y;
    reg [15:0] current_move_val;
    
    always @(*) begin
        // Default assignments
        next_bs_x = bitset_x;
        next_bs_y = bitset_y;
        
        // Extract current move value safely
        if (state == DP_X_PROC && proc_idx < move_idx_x) begin
            // For X, if proc_idx > 0, moves are +/-.
            // If proc_idx == 0, it was handled in start (fixed direction).
            // But `proc_idx` starts at 1 after start (if first move existed).
            // So we always use magnitude for the shift logic.
            current_move_val = abs_val(moves_x[proc_idx]);
            
            // We must ensure we don't shift if move is 0
            if (current_move_val > 0 && current_move_val <= 16000) begin
                // Perform shift
                // We need to handle the wide vector shift.
                // `bitset_x << current_move_val` produces a vector of width 16001 + current_move_val.
                // We slice it to [16000:0].
                
                // Note: Verilog semantics: if shift amount > vector width, result is 0.
                // 
                // We compute: new = old | (old << move) | (old >> move)
                // We must truncate the shifted vectors to 16001 bits.
                
                next_bs_x = bitset_x | 
                           (bitset_x << current_move_val) | 
                           (bitset_x >> current_move_val);
                           // The result of shift is wider, but implicit truncation happens on assignment to 16000:0.
            end
        end
        
        if (state == DP_Y_PROC && proc_idx < move_idx_y) begin
            current_move_val = abs_val(moves_y[proc_idx]);
            if (current_move_val > 0 && current_move_val <= 16000) begin
                next_bs_y = bitset_y | 
                           (bitset_y << current_move_val) | 
                           (bitset_y >> current_move_val);
            end
        end
    end

    // Final Update in Sequential Block
    // We need to register the new bitset when the move processing is done.
    // We assumed 1 cycle per move. 
    // We need to sync `dp_update_done` with this.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset handled above
        end else begin
            if (state == DP_X_PROC && proc_idx < move_idx_x) begin
                // Register the new bitset
                bitset_x <= next_bs_x;
                dp_update_done <= 1'b1; // Signal we finished this move
                proc_idx <= proc_idx + 11'd1;
            end else if (state == DP_Y_PROC && proc_idx < move_idx_y) begin
                bitset_y <= next_bs_y;
                dp_update_done <= 1'b1;
                proc_idx <= proc_idx + 11'd1;
            end else begin
                dp_update_done <= 1'b0;
            end
        end
    end

    // Result checking
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 1'b0;
        end else if (state == CHECK) begin
            // Check X
            if (target_x >= -8000 && target_x <= 8000) begin
                if (bitset_x[OFFSET + target_x] == 1'b1) begin
                    // Check Y
                    if (target_y >= -8000 && target_y <= 8000) begin
                        if (bitset_y[OFFSET + target_y] == 1'b1) begin
                            result <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                    end else begin
                        result <= 1'b0;
                    end
                end else begin
                    result <= 1'b0;
                end
            end else begin
                result <= 1'b0;
            end
        end
    end

endmodule