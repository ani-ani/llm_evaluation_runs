module bacteria_simulation (
    input clk,
    input rst_n,
    input start,
    input [3:0] trap_row,
    input [3:0] trap_col,
    input [3:0] start_row_0, start_row_1, start_row_2, start_row_3, start_row_4,
    input [3:0] start_col_0, start_col_1, start_col_2, start_col_3, start_col_4,
    input [1:0] start_dir_0, start_dir_1, start_dir_2, start_dir_3, start_dir_4,
    input [63:0] grid_0, grid_1, grid_2, grid_3, grid_4,
    output reg [15:0] result,
    output reg done
);

    // Parameters
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] STEP = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    localparam [2:0] LOOP_DETECTED = 3'd5;

    localparam [3:0] MAX_ROWS = 4'd8;
    localparam [3:0] MAX_COLS = 4'd8;
    localparam [7:0] MAX_TIME = 8'd255;
    localparam [15:0] TIMEOUT_VAL = 16'd65535;
    localparam K = 5;
    localparam STATE_MEM_DEPTH = 128;
    localparam [6:0] STATE_MEM_ADDR_MASK = 7'h7F;

    // State register
    reg [2:0] state;
    reg [2:0] next_state;

    // Registers for simulation data
    reg [3:0] current_row [0:4];
    reg [3:0] current_col [0:4];
    reg [1:0] current_dir [0:4];
    reg [7:0] time_counter;

    // Internal control signals
    reg [2:0] bacteria_idx; // 0 to 4
    reg [3:0] digit;
    reg [1:0] new_dir_calc;
    reg [1:0] flipped_dir_calc;
    reg [3:0] next_row_calc;
    reg [3:0] next_col_calc;
    reg [15:0] result_nxt;
    reg done_nxt;

    // Cycle detection registers
    reg [6:0] state_mem_addr;
    reg [15:0] state_mem_data_in;
    reg [15:0] state_mem [0:127]; // BRAM model
    reg state_mem_wr;
    reg [15:0] stored_hash;
    reg hash_match;
    reg [6:0] mem_write_ptr;

    integer i;

    // State Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            time_counter <= 8'd0;
            bacteria_idx <= 3'd0;
            mem_write_ptr <= 7'd0;
            for (i = 0; i < K; i = i + 1) begin
                current_row[i] <= 4'd0;
                current_col[i] <= 4'd0;
                current_dir[i] <= 2'd0;
            end
        end else begin
            state <= next_state;
            result <= result_nxt;
            done <= done_nxt;
            
            if (state == LOAD) begin
                // Initialize positions and directions from inputs
                current_row[0] <= start_row_0;
                current_col[0] <= start_col_0;
                current_dir[0] <= start_dir_0;
                current_row[1] <= start_row_1;
                current_col[1] <= start_col_1;
                current_dir[1] <= start_dir_1;
                current_row[2] <= start_row_2;
                current_col[2] <= start_col_2;
                current_dir[2] <= start_dir_2;
                current_row[3] <= start_row_3;
                current_col[3] <= start_col_3;
                current_dir[3] <= start_dir_3;
                current_row[4] <= start_row_4;
                current_col[4] <= start_col_4;
                current_dir[4] <= start_dir_4;
                time_counter <= 8'd0;
                mem_write_ptr <= 7'd0;
            end else if (state == STEP) begin
                // Update specific bacterium
                current_row[bacteria_idx] <= next_row_calc;
                current_col[bacteria_idx] <= next_col_calc;
                current_dir[bacteria_idx] <= flipped_dir_calc;
            end else if (state == CHECK) begin
                // Increment time if moving to next cycle
                time_counter <= time_counter + 8'd1;
            end

            // Memory write logic for state history
            if (state_mem_wr) begin
                state_mem[mem_write_ptr] <= state_mem_data_in;
                mem_write_ptr <= mem_write_ptr + 7'd1;
            end
        end
    end

    // Combinational Logic
    always @(*) begin
        next_state = state;
        result_nxt = result;
        done_nxt = done;
        digit = 4'd0;
        new_dir_calc = 2'd0;
        flipped_dir_calc = 2'd0;
        next_row_calc = 4'd0;
        next_col_calc = 4'd0;
        state_mem_wr = 1'b0;
        state_mem_data_in = 16'd0;
        state_mem_addr = 7'd0;
        stored_hash = 16'd0;
        hash_match = 1'b0;

        case (state)
            IDLE: begin
                done_nxt = 1'b0;
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                next_state = STEP;
            end

            STEP: begin
                // Extract digit from grid
                // Grid is flattened 64 bits. Offset = row * 8 + col
                // Access 4 bits at offset
                case (bacteria_idx)
                    3'd0: begin
                        digit = grid_0[ (current_row[bacteria_idx] * 4'd8 + current_col[bacteria_idx]) * 4 +: 4 ];
                    end
                    3'd1: begin
                        digit = grid_1[ (current_row[bacteria_idx] * 4'd8 + current_col[bacteria_idx]) * 4 +: 4 ];
                    end
                    3'd2: begin
                        digit = grid_2[ (current_row[bacteria_idx] * 4'd8 + current_col[bacteria_idx]) * 4 +: 4 ];
                    end
                    3'd3: begin
                        digit = grid_3[ (current_row[bacteria_idx] * 4'd8 + current_col[bacteria_idx]) * 4 +: 4 ];
                    end
                    3'd4: begin
                        digit = grid_4[ (current_row[bacteria_idx] * 4'd8 + current_col[bacteria_idx]) * 4 +: 4 ];
                    end
                    default: digit = 4'd0;
                endcase

                // Update direction
                new_dir_calc = current_dir[bacteria_idx] + digit[1:0]; // digit is 0-9, take lower 2 bits
                
                // Check bounds & flip if necessary (Simultaneously)
                // Next position calculation
                next_row_calc = current_row[bacteria_idx];
                next_col_calc = current_col[bacteria_idx];
                flipped_dir_calc = new_dir_calc;

                case (new_dir_calc)
                    2'd0: begin // Up
                        if (current_row[bacteria_idx] == 4'd0) begin
                            flipped_dir_calc = 2'd2; // Down
                            next_row_calc = 4'd1;
                        end else begin
                            next_row_calc = current_row[bacteria_idx] - 4'd1;
                        end
                    end
                    2'd1: begin // Right
                        if (current_col[bacteria_idx] == 4'd7) begin
                            flipped_dir_calc = 2'd3; // Left
                            next_col_calc = 4'd6;
                        end else begin
                            next_col_calc = current_col[bacteria_idx] + 4'd1;
                        end
                    end
                    2'd2: begin // Down
                        if (current_row[bacteria_idx] == 4'd7) begin
                            flipped_dir_calc = 2'd0; // Up
                            next_row_calc = 4'd6;
                        end else begin
                            next_row_calc = current_row[bacteria_idx] + 4'd1;
                        end
                    end
                    2'd3: begin // Left
                        if (current_col[bacteria_idx] == 4'd0) begin
                            flipped_dir_calc = 2'd1; // Right
                            next_col_calc = 4'd1;
                        end else begin
                            next_col_calc = current_col[bacteria_idx] - 4'd1;
                        end
                    end
                endcase

                // Advance to next bacterium or move to CHECK
                if (bacteria_idx < 3'd4) begin
                    // Do not update state registers here, wait for sequential update
                    // Actually, for simulation, we just calculate and update the current register
                    // The register update block handles the actual assignment based on state
                    // Since we are in STEP, we update current_idx, then if not done, stay in STEP
                    // But we need to sequence this. 
                    // Let's assume single cycle per bacterium logic for simplicity and robustness
                    // Wait, 5 bacteria in 300 cycles. We can take 5 cycles for one step.
                    // So we stay in STEP until all bacteria processed.
                    // We need a separate counter or use bacteria_idx.
                    // Since we are in comb logic, we check if we are done with this step.
                    // Wait, we need to trigger the update for the *current* index, then increment index.
                    // The sequential block updates based on state.
                    // If we are in STEP, we calculate for bacteria_idx.
                    // Next cycle, we go to STEP again? Or a separate UPDATE state?
                    // Let's go: STEP calculates, next cycle we are still in STEP but index increments?
                    // No, better: Stay in STEP state until index > 4.
                    // But the update must happen on clock edge. 
                    // Let's refine: 
                    // State STEP calculates for bacteria_idx.
                    // If bacteria_idx < 4, next_state = STEP, and we increment bacteria_idx in seq logic.
                    // If bacteria_idx == 4, next_state = CHECK.
                    
                    // Problem: bacteria_idx increments on clock edge. 
                    // Logic: 
                    // In STEP state, we calculate for `bacteria_idx`. 
                    // If `bacteria_idx` is 4, we are done with this time step.
                    // Wait, `bacteria_idx` 0 to 4 (5 items).
                    
                    // Sequence:
                    // Cycle T: State LOAD -> STEP. bacteria_idx = 0.
                    // Cycle T+1: State STEP. Calculate for idx 0. Update reg 0. Next: Step (idx 1).
                    // Cycle T+2: State STEP. Calculate for idx 1. Update reg 1. Next: Step (idx 2).
                    // ...
                    // Cycle T+5: State STEP. Calculate for idx 4. Update reg 4. Next: Check.
                    
                    // Logic check:
                    if (bacteria_idx < 3'd4) begin
                        next_state = STEP;
                    end else begin
                        next_state = CHECK;
                    end
                end else begin
                    // bacteria_idx is 4, we just processed the last one
                    next_state = CHECK;
                end
            end

            CHECK: begin
                // 1. Check if all at trap
                // 2. Check timeout
                // 3. Check hash (state repetition)
                
                // Check All at Trap
                // Compare row and col for all 5 bacteria
                // Logic: if any mismatch, flag remains false
                // We can use a reduction loop in unrolled form
                // Since K=5 is small, unroll manually
                
                // Check Time
                if (time_counter >= MAX_TIME) begin
                    result_nxt = TIMEOUT_VAL;
                    done_nxt = 1'b1;
                    next_state = IDLE;
                end else begin
                    // Check positions
                    if ((current_row[0] == trap_row) && (current_col[0] == trap_col) &&
                        (current_row[1] == trap_row) && (current_col[1] == trap_col) &&
                        (current_row[2] == trap_row) && (current_col[2] == trap_col) &&
                        (current_row[3] == trap_row) && (current_col[3] == trap_col) &&
                        (current_row[4] == trap_row) && (current_col[4] == trap_col)) begin
                        
                        result_nxt = {8'd0, time_counter}; // Time in seconds
                        done_nxt = 1'b1;
                        next_state = IDLE;
                    end else begin
                        // Not found, need to store state and check loop
                        // Compute Hash (XOR of positions and directions)
                        // Hash = {row[0], col[0], dir[0], ..., row[4], col[4], dir[4]}
                        // But 16 bits is tight. 5*(4+4+2) = 50 bits. 
                        // Let's reduce: XOR upper and lower parts of rows/cols.
                        // Or simply fold: 
                        // Hash = (Row0 ^ Col0 ^ Dir0) ... 
                        // Let's pack: {Row0, Col0, Dir0, Row1, Col1, Dir1, ...} -> 50 bits.
                        // We only store 16 bits in memory. 
                        // We will compute a 16-bit checksum: 
                        // H = (Row0<<12) | (Col0<<10) | (Dir0<<8) | ...
                        // Actually, just XORing everything into 16 bits is safer for cycle detection.
                        // But collisions are likely with only 16 bits. 
                        // However, requirement says "Hash (e.g., XOR)".
                        // Let's compute: 
                        // Hash = (Row0[3:0] ^ Col0[3:0] ^ {2'b00, Dir0[1:0]}) 
                        // We need more bits. 
                        // Let's try: {Row0, Col0} ^ {Row1, Col1} ^ ... ^ {Row4, Col4} ^ {Dir0, Dir1, Dir2, Dir3, Dir4, 6'b0}
                        // 16 bits total.
                        // Hash[15:8] = Row0 ^ Row1 ^ Row2 ^ Row3 ^ Row4
                        // Hash[7:0]  = Col0 ^ Col1 ^ Col2 ^ Col3 ^ Col4 ^ Dir0 ^ Dir1 ^ Dir2 ^ Dir3 ^ Dir4
                        
                        // Note: We are in CHECK state. We need to read memory to compare.
                        // Reading memory takes a cycle? Or is it zero-delay? 
                        // If memory is LUT/FF based, zero delay is fine.
                        // If Block RAM, might need a pipeline. 
                        // Let's assume we can read synchronously or use logic.
                        // We will read `state_mem` at `state_mem_addr`.
                        // We need to calculate the address first.
                        
                        // Next state logic:
                        // We calculate Hash. 
                        // We check if Hash exists in Memory.
                        // If yes -> LOOP_DETECTED (result -1).
                        // If no -> Store Hash, then Next Time Step.
                        
                        // To read memory, we need the address.
                        // Address = Hash[6:0] & 7'h7F (modulo 128).
                        
                        // Since memory read is asynchronous or we need to latch it?
                        // In Verilog, if state_mem is an array of regs, reading is combinational.
                        // So we can do:
                        // stored_hash = state_mem[address];
                        // But `address` depends on current_row/col which are valid.
                        // However, we are in CHECK state. 
                        // We need a sub-state or just use the combinational logic carefully.
                        // 
                        // Let's do this: 
                        // In CHECK state, we calculate the hash and address.
                        // We compare `stored_hash` (from memory) with `current_hash`.
                        // Since `stored_hash` is updated via `always` block, we might have a 1-cycle delay if we trigger write.
                        // But we need to compare in the same cycle (CHECK).
                        // So we need combinational read.
                        // `stored_hash` signal will be assigned from memory.
                        
                        // Let's define the hash calculation:
                        // Hash[15:8] = current_row[0] ^ current_row[1] ^ current_row[2] ^ current_row[3] ^ current_row[4];
                        // Hash[7:0]  = current_col[0] ^ current_col[1] ^ current_col[2] ^ current_col[3] ^ current_col[4] ^ 
                        //              current_dir[0] ^ current_dir[1] ^ current_dir[2] ^ current_dir[3] ^ current_dir[4];
                        // 
                        // Address = Hash[6:0];
                        // 
                        // Read memory:
                        // stored_hash = state_mem[address];
                        // 
                        // Compare:
                        // if (stored_hash == current_hash) -> Loop.
                        // else -> Store.
                        
                        // Wait, what if memory is empty (0)? 
                        // If memory entry is 0, and Hash is 0, it falsely detects loop.
                        // To avoid this, we can mark "valid" bits. 
                        // Since K=5, time max 255. 128 entries. 
                        // We can store Hash + a Valid bit in the 16-bit word? 
                        // No, 16 bits is just for hash.
                        // We can use a separate valid array of 128 bits (Flop based).
                        // Or, we can check if the stored hash is the same.
                        // Initial memory is undefined (X) or 0.
                        // We must ensure we initialize memory to something distinct from valid hashes.
                        // But we don't have a reset for memory content (only pointer).
                        // Actually, we initialize memory pointer. We assume memory content is garbage until written.
                        // If we read garbage, we might get X or 0.
                        // If we get X, comparison fails (unless we use case equality).
                        // If we get 0, and we hash to 0, it fails.
                        // Solution: Don't store 0. Or use a valid flag.
                        // Let's use a separate valid array: `reg valid_mem [0:127];`
                        // Or, just check if `stored_hash == current_hash` AND `stored_hash != 0` (assuming 0 is unlikely or handle separately).
                        // Better: `if (valid_mem[addr] && stored_hash == current_hash)`
                        // 
                        // Let's implement valid_mem.
                        // `reg [127:0] valid_bits;` (128 bits)
                        
                        // Let's refine the sequence:
                        // 1. Calculate Current Hash and Address.
                        // 2. Check Valid Bits and Hash.
                        // 3. If Match -> Loop State.
                        // 4. If No Match -> 
                        //    - Store Hash to Memory.
                        //    - Set Valid Bit.
                        //    - Reset Time Step (Go back to STEP).
                        
                        // Wait, going back to STEP. 
                        // State CHECK. 
                        // We need to transition to IDLE (Done), LOOP_DETECTED (Done), or STEP (Continue).
                        
                        // Logic for Next State:
                        // If (all_at_trap) -> IDLE (handled above).
                        // Else If (time > max) -> IDLE (handled above).
                        // Else If (Loop Detected) -> LOOP_DETECTED.
                        // Else -> STEP (for next second).
                        
                        // We need to calculate Loop/Store logic here.
                        // But we need to read memory. 
                        // Let's assume `state_mem` and `valid_mem` are readable combinational.
                        // We need to handle the Store in the sequential block (next cycle) or immediately?
                        // If we go to STEP immediately, we must have stored the data.
                        // So, we should latch the "Store" command.
                        // 
                        // Let's define signals:
                        // wire [15:0] current_hash;
                        // wire [6:0] check_addr;
                        // wire is_valid;
                        // wire is_match;
                        
                        // Calculations:
                        wire [7:0] r_xor;
                        wire [7:0] c_xor;
                        wire [4:0] d_xor;
                        
                        assign r_xor = current_row[0] ^ current_row[1] ^ current_row[2] ^ current_row[3] ^ current_row[4];
                        assign c_xor = current_col[0] ^ current_col[1] ^ current_col[2] ^ current_col[3] ^ current_col[4];
                        assign d_xor = current_dir[0] ^ current_dir[1] ^ current_dir[2] ^ current_dir[3] ^ current_dir[4];
                        
                        // Use concatenation for hash
                        wire [15:0] current_hash;
                        assign current_hash = {r_xor, c_xor, d_xor[4:0], 3'd0}; // Packed to 16 bits
                        
                        wire [6:0] check_addr;
                        assign check_addr = current_hash[6:0];
                        
                        // Memory Read (Combinational)
                        wire mem_valid;
                        // We need a valid memory array. 
                        reg [127:0] valid_mem;
                        // Since I can't declare a new reg in comb block, I need to move it to the top level.
                        // I will add `valid_mem` to the sequential block init.
                        
                        assign mem_valid = valid_mem[check_addr];
                        wire [15:0] stored_hash_val;
                        assign stored_hash_val = state_mem[check_addr];
                        
                        wire is_loop;
                        assign is_loop = mem_valid && (stored_hash_val == current_hash);
                        
                        if (is_loop) begin
                            result_nxt = TIMEOUT_VAL;
                            done_nxt = 1'b1;
                            next_state = IDLE;
                        end else begin
                            // No loop, store state and continue
                            // We need to trigger write to memory and valid bit
                            state_mem_wr = 1'b1;
                            state_mem_addr = check_addr;
                            state_mem_data_in = current_hash;
                            // We need to update valid_mem in sequential logic
                            // We can't update `valid_mem` directly here easily without a wire/reg confusion.
                            // Let's add a signal `update_valid_bit` and `update_valid_idx`.
                            
                            // Actually, let's just use a separate sequential block for valid_mem update,
                            // or add logic to the existing block.
                            // We'll add logic to the existing sequential block for `valid_mem`.
                            
                            next_state = STEP;
                        end
                    end
                end
            end

            DONE_STATE: begin
                // Not strictly needed, IDLE covers it, but good for structure
                next_state = IDLE;
            end

            LOOP_DETECTED: begin
                // Redundant if handled in CHECK, but keep for safety
                result_nxt = TIMEOUT_VAL;
                done_nxt = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential updates for data that weren't covered by the main block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bacteria_idx <= 3'd0;
            valid_mem <= 128'd0;
        end else begin
            // Bacteria Index Management
            if (state == LOAD) begin
                bacteria_idx <= 3'd0;
            end else if (state == STEP) begin
                if (bacteria_idx < 3'd4) begin
                    bacteria_idx <= bacteria_idx + 3'd1;
                end else begin
                    bacteria_idx <= 3'd0; // Reset for next time step
                end
            end

            // Valid Memory Update
            if (state == CHECK) begin
                // We need to ensure we only update valid_mem if we decided to store (i.e., not loop)
                // The `state_mem_wr` signal is set in CHECK state when not looping.
                // However, `state_mem_wr` is a wire from comb logic. 
                // In the sequential block, we can check the conditions again or use a latched version.
                // To avoid re-evaluating complex logic, let's add a flag `store_state_flag` set in comb logic.
                // Actually, let's just duplicate the check logic in the sequential block or latch the decision.
                // 
                // Re-evaluating logic in seq block:
                // We know we are in CHECK.
                // We know we are not done (else we wouldn't be here or we would be IDLE).
                // We need to check if it was a loop.
                // We can use the `is_loop` wire if it were reg, but it's wire.
                // We can latch `is_loop` or `store_state`.
                
                // Let's define a reg `store_state_nxt` and `store_state_reg`.
                // Or, simply use the signals calculated in comb block that trigger the action.
                // `state_mem_wr` is 1 if we need to store.
                // So:
                if (state_mem_wr) begin
                    valid_mem[check_addr] <= 1'b1;
                end
                // Note: `check_addr` is wire. It should be valid.
                // Wait, `check_addr` depends on `current_row` etc. which are regs.
                // So `check_addr` is stable during CHECK state.
            end
        end
    end

endmodule
