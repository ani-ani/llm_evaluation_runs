module max_xor_subset(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_count,
    input [31:0] data_in,
    input data_valid,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam COLLECT = 3'b001;
    localparam BUILD_BASIS = 3'b010;
    localparam MAXIMIZE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [2:0] state_next;

    // Buffer for input numbers
    reg [31:0] buffer [0:7];
    reg [2:0] write_ptr;
    reg [2:0] read_ptr;
    reg [2:0] count_reg;

    // Basis array (up to 8 vectors)
    reg [31:0] basis [0:7];
    reg [2:0] basis_count;
    reg [2:0] basis_idx;
    reg [2:0] basis_idx_next;

    // Temporary variables for Gaussian elimination
    reg [31:0] temp_num;
    reg [31:0] temp_num_next;
    reg [31:0] temp_basis;
    reg found_msb;
    reg [4:0] bit_pos; // Current bit position being processed (0-31)
    reg [4:0] bit_pos_next;

    // Temporary variables for maximization
    reg [31:0] next_result;
    reg [31:0] xor_val;

    // Control signals
    reg load_num;
    reg update_basis;
    reg try_insert;
    reg start_max;
    reg inc_basis_idx;
    reg clr_basis_idx;
    reg clr_bit_pos;
    reg inc_bit_pos;
    reg clr_read_ptr;
    reg inc_read_ptr;
    reg store_result;
    reg clr_result;
    reg set_done;
    reg clr_done;

    // Sequential state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            write_ptr <= 3'b0;
            read_ptr <= 3'b0;
            count_reg <= 3'b0;
            basis_count <= 3'b0;
            basis_idx <= 3'b0;
            bit_pos <= 5'd31;
            temp_num <= 32'b0;
            result <= 32'b0;
            busy <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= state_next;
            basis_idx <= basis_idx_next;
            bit_pos <= bit_pos_next;
            temp_num <= temp_num_next;
            
            if (load_num) begin
                buffer[write_ptr] <= data_in;
                write_ptr <= write_ptr + 1;
            end

            if (clr_read_ptr) begin
                read_ptr <= 3'b0;
            end else if (inc_read_ptr) begin
                read_ptr <= read_ptr + 1;
            end

            if (update_basis) begin
                // Store the reduced number in the basis array at basis_count
                // Note: We need to find the correct slot for basis insertion based on MSB
                // For simplicity in this implementation, we build basis linearly
                // and will sort/order during maximization or just use highest bit logic
                basis[basis_count] <= temp_num;
                basis_count <= basis_count + 1;
            end

            if (store_result) begin
                result <= next_result;
            end

            if (clr_result) begin
                result <= 32'b0;
            end

            if (set_done) done <= 1'b1;
            if (clr_done) done <= 1'b0;
            
            busy <= (state != IDLE && state != DONE);
        end
    end

    // Combinational logic for state transition and datapath
    always @(*) begin
        state_next = state;
        basis_idx_next = basis_idx;
        bit_pos_next = bit_pos;
        temp_num_next = temp_num;
        
        load_num = 1'b0;
        update_basis = 1'b0;
        try_insert = 1'b0;
        start_max = 1'b0;
        inc_basis_idx = 1'b0;
        clr_basis_idx = 1'b0;
        clr_bit_pos = 1'b0;
        inc_bit_pos = 1'b0;
        clr_read_ptr = 1'b0;
        inc_read_ptr = 1'b0;
        store_result = 1'b0;
        clr_result = 1'b0;
        set_done = 1'b0;
        clr_done = 1'b0;
        
        // Default calculations
        temp_basis = 32'b0;
        found_msb = 1'b0;
        next_result = result;
        xor_val = 32'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    state_next = COLLECT;
                    clr_read_ptr = 1'b1;
                    write_ptr = 3'b0; // Reset write pointer explicitly
                    clr_done = 1'b1;
                    count_reg = num_count;
                end
            end

            COLLECT: begin
                // Wait for data_valid to load numbers
                if (data_valid) begin
                    load_num = 1'b1;
                    // Check if we collected all numbers
                    if (write_ptr + 1 == count_reg) begin
                        state_next = BUILD_BASIS;
                        basis_idx_next = 3'b0; // Index for current number being processed
                        basis_count = 3'b0;     // Reset basis count
                    end
                end
            end

            BUILD_BASIS: begin
                // Process number at read_ptr to add to basis
                // Gaussian elimination logic
                
                // Step 1: Load number to process (when entering this state or moving to next number)
                // We use temp_num to hold the number being reduced
                // Logic: 
                //   temp_num = buffer[read_ptr]
                //   For each basis vector (index 0 to basis_count-1):
                //     If MSB(temp_num) == MSB(basis[basis_idx]), temp_num = temp_num ^ basis[basis_idx]
                //   If temp_num != 0, add to basis.

                // Optimization: Since we process bit by bit or vector by vector, let's structure it simply.
                // We iterate through basis vectors 0 to basis_count-1.
                // If temp_num & (1 << MSB_idx) exists, and basis[i] has that bit, XOR.
                
                // To save logic depth, we process one basis vector per clock cycle or a pipelined approach.
                // Given constraint is ~288 cycles, we can afford per-vector processing.
                
                // Let's implement the loop: 
                // 1. Load temp_num from buffer
                // 2. Loop basis_idx from 0 to basis_count-1
                // 3. In loop: 
                //    Calculate mask = {32{temp_num[basis_msb]}} & basis[basis_idx] ... but we need MSB.
                //    Actually, standard algorithm: 
                //      For i from 0 to basis_count-1:
                //        if ((temp_num ^ basis[i]) < temp_num) temp_num ^= basis[i]; 
                //      (Or equivalently check MSB of temp_num vs basis[i])
                // 
                //    Let's stick to the bitwise reduction described in prompt:
                //    "For each basis vector (MSB to LSB): If current number has same MSB as basis vector, XOR them"
                //    This implies we need to know the MSB of basis vectors.
                //    Let's assume basis vectors are kept in a way that basis[i] has a distinct MSB or higher than basis[i+1].
                //    But we build dynamically.
                
                // Refined logic for BUILD_BASIS state:
                // We need a temporary register to hold the number being reduced.
                // Let's say we use `temp_num`.
                
                // Sub-states or Logic inside BUILD_BASIS:
                // If (load_temp) temp_num = buffer[read_ptr];
                // Loop `basis_idx` 0 to `basis_count - 1`.
                //   Check MSB of `temp_num`. Let's say MSB is the highest set bit.
                //   We can find MSB of temp_num easily if we use a priority encoder logic, but let's simplify.
                //   Since basis vectors in standard Gaussian elimination are kept such that basis[i] has a leading bit that no basis[j>i] has.
                //   If we keep basis unsorted, we must check all.
                
                // Let's follow the prompt's algorithm strictly:
                // "For each number in buffer: For each basis vector (MSB to LSB): ..."
                // "If result is non-zero, add to basis."
                
                // Let's break BUILD_BASIS into sub-steps implicitly via flags and counters.
                
                // Case 1: Start processing new number
                if (read_ptr == 3'b0 && basis_idx == 3'b0 && temp_num == 32'b0) begin
                   // Just entered or need to load
                   // We need to load buffer[0] into temp_num
                   temp_num_next = buffer[3'b0];
                end
                
                // Actually, cleaner way:
                // When we enter BUILD_BASIS for a specific read_ptr:
                // 1. Load temp_num = buffer[read_ptr]
                // 2. Loop basis_idx from 0 to basis_count-1:
                //    Reduce temp_num using basis[basis_idx]
                // 3. If temp_num != 0, Update Basis (Add to array)
                // 4. Move to next read_ptr
                
                // Let's define the "reduce" operation clearly.
                // Prompt: "If current number has same MSB as basis vector, XOR them"
                // Let `b_vec` = basis[basis_idx]. Let `curr_msb` = index of highest set bit in temp_num.
                // Let `b_msb` = index of highest set bit in b_vec.
                // If `curr_msb` == `b_msb`, then temp_num ^= b_vec.
                
                // Implementation of one reduction step:
                // We need to compute MSB of temp_num and MSB of basis[basis_idx].
                // To save logic, we can pre-calculate MSB of basis vectors, or compute on fly (costs delay, but 1 cycle is fine).
                // Let's compute MSB on fly.
                
                // Helper logic to find MSB index (0-31). 5 bit output.
                // Integer i;
                // integer msb_idx = -1;
                // for (i=31; i>=0; i--) if (val[i]) msb_idx = i;
                
                // Since this is comb logic, we can do it. 
                // However, we need to handle the loop sequentially.
                
                // Let's assume we process one basis vector per clock cycle in BUILD_BASIS.
                // State: BUILD_BASIS.
                //   - If `load_num` flag (internal) is 0: 
                //       temp_num = buffer[read_ptr]; basis_idx = 0; `load_num` set.
                //   - Else if basis_idx < basis_count:
                //       // Perform reduction step
                //       // Calculate MSB of temp_num (temp_msb) and basis[basis_idx] (basis_msb)
                //       // If (temp_msb != -1 && basis_msb != -1 && temp_msb == basis_msb) temp_num ^= basis[basis_idx];
                //       basis_idx++;
                //   - Else (done with reduction):
                //       // Check if temp_num != 0
                //       if (temp_num != 0) {
                //           basis[basis_count] = temp_num;
                //           basis_count++;
                //       }
                //       // Reset temp_num to 0 (to mark done with this number)
                //       temp_num = 0;
                //       // Next number
                //       read_ptr++;
                //       if (read_ptr == count_reg) state_next = MAXIMIZE;
                //       else state_next = BUILD_BASIS; // Stay, will load next num
                
                // BUT: We are in a single always block. 
                // Let's use `temp_num` to store intermediate reduction.
                // Use `basis_idx` as pointer to current basis vector being used for reduction.
                // Use `read_ptr` to track current input number.
                
                // Sub-state machine logic for BUILD_BASIS:
                
                // 1. Check if we are ready to load a new number.
                // If temp_num is zero and we haven't started reduction for this read_ptr:
                // We need a flag to say "I loaded this number". Let's use temp_num != 0 as "In progress" or "Ready to reduce".
                // But temp_num becomes 0 if reduced to 0.
                // Let's add an internal flag or just check counters.
                
                // Let's refine: 
                // `temp_num` holds the current reduction state. 
                // `basis_idx` is the current index into the basis array.
                // 
                // If (temp_num == 0 && read_ptr < count_reg):
                //    temp_num_next = buffer[read_ptr];
                //    basis_idx_next = 0;
                //    return; // Next cycle enters reduction
                // 
                // If (basis_idx < basis_count):
                //    // Reduce step
                //    // Find MSB of temp_num and basis[basis_idx]
                //    // Logic for MSB: 
                //    // msb_temp = priority_encoder_32(temp_num);
                //    // msb_basis = priority_encoder_32(basis[basis_idx]);
                //    // if (msb_temp == msb_basis) temp_num_next = temp_num ^ basis[basis_idx];
                //    basis_idx_next = basis_idx + 1;
                //    return;
                // 
                // Else (basis_idx >= basis_count):
                //    // Reduction done
                //    if (temp_num != 0):
                //       update_basis = 1; // Stores temp_num into basis[basis_count] in sequential block
                //    temp_num_next = 0; // Reset for next number
                //    inc_read_ptr = 1;
                //    if (read_ptr + 1 == count_reg): state_next = MAXIMIZE;
                //    else: state_next = BUILD_BASIS;
                
                // Optimization: MSB calculation logic.
                // We can implement a generic MSB finder using a for-loop in comb logic.
                // Since we are synthesizing, the tools will handle this.
                
                // Let's define MSB index logic explicitly for the required reduction.
                // Since this is comb logic inside always @(*), we calculate values based on current state.
                
                // Logic for MSB:
                // msb_temp = 5'h0; for (int i=31; i>=0; i--) if (temp_num[i]) msb_temp = i;
                // msb_basis = 5'h0; for (int i=31; i>=0; i--) if (basis[basis_idx][i]) msb_basis = i;
                
                // We need to compute these to decide.
                // However, standard practice is to use `priority_encoder` logic.
                // Let's define `msb_temp` and `msb_basis` as local variables.
                
                integer i;
                reg [4:0] msb_temp;
                reg [4:0] msb_basis;
                
                msb_temp = 5'd31;
                for (i = 31; i >= 0; i = i - 1) begin
                    if (!temp_num[i]) msb_temp = i[4:0] - 1; // Find first 1, this loop style sets msb_temp to index of MSB if done correctly.
                    // Correct way for loop: 
                    // msb_temp = 0; for(i=31; i>=0; i--) if (temp_num[i]) msb_temp = i;
                end
                // Let's use a simpler explicit check for synthesis. 
                // Verilator/Lint friendly MSB finding.
                msb_temp = 5'd0;
                for (i = 31; i >= 0; i = i - 1) begin
                    if (temp_num[i]) msb_temp = i[4:0];
                end
                
                msb_basis = 5'd0;
                for (i = 31; i >= 0; i = i - 1) begin
                    if (basis[basis_idx][i]) msb_basis = i[4:0];
                end

                // Now the main BUILD_BASIS logic
                
                // 1. Load new number if needed (temp_num == 0)
                if (temp_num == 32'b0 && read_ptr < count_reg) begin
                    temp_num_next = buffer[read_ptr];
                    basis_idx_next = 3'b0;
                end
                // 2. Reduce
                else if (basis_idx < basis_count && temp_num != 32'b0) begin
                    // Check if MSBs match
                    if (msb_temp == msb_basis && temp_num != 32'b0) begin
                         temp_num_next = temp_num ^ basis[basis_idx];
                    end
                    basis_idx_next = basis_idx + 1;
                end
                // 3. Add to basis if reduced result is non-zero
                else if (basis_idx >= basis_count && temp_num != 32'b0) begin
                    // Finished reduction for this number
                    update_basis = 1'b1;
                    temp_num_next = 32'b0; // Clear for next number
                    // Move to next read_ptr in next cycle (or immediately handled by inc logic)
                    // We need to increment read_ptr. 
                    // Wait, if update_basis is asserted, sequential block updates basis_count.
                    // We need to increment read_ptr.
                    inc_read_ptr = 1'b1;
                    // Check if done
                    if (read_ptr == count_reg - 1) begin
                        // If we just processed the last number (index count-1)
                        // Note: read_ptr increments, so we compare against count-1 before increment?
                        // No, check after increment in sequential or compare current.
                        // Let's check: if read_ptr == count_reg - 1, then next is count_reg.
                        // But we are in combinational block.
                        // If read_ptr is currently X, we process X. Next cycle read_ptr = X+1.
                        // We need to stop when we processed count_reg numbers.
                        // read_ptr goes 0, 1, ..., count_reg-1.
                        // When processing read_ptr = count_reg-1:
                        //   temp_num loaded from buffer[count_reg-1]
                        //   Reduced
                        //   update_basis asserted
                        //   inc_read_ptr asserted -> read_ptr becomes count_reg.
                        //   Next cycle: temp_num = 0. State transition happens?
                        //   State transition logic: if read_ptr >= count_reg.
                    end
                    // We need to handle state transition to MAXIMIZE.
                    // This happens when read_ptr reaches count_reg.
                    // But inc_read_ptr sets read_ptr to count_reg only in sequential block.
                    // Wait, `read_ptr < count_reg` condition in step 1 prevents loading new data.
                    // So after inc_read_ptr, read_ptr becomes count_reg.
                    // We need to change state.
                    // So we check: if (read_ptr == count_reg - 1) transition to MAXIMIZE?
                    // No, we should transition when read_ptr reaches count_reg.
                    // Let's do: if (read_ptr + 1 == count_reg) state_next = MAXIMIZE;
                    // But `inc_read_ptr` handles the increment.
                    // If read_ptr is count_reg - 1, we are processing it. After this, read_ptr -> count_reg.
                    // We can set state_next = MAXIMIZE here.
                    
                    if (read_ptr == count_reg - 1) begin
                        state_next = MAXIMIZE;
                        clr_bit_pos = 1'b1;
                        clr_result = 1'b1;
                        basis_idx_next = 3'b0; // Reset basis_idx for maximization loop
                    end else begin
                        state_next = BUILD_BASIS;
                    end
                end
                // 4. If temp_num became 0 (fully reduced to 0), just move to next number
                else if (basis_idx >= basis_count && temp_num == 32'b0) begin
                    // This number is 0 or reduced to 0. No need to add to basis.
                    // Move to next number.
                    inc_read_ptr = 1'b1;
                    if (read_ptr == count_reg - 1) begin
                        state_next = MAXIMIZE;
                        clr_bit_pos = 1'b1;
                        clr_result = 1'b1;
                        basis_idx_next = 3'b0;
                    end else begin
                        state_next = BUILD_BASIS;
                    end
                end
            end

            MAXIMIZE: begin
                // Algorithm: result = 0. For each basis vector (MSB to LSB).
                // Prompt says: "For each basis vector (MSB to LSB)"
                // We need to sort basis or iterate in a specific order.
                // "If (result XOR basis) > result, then result = result XOR basis"
                // Since we built basis without sorting, we might need to sort or iterate multiple times.
                // However, a simple way is to iterate through all basis vectors for each bit position.
                // Or, we can just process basis vectors 0 to basis_count-1 multiple times?
                // No, the greedy algorithm requires vectors to be processed in order of their MSB (highest to lowest).
                // Our basis array is built in arbitrary order.
                // Let's sort it first? Or, iterate bit positions 31 down to 0.
                // For each bit position `i`:
                //   Check if there is a basis vector with MSB at `i`.
                //   If so, try to XOR it with result.
                // 
                // To implement "For each basis vector (MSB to LSB)":
                // We need to scan the basis array to find the vector with highest MSB, then second highest, etc.
                // 
                // Simplification for finite cycles:
                // We can iterate `bit_pos` from 31 to 0.
                // In each iteration, scan `basis_idx` 0 to `basis_count-1`.
                // If `basis[basis_idx]` has MSB at `bit_pos`, perform: 
                //    if ((result ^ basis[basis_idx]) > result) result ^= basis[basis_idx];
                //    break; (since we found the vector for this bit pos)
                // 
                // State MAXIMIZE:
                //   Loop `bit_pos` 31 -> 0.
                //     Loop `basis_idx` 0 -> `basis_count-1`.
                //       Check MSB of basis[basis_idx].
                //       If matches bit_pos:
                //         Calculate candidate = result ^ basis[basis_idx].
                //         If candidate > result: store_result = 1; next_result = candidate;
                //         Then increment bit_pos (or move to next bit).
                //         (Break inner loop)
                //   When bit_pos < 0, go to DONE.
                
                // Wait, `basis_idx` is used for the inner loop. `bit_pos` is outer.
                // We need to iterate basis_idx for each bit_pos.
                
                // Logic:
                // If bit_pos is negative (or we wrapped around): state = DONE.
                
                // We need to find MSB of basis[basis_idx].
                // Reuse MSB logic.
                msb_basis = 5'd0;
                for (i = 31; i >= 0; i = i - 1) begin
                    if (basis[basis_idx][i]) msb_basis = i[4:0];
                end
                
                // Check if current basis vector matches current bit position
                if (bit_pos < 32 && basis_idx < basis_count) begin
                    if (msb_basis == bit_pos) begin
                        // Found a vector for this bit position
                        xor_val = result ^ basis[basis_idx];
                        if (xor_val > result) begin
                            next_result = xor_val;
                            store_result = 1'b1;
                        end
                        // Move to next bit position
                        // We need to reset basis_idx for next bit_pos
                        bit_pos_next = bit_pos - 1;
                        basis_idx_next = 3'b0;
                    end else begin
                        // Try next basis vector
                        basis_idx_next = basis_idx + 1;
                        if (basis_idx + 1 == basis_count) begin
                            // No vector found for this bit_pos
                            bit_pos_next = bit_pos - 1;
                            basis_idx_next = 3'b0;
                        end
                    end
                end else begin
                    // If bit_pos < 0, we are done
                    if (bit_pos == 5'h1F) begin // Assuming initialized to 31, if it underflows to 31 or similar?
                        // Actually, we decrement bit_pos. When it becomes 0, we process it. 
                        // When bit_pos is 0 and processed, it becomes -1 (e.g. 5'b11111 = 31).
                        // Let's explicitly define end condition.
                        // If we processed bit 0, we are done.
                    end
                    // Better end condition:
                    // When bit_pos_next should be less than 0.
                    // If bit_pos == 0 and we finish the loop for it.
                    // If bit_pos == 0 and we process it, next is -1.
                    // If bit_pos is 5'b11111 (which is 31 if signed, or unsigned 31),
                    // Let's use a counter that goes 31, 30, ..., 0.
                    // If bit_pos becomes 31 after 0 (underflow), we stop.
                    // Or just track: if bit_pos == 0 and basis_idx >= basis_count -> next state DONE.
                    
                    if (bit_pos == 5'd0 && basis_idx >= basis_count) begin
                        state_next = DONE;
                    end else if (bit_pos == 5'd0) begin
                        // Need to finish scanning basis for bit 0
                        basis_idx_next = basis_idx + 1;
                        if (basis_idx + 1 == basis_count) begin
                            state_next = DONE;
                        end
                    end else begin
                        // Should not happen unless counters mess up, but handle as end
                        state_next = DONE;
                    end
                end
                
                // Correction for MAXIMIZE flow:
                // We are iterating `bit_pos` from 31 down to 0.
                // Inside, we scan `basis_idx` 0 to `basis_count-1`.
                // 
                // Pseudo:
                // Loop bit_pos 31 -> 0:
                //   Loop basis_idx 0 -> basis_count-1:
                //     if msb(basis[basis_idx]) == bit_pos:
                //        try xor
                //        break
                // 
                // Implementation:
                // 
                // If bit_pos_next == 31 (initial state or wrapped), we should move to next state if done.
                // Let's assume bit_pos starts at 31.
                // When bit_pos reaches 5'd31 again after 0 (underflow), stop.
                // 
                // If bit_pos_next == 31 and basis_idx != 0, it means we started. 
                // Let's refine the termination.
                // We need to process bits 31, 30, ..., 0.
                // 
                // If bit_pos is 31 and basis_idx is 0: 
                //   Scan basis for MSB 31.
                //   If found: result ^= basis; 
                //   basis_idx = 0; bit_pos = 30.
                //   (Wait, we need to reset basis_idx when bit_pos changes).
                //   
                // If bit_pos is 30:
                //   Scan basis for MSB 30.
                //   ...
                //   
                // Termination: When bit_pos is 0 and we finish scanning.
                // After scanning 0, bit_pos becomes -1 (5'b11111).
                // If we see bit_pos == 5'b11111, go to DONE.
                
                // Re-write MAXIMIZE block:
                
                // 1. If bit_pos is 'invalid' (e.g. we finished 0)
                //    In sequential, we initialize bit_pos to 31.
                //    We decrement bit_pos. 
                //    If bit_pos_next becomes 5'b11111 (2's comp -1), we stop.
                //    So condition: if (bit_pos == 0) finish cycle, next bit_pos = 31?
                //    No, if bit_pos == 0, we process it. Then bit_pos_next = bit_pos - 1 = -1.
                //    Then state_next = DONE.
                
                // 2. Scanning logic:
                //    If basis_idx < basis_count:
                //       calculate msb_basis.
                //       If msb_basis == bit_pos:
                //          xor_val = result ^ basis[basis_idx];
                //          if (xor_val > result) store_result = 1; next_result = xor_val;
                //          // Done for this bit_pos
                //          bit_pos_next = bit_pos - 1;
                //          basis_idx_next = 3'b0;
                //       Else:
                //          basis_idx_next = basis_idx + 1;
                //          // If we scanned all and didn't find
                //          if (basis_idx + 1 == basis_count):
                //             bit_pos_next = bit_pos - 1;
                //             basis_idx_next = 3'b0;
                //             
                // 3. Termination check:
                //    If bit_pos_next == 5'b11111: state_next = DONE;
                //    
                // Note: We need to handle the case where bit_pos becomes 0 and we find a match.
                // Process match -> bit_pos_next = -1. 
                // In next cycle, we check state transition.
                // 
                // Let's implement this logic.
                
                // Calculate MSB of basis[basis_idx]
                msb_basis = 5'd0;
                for (i = 31; i >= 0; i = i - 1) begin
                    if (basis[basis_idx][i]) msb_basis = i[4:0];
                end

                if (bit_pos < 5'd32) begin // Valid bit position
                    if (basis_idx < basis_count) begin
                        if (msb_basis == bit_pos) begin
                            xor_val = result ^ basis[basis_idx];
                            if (xor_val > result) begin
                                next_result = xor_val;
                                store_result = 1'b1;
                            end
                            // Move to next bit
                            if (bit_pos == 5'd0) begin
                                bit_pos_next = 5'b11111; // Mark as done (underflow)
                            end else begin
                                bit_pos_next = bit_pos - 1;
                            end
                            basis_idx_next = 3'b0;
                        end else begin
                            // Check next basis vector
                            basis_idx_next = basis_idx + 1;
                            if (basis_idx + 1 == basis_count) begin
                                // End of basis, move to next bit
                                if (bit_pos == 5'd0) begin
                                    bit_pos_next = 5'b11111;
                                end else begin
                                    bit_pos_next = bit_pos - 1;
                                end
                                basis_idx_next = 3'b0;
                            end
                        end
                    end else begin
                        // basis_idx >= basis_count, move to next bit
                        if (bit_pos == 5'd0) begin
                            bit_pos_next = 5'b11111;
                        end else begin
                            bit_pos_next = bit_pos - 1;
                        end
                        basis_idx_next = 3'b0;
                    end
                end
                
                // Check termination condition (bit_pos underflow)
                if (bit_pos_next == 5'b11111) begin
                    state_next = DONE;
                end
            end

            DONE: begin
                set_done = 1'b1;
                if (!start) begin // Wait for start to go low to reset? Or just stay done.
                    // Usually done stays high until start is pulsed again.
                    // If start is low, we stay here.
                    // If start is high, we might restart? No, wait for start low then high.
                end
                if (start) begin
                    // To restart, we need start to go low then high.
                    // Or, on start signal in DONE state, we reset.
                    // Let's implement edge detection or just require start low.
                    // Let's go back to IDLE when start is low.
                    // Actually, standard handshaking: 
                    // Start high -> Process. Done high.
                    // Start stays high? Usually Start is a pulse.
                    // If Start is 0, stay Done. If Start 1, go IDLE (or Collect?)
                    // Let's go to IDLE when Start is 0 (assuming Start is a pulse that is handled by external logic).
                    // If Start is held high, we should probably not restart immediately.
                    // Let's assume Start is a pulse.
                    // If Start is low, we are done.
                    // If Start goes high again, we restart.
                    if (start) begin
                        state_next = IDLE; // Restart
                    end
                end else begin
                    state_next = DONE;
                end
            end
            
            default: state_next = IDLE;
        endcase
    end

endmodule

// Helper module (conceptual, usually part of libraries, but included as function for completeness if needed)
// Verilog doesn't support function returning array or complex logic inside always_comb easily for synthesis without 
// explicit wiring. The MSB finding loops used above are standard synthesis constructs.
