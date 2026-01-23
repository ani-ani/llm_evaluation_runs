module secret_message (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input load,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    parameter MAX_LEN = 16;
    parameter IDLE = 3'b001;
    parameter LOAD = 3'b010;
    parameter PROCESSING = 3'b100;
    parameter DONE = 3'b000; // Use done bit logic for state decode if needed, but explicit states preferred
    // Let's use one-hot or binary
    // 000: IDLE, 001: LOAD, 010: PROCESSING, 011: DONE
    // Re-encoding to avoid unused states issues and explicit done state
    localparam S_IDLE = 3'b000;
    localparam S_LOAD = 3'b001;
    localparam S_PROCESS = 3'b010;
    localparam S_DONE = 3'b011;
    localparam S_UPDATE = 3'b100; // Intermediate state for incrementing counters

    reg [2:0] state, next_state;
    
    // Buffer and length
    reg [7:0] buffer [0:MAX_LEN-1];
    reg [4:0] load_idx; // 0 to 15
    reg [4:0] N; // Actual length
    
    // Processing counters
    reg [4:0] i; // Start index
    reg [4:0] d; // Common difference
    reg [4:0] L; // Length of progression
    
    // Hashing / Counting variables
    // Since strings are short, we can use a large memory or smaller optimized logic.
    // Requirement: "maintain a count for each unique hidden string".
    // With max 16 chars, the hidden string max length is 16.
    // The number of unique strings is potentially large.
    // Constraint check: "Result must be output in Q16.16 format" but "result is an integer".
    // The core problem implies finding the MAX count.
    // We need a storage mechanism. 
    // To be synthesizable and efficient for 16 chars, we can iterate and compare.
    // However, enumerating all subsequences and counting distinct ones exactly requires a map.
    // Since we are in Verilog and need to be synthesizable, we face a memory limit.
    // Alternative: Iterate over all progressions, build the string, and check if it matches a stored string.
    // Since the requirement is just the MAX count, we can try to store (string, count) pairs in LUTs/BRAMs.
    // Given the small input, we can use a direct comparison approach with a fixed size storage for distinct strings.
    // Let's limit distinct strings to a manageable number (e.g., 1024) to fit in logic or BRAM.
    // Or, since the total number of possible subsequences is limited:
    // i=0..15, d=1..15, L=1..16. Total ~16*15*16 = 3840 progressions max.
    // We can iterate through all progressions, form the string, and store it in a hash map or simple RAM.
    // To make it efficient and robust for an interview setting:
    // We will assume a hash table size (e.g., 512 entries) for simplicity.
    
    // Implementation of Hash Map:
    // 512 entries. Each entry stores: Valid bit, String (packed), Count.
    // String length is variable. To pack it, we need to know length.
    // We can store a tuple: {length, char0, char1, ... char15}. 1 bit + 16*8 = 129 bits. Too large.
    // Optimization: We only need to process one progression at a time.
    // Step 1: Generate hash from current progression string.
    // Step 2: Lookup in memory. If match, increment count.
    // Step 3: If no match, find empty slot or overwrite (LRU not needed, just find empty).
    // Step 4: Update max_count.
    
    // Let's use a simpler approach given the "sequential" requirement and "small length".
    // We will implement a linear search over a stored array of (string, count) pairs.
    // To fit in logic, let's size the storage to hold 256 distinct strings.
    // Each string: Max 16 chars. 
    // We need a way to compare variable length strings.
    // We can store: 16 x 8-bit chars + 4-bit length + 32-bit count + valid bit. Total bits per entry: 128+4+32+1 = 165 bits. 256 entries = 42k bits. This is large but fits in modern FPGAs using BRAM or LUTRAM.
    // However, implementing a true content-addressable memory (CAM) is complex.
    // 
    // ALTERNATIVE STRATEGY (More Verilog friendly):
    // The input string is fixed. The number of subsequences is bounded.
    // We can iterate `i`, `d`, `L`.
    // For each (i,d,L), extract the string.
    // Then, we check if this string is already in our "database".
    // If yes, increment its count.
    // If no, add it.
    // 
    // Hardware details:
    // We need a RAM to store strings and counts.
    // Address: Hash of the string (or simple counter if we search linearly in state machine states).
    // Since we want efficiency, let's use a hash index.
    // 
    // Hash function: Simple sum of characters modulo 256.
    // Collision resolution: Linear probing (check next slot if occupied but content differs).
    // 
    // State Machine extension:
    // In PROCESS state:
    // 1. Iterate i, d, L.
    // 2. Generate string S.
    // 3. Calculate Hash H.
    // 4. Read RAM[H].
    // 5. Check valid and content match.
    // 6. If match, increment count. If valid but mismatch, H++ (probe). If empty, write.
    // 7. Update max_count.
    // 
    // This requires extra states for RAM read/write/probing.
    // Let's define sub-states for processing.
    
    // RAM Structure (Inferred logic or BRAM)
    // Depth 256, Width: Valid(1) + Length(4) + Chars(16*8=128) + Count(32) = 165 bits.
    // To save space, we can pack Chars in a shift register or only store needed bytes.
    // Since we need to compare strings, we need to store them.
    // 
    // Optimization: Use 2-cycle RAM access (Read, then Write).
    // 
    // Registers for RAM interface
    reg [7:0] ram_addr;
    reg ram_write;
    wire ram_read_valid;
    wire [3:0] ram_len_out;
    wire [127:0] ram_chars_out;
    wire [31:0] ram_count_out;
    
    // We will infer a block RAM for the storage.
    // We need arrays for Valid, Len, Chars, Count.
    reg ram_valid [0:255];
    reg [3:0] ram_len [0:255];
    reg [127:0] ram_chars [0:255];
    reg [31:0] ram_count [0:255];
    
    // Helper: Current string generation registers
    // We need to buffer the generated string from the progression.
    reg [127:0] current_chars;
    reg [3:0] current_len;
    
    // Helper: Hash calculation
    // We can calculate hash on the fly while generating string.
    reg [7:0] current_hash;
    
    // Sub-state for processing logic
    reg [1:0] proc_sub_state; // 0: Calculate/Read, 1: Compare, 2: Write/Update, 3: Next Iteration
    
    // Random Access Memory Logic
    // We use logic arrays, synthesis tools will map to BRAM if size permits.
    
    integer k;
    
    // Next State Logic
    always @(*) begin
        case (state)
            S_IDLE: begin
                if (start) next_state = S_LOAD;
                else next_state = S_IDLE;
            end
            S_LOAD: begin
                if (!start) next_state = S_LOAD; // Stay in load until start is asserted? 
                // Wait for user to finish loading. Usually "start" initiates process.
                // Let's assume Start goes high after load is done.
                // The description says "start" triggers processing. 
                // So if we are in LOAD and Start is high, go PROCESS.
                if (start) next_state = S_PROCESS;
                else next_state = S_LOAD;
            end
            S_PROCESS: begin
                // Complex logic. We use proc_sub_state to manage cycles.
                // We iterate through all i, d, L.
                // If loop done, go DONE.
                if (i >= N && d > N && L > N) next_state = S_DONE; // Loop completion condition check
                else next_state = S_PROCESS;
            end
            S_DONE: begin
                next_state = S_IDLE; // Auto reset on done or wait for external reset? 
                // Usually stays in done until reset or start.
                // Let's go back to idle if start is low, else stay done? 
                // Let's stay in done until reset.
                if (!rst_n) next_state = S_IDLE; // Or just rely on reset
                else next_state = S_DONE;
            end
            default: next_state = S_IDLE;
        endcase
        
        // Override for reset
        if (!rst_n) next_state = S_LOAD; // Or IDLE. 
        // Requirement says IDLE waits for start. 
        // LOAD accepts chars. 
        // Let's go to IDLE on reset.
        if (!rst_n) next_state = S_IDLE;
    end

    // State Transition and Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            result <= 0;
            load_idx <= 0;
            N <= 0;
            i <= 0;
            d <= 0;
            L <= 0;
            ram_write <= 0;
            proc_sub_state <= 0;
            // Clear RAM valid bits
            for (k = 0; k < 256; k = k + 1) ram_valid[k] <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                S_IDLE: begin
                    done <= 0;
                    load_idx <= 0;
                    N <= 0;
                    // Initialize loop counters
                    i <= 0;
                    d <= 1;
                    L <= 1;
                    // Reset max result
                    result <= 0;
                    // RAM will be cleared lazily or assume dirty? 
                    // Better to clear explicitly if needed, but let's assume reset clears valid bits.
                end
                
                S_LOAD: begin
                    if (load && load_idx < MAX_LEN) begin
                        buffer[load_idx] <= char_in;
                        load_idx <= load_idx + 1;
                        N <= load_idx + 1;
                    end
                    // If load is low and we have length, we stay here until start.
                    // If user loads fewer than 16, N captures the last written index + 1.
                end
                
                S_PROCESS: begin
                    // Sub-state machine for processing logic to handle sequencing
                    case (proc_sub_state)
                        0: begin // Calculate/Generate String
                            // Check if current configuration is valid
                            // Condition: i + (L-1)*d < N
                            if (N == 0) begin
                                // Empty string, jump to done
                                state <= S_DONE;
                            end else if (i >= N) begin
                                // i overflow, go to next d
                                i <= 0;
                                d <= d + 1;
                                L <= 1;
                                if (d > N) state <= S_DONE;
                            end else if (L == 0 || (i + (L-1)*d >= N)) begin
                                // L invalid or too large for this i,d, increment i
                                i <= i + 1;
                                L <= 1;
                                if (i + 1 >= N && L == 1) begin 
                                    // logic for next d handled in next cycle or here
                                end
                            end else begin
                                // Valid (i, d, L). Generate string and hash.
                                // We need to extract L chars: buffer[i], buffer[i+d], buffer[i+2d]...
                                // Since we are sequential, we can't do this in 1 cycle easily without a loop.
                                // We will use a counter for extraction or do it in parallel if L is small.
                                // To keep it simple and robust:
                                // Use a temporary register to build the string over multiple cycles.
                                // Or calculate hash incrementally.
                                
                                // Let's assume we use a multi-cycle approach within this state.
                                // We'll use a local counter `temp_idx` for extraction.
                                // Actually, let's define a sub-sub-state or just use the existing proc_sub_state.
                                // Let's add a small loop counter for extraction.
                                
                                // To save states, we calculate the hash and compare in one go.
                                // We need to read RAM based on Hash.
                                // So: Generate Hash -> Read RAM -> Compare.
                                
                                // Generating Hash of current progression (i, d, L):
                                // Hash = sum of chars % 256.
                                
                                // We need to compute this sum.
                                // Since L can be up to 16, we can do it in 1 cycle if we have adders.
                                // But we need to access buffer which is async read.
                                // So we can compute hash in combinational logic, then register it.
                                // But we need to generate the FULL string to store in RAM if not found.
                                // So we need to store the full string (chars) for the current progression.
                                
                                // Let's define a helper task logic using a separate counter `ext_cnt`.
                                // We'll advance `proc_sub_state` to 1 (Read RAM) only after string is ready.
                                
                                // Re-evaluating: Doing it in sub-states is cleaner.
                                // Let's use proc_sub_state: 0: Prepare/GenHash, 1: Read RAM, 2: Compare/Hit, 3: Miss/Write, 4: Update Max, 5: Next Iter
                                
                                // Back to main process block: We'll switch to a refined sub-state machine.
                            end
                        end
                    endcase
                end
            endcase
        end
    end
    
    // --- Refactored Logic for PROCESSING ---
    // The single always block above is getting messy for the complex processing.
    // Let's rewrite the PROCESSING logic explicitly.
    
    // Registers for extraction
    reg [4:0] ext_idx;
    reg [4:0] ext_step;
    reg [4:0] ext_len_rem;
    reg [7:0] ext_char_acc;
    reg [127:0] ext_string_acc;
    reg [7:0] ext_hash_acc;
    
    // RAM read/write interface logic
    // We infer RAM using standard logic arrays.
    // Read happens combinationally or next cycle. 
    // Let's assume Read is asynchronous based on `ram_addr`.
    // We will latch the read result.
    reg [165:0] ram_rd_dout; // {valid, len, chars, count}
    
    // Mapping the read outputs
    wire ram_valid_out = ram_rd_dout[165];
    wire [3:0] ram_len_out = ram_rd_dout[164:161];
    wire [127:0] ram_chars_out = ram_rd_dout[160:33];
    wire [31:0] ram_count_out = ram_rd_dout[32:1];
    
    // RAM write logic
    always @(posedge clk) begin
        if (ram_write) begin
            ram_valid[ram_addr] <= 1;
            ram_len[ram_addr] <= current_len;
            ram_chars[ram_addr] <= current_chars;
            ram_count[ram_addr] <= current_len; // Initially 1 or increment
        end
    end
    
    // RAM Read Logic (Asynchronous, latched on clock edge or when needed)
    // Since we are in a sequential block, we latch the read data at the start of the read cycle.
    always @(posedge clk) begin
        if (state == S_PROCESS && proc_sub_state == 2) begin // Read state
            ram_valid[ram_addr] <= ram_valid[ram_addr]; // Keep value? No, we need to read it.
            // Actually, logic arrays in Verilog are read asynchronously.
            // We must capture them into a register to use them.
            ram_rd_dout <= {ram_valid[ram_addr], ram_len[ram_addr], ram_chars[ram_addr], ram_count[ram_addr]};
        end
    end
    
    // Iteration Logic and Processing State Machine
    // We need to drive `i`, `d`, `L` to cover all combinations.
    // We also need to handle the string extraction and hashing.
    // We will break down S_PROCESS into micro-states.
    
    localparam P_IDLE = 0;
    localparam P_GEN_STRING = 1;
    localparam P_HASH_READ = 2; // Calculate hash, Read RAM
    localparam P_COMPARE = 3;   // Compare strings, decide action
    localparam P_WRITE = 4;     // Write new entry or update count
    localparam P_UPDATE_MAX = 5;// Check if this count > global max
    localparam P_NEXT_ITER = 6; // Increment L, d, i
    
    reg [3:0] p_state;
    
    // Combinational Logic for matching
    wire match_found = ram_valid_out && (ram_len_out == current_len) && (ram_chars_out == current_chars);
    wire empty_slot_found = !ram_valid_out;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            result <= 0;
            load_idx <= 0;
            N <= 0;
            // RAM clear is slow, we rely on reset or dynamic clearing.
            // To be safe, let's clear RAM in IDLE if needed, but for speed, we can mark empty slots on the fly.
            // We will just overwrite dirty entries.
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) state <= S_LOAD;
                end
                
                S_LOAD: begin
                    if (load) begin
                        if (load_idx < MAX_LEN) begin
                            buffer[load_idx] <= char_in;
                            load_idx <= load_idx + 1;
                            N <= load_idx + 1;
                        end
                    end
                    if (start && !load) state <= S_PROCESS; // Start signal goes high to process
                end
                
                S_PROCESS: begin
                    case (p_state)
                        P_IDLE: begin
                            // Initialize iteration
                            i <= 0;
                            d <= 1;
                            L <= 1;
                            p_state <= P_GEN_STRING;
                            // Reset RAM pointer
                            ram_write <= 0;
                        end
                        
                        P_GEN_STRING: begin
                            // Generate string for current (i, d, L)
                            // We can do this in one cycle using combinational logic if we want.
                            // But let's do it sequentially to be safe with logic depth.
                            // Actually, since N <= 16, we can unroll it or use a small loop counter.
                            // Let's use a counter `ext_idx` to iterate.
                            
                            if (ext_idx < L) begin
                                // Accumulate
                                // We need to map progressions: index = i + ext_idx * d
                                // Check bounds? We already ensured i + (L-1)*d < N.
                                // Access buffer
                                // Since buffer is array, we need to index it.
                                // We need to compute index math.
                                // 0: i
                                // 1: i + d
                                // ...
                                
                                // Optimization: We can't easily index variable (ext_idx * d) in one cycle without a multiplier.
                                // However, we can iterate.
                                // Let's compute the current index: `i + ext_idx * d`.
                                // We can update this incrementally: start with `i`, add `d` each step.
                                
                                // To simplify, let's just use a counter and access buffer.
                                // Wait, index calculation `i + ext_idx * d` takes a multiplier.
                                // Since d is small (1-15), we can use a shift-adder or just a small multiplier.
                                // Let's assume a multiplier is available or implement sequential add.
                                // To save hardware, we compute index = i + (ext_idx * d).
                                // Let's use a temporary register `curr_idx`.
                                
                                // Let's use an iterative approach inside P_GEN_STRING.
                                if (ext_idx == 0) begin
                                    curr_idx <= i;
                                    ext_hash_acc <= buffer[i];
                                    ext_string_acc[127:120] <= buffer[i];
                                    // Calculate length to store? We know L.
                                end else begin
                                    curr_idx <= curr_idx + d;
                                    ext_hash_acc <= ext_hash_acc + buffer[curr_idx + d];
                                    // Append char. We need to shift. 
                                    // Ext_string_acc is packed. 
                                    // We can shift left by 8 and OR, or use index.
                                    // Let's use index to update only the relevant byte.
                                    // ext_string_acc[127 - 8*ext_idx +: 8] <= buffer[curr_idx + d];
                                    // Calculation: 127 - 8*ext_idx is top bit.
                                end
                                
                                ext_idx <= ext_idx + 1;
                                // Stay in this state
                            end else begin
                                // String generation complete
                                current_len <= L;
                                current_chars <= ext_string_acc; // Update full string
                                current_hash <= ext_hash_acc % 256; // Modulo 256
                                
                                // Reset ext_idx for next use
                                ext_idx <= 0;
                                
                                // Next: Hash and Read RAM
                                p_state <= P_HASH_READ;
                            end
                        end
                        
                        P_HASH_READ: begin
                            // Set RAM address based on hash
                            ram_addr <= current_hash;
                            // Wait for read (next cycle)
                            p_state <= P_COMPARE;
                            ram_write <= 0;
                            // We also need to handle collision / probing.
                            // We'll use `probe_count` to limit search.
                            probe_count <= 0;
                        end
                        
                        P_COMPARE: begin
                            // Data latched from RAM in previous cycle (if we assume synchronous read)
                            // Actually, we defined ram_read_valid as wire, so it might be async.
                            // If async read, we have it now.
                            // Let's assume our `ram_rd_dout` logic in always block catches it.
                            
                            if (match_found) begin
                                // Hit: Prepare to update count
                                // We need to read the current count, increment it.
                                // Since we have it in ram_count_out, we can do it.
                                // Prepare write data
                                current_len <= ram_len_out;
                                current_chars <= ram_chars_out;
                                // Increment count
                                // If we are updating the count in RAM, we need to write back.
                                // The RAM content is {valid, len, chars, count}.
                                p_state <= P_WRITE;
                                // Special flag for incrementing vs creating new
                                ram_write <= 1;
                                // New count = ram_count_out + 1
                                // We need to store this new count in a temp register to write it.
                                // Or calculate it in the write block.
                                // Let's reuse `ext_hash_acc` or similar to store the new count.
                                ext_hash_acc <= ram_count_out[7:0] + 1; // Using temp reg for count byte? 
                                // Let's use `probe_count` low bits or a new register. 
                                // We need 32-bit. 
                                // Let's use `ext_string_acc` temporarily or a dedicated `temp_count` register.
                                temp_count <= ram_count_out + 1;
                                
                            end else if (empty_slot_found) begin
                                // Miss, empty slot found. Prepare to write new entry.
                                p_state <= P_WRITE;
                                ram_write <= 1;
                                // New entry: Valid=1, Len=current_len, Chars=current_chars, Count=1
                                temp_count <= 1;
                                
                            end else begin
                                // Collision (Slot occupied but content different)
                                // Probe next address
                                if (probe_count < 16) begin // Limit probing depth
                                    ram_addr <= ram_addr + 1;
                                    probe_count <= probe_count + 1;
                                    // Stay in P_COMPARE, next cycle reads new slot
                                end else begin
                                    // Hash table full or stuck. Discard string? 
                                    // For this exercise, we'll just skip updating.
                                    p_state <= P_NEXT_ITER;
                                end
                            end
                        end
                        
                        P_WRITE: begin
                            // Write cycle complete or logic handled.
                            // We need to update the RAM array.
                            // The write logic is in a separate always block sensitive to ram_write.
                            // We need to provide data to that block.
                            // Data needed: Valid=1, Len=current_len, Chars=current_chars, Count=temp_count
                            // We need to route this to the RAM write logic.
                            
                            // We need to update `ram_count` at `ram_addr`.
                            // Since we are writing, let's perform the write here directly to avoid complexity.
                            // (The separate always block above was a template. Let's merge logic).
                            
                            ram_valid[ram_addr] <= 1;
                            ram_len[ram_addr] <= current_len;
                            ram_chars[ram_addr] <= current_chars;
                            ram_count[ram_addr] <= temp_count;
                            
                            // Move to update max
                            p_state <= P_UPDATE_MAX;
                            ram_write <= 0; // Stop writing
                        end
                        
                        P_UPDATE_MAX: begin
                            // Check if temp_count > result
                            if (temp_count > result) begin
                                result <= temp_count;
                            end
                            p_state <= P_NEXT_ITER;
                        end
                        
                        P_NEXT_ITER: begin
                            // Increment L, d, i
                            // Logic: i increases, then L, then d.
                            // Loop i from 0 to N-1
                            // Loop L from 1 to max valid
                            // Loop d from 1 to N (or as valid)
                            
                            if (i < N) begin
                                if (i + (L-1)*d < N) begin
                                    // Valid L, try next L
                                    L <= L + 1;
                                end else begin
                                    // L too large for this i, reset L, try next i
                                    L <= 1;
                                    i <= i + 1;
                                end
                            end else begin
                                // i reached N, reset i, try next d
                                i <= 0;
                                L <= 1;
                                d <= d + 1;
                                if (d >= N) begin // If d >= N, length 1 only? d=15 for N=16. 
                                    // If d >= N, only d=N gives i+0 valid? No, d=N, i=0 valid for L=1. i=1 invalid.
                                    // We can stop when d > N because i must be < N and L>=1.
                                    if (d > N) begin
                                        state <= S_DONE;
                                        done <= 1;
                                    end
                                end
                            end
                            
                            // If we just modified counters, we need to check validity of the NEW state immediately?
                            // No, let's go back to P_IDLE (or P_GEN_STRING) to let the state update.
                            // But we need to check if the new (i,d,L) is valid.
                            // If we jump to P_GEN_STRING, it will proceed.
                            // However, P_GEN_STRING expects valid indices.
                            // We just updated them. We should check validity here or in P_IDLE.
                            
                            // Let's transition to P_IDLE or P_GEN_STRING based on validity.
                            // Actually, P_IDLE resets ext_idx etc.
                            p_state <= P_IDLE; // This will trigger re-init and then P_GEN_STRING
                            
                            // Edge case: If N=0, we should handle it.
                            if (N == 0) begin
                                state <= S_DONE;
                                done <= 1;
                            end
                        end
                    endcase
                end
                
                S_DONE: begin
                    // Result is already set.
                    // Result must be Q16.16. The integer count needs to be shifted.
                    // The description says: "Result must be output in Q16.16 format (though result is an integer, multiply by 65536 for format)"
                    // So we need to multiply result by 65536.
                    // But result is a register. Let's do this transitionally.
                    // When we enter DONE, we should shift result.
                    // Wait, result is updated during process. 
                    // Let's multiply when entering DONE.
                    // However, we might enter DONE multiple times? 
                    // Let's just shift when we transition to DONE.
                    // But the code above sets done=1 inside S_PROCESS logic? No, it sets state to S_DONE.
                    // We can intercept here.
                    
                    // To avoid shifting multiple times, we can check if done is 0.
                    if (!done) begin
                         result <= result << 16; // Multiply by 65536
                         done <= 1;
                    end
                end
            endcase
        end
    end
    
    // Auxiliary Registers (declared in always block but need to be reg)
    reg [4:0] curr_idx;
    reg [7:0] probe_count;
    reg [31:0] temp_count;

endmodule
