module introspective_cache (
    input clk,
    input rst_n,
    input start,
    input [3:0] access_i,
    input valid_i,
    output reg [2:0] read_count,
    output reg done
);

    // Parameters
    parameter CACHE_SIZE = 8;
    parameter LOOKAHEAD_DEPTH = 16;
    parameter OBJECT_BITS = 4;

    // State Encoding
    localparam IDLE = 3'b000;
    localparam FILL_WINDOW = 3'b001;
    localparam PROCESS_ACCESS = 3'b010;
    localparam UPDATE_CACHE = 3'b011;
    localparam LOOKAHEAD_SHIFT = 3'b100;
    localparam DONE = 3'b101;

    // Registers for State Machine
    reg [2:0] current_state, next_state;

    // Lookahead Buffer (Shift Register)
    reg [OBJECT_BITS-1:0] lookahead_buffer [0:LOOKAHEAD_DEPTH-1];
    reg [4:0] valid_count; // Can be up to 16

    // Cache State
    reg cache_valid [0:CACHE_SIZE-1];
    reg [OBJECT_BITS-1:0] cache_tags [0:CACHE_SIZE-1];

    // Control Registers
    reg [3:0] current_access; // Holds the access being processed
    reg [3:0] eviction_candidate; // Tag of object to evict
    reg [2:0] eviction_index; // Index of slot to evict

    // Iteration Counters
    reg [3:0] i_iter; // Used for searching cache
    reg [4:0] j_iter; // Used for lookahead searches
    reg [2:0] k_iter; // Used for eviction candidate comparison

    // Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State Transition & Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = FILL_WINDOW;
                else next_state = IDLE;
            end

            FILL_WINDOW: begin
                // Wait until we have LOOKAHEAD_DEPTH items OR input stream ends (done becomes high)
                if (valid_count >= LOOKAHEAD_DEPTH) next_state = PROCESS_ACCESS;
                else if (done) next_state = DONE; // Handle short sequence
                else next_state = FILL_WINDOW;
            end

            PROCESS_ACCESS: begin
                // We decide next state based on results computed in PROCESS_ACCESS block
                // But typically we go to UPDATE_CACHE to perform the write
                next_state = UPDATE_CACHE;
            end

            UPDATE_CACHE: begin
                // After updating cache (or confirming hit), shift the window
                // Check if we are done (lookahead empty and no valid input)
                if (valid_count == 1 && !valid_i) next_state = DONE;
                else next_state = LOOKAHEAD_SHIFT;
            end

            LOOKAHEAD_SHIFT: begin
                // Next cycle we will be ready for next access
                next_state = PROCESS_ACCESS;
            end

            DONE: begin
                next_state = DONE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic (Outputs and Internal Updates)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_count <= 0;
            done <= 0;
            valid_count <= 0;
            i_iter <= 0;
            j_iter <= 0;
            k_iter <= 0;
            // Reset Cache
            for (int idx = 0; idx < CACHE_SIZE; idx = idx + 1) begin
                cache_valid[idx] <= 0;
                cache_tags[idx] <= 0;
            end
            // Reset Buffer
            for (int idx = 0; idx < LOOKAHEAD_DEPTH; idx = idx + 1) begin
                lookahead_buffer[idx] <= 0;
            end
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        read_count <= 0;
                        done <= 0;
                        valid_count <= 0;
                    end
                end

                FILL_WINDOW: begin
                    if (valid_i && valid_count < LOOKAHEAD_DEPTH) begin
                        lookahead_buffer[valid_count] <= access_i;
                        valid_count <= valid_count + 1;
                    end
                    // If valid_i drops, we assume the sequence ended (for this specific design requirement)
                    // However, FILL_WINDOW logic forces filling first. 
                    // If input stops early, the DONE check in transition handles it.
                end

                PROCESS_ACCESS: begin
                    // 1. Get current access (from index 0 of buffer)
                    current_access <= lookahead_buffer[0];

                    // 2. Check for Hit
                    // We use i_iter to scan cache. Result available next cycle.
                    // Optimization: We do the scan logic here, but we need to wait for state transition to UPDATE_CACHE 
                    // to apply the result. However, to keep it single-cycle processing logic for this state,
                    // we calculate the "eviction candidate" or hit status immediately.

                    // Default: Assume Miss (will be overwritten if Hit detected)
                    // Hit detection logic (combinational loop over cache)
                    // Since we are in a sequential block, we can compute the hit status.
                    // Let's search for the current_access in cache.

                    // Logic: Did we find the object in cache?
                    // We need a flag for hit.
                    // Let's use a variable defined outside, or compute next state actions directly.
                    // Actually, in standard FPGA flow, we do logic inside always block. 
                end

                UPDATE_CACHE: begin
                    // Apply the decision made in PROCESS_ACCESS or derived during transition.
                    // We need to reconstruct the logic because PROCESS_ACCESS didn't update state directly.
                    // Let's perform the check again or use registered values.

                    // Check Hit (Re-evaluated or use a wire)
                    // Since we are in UPDATE_CACHE, we look at 'current_access'
                    reg hit;
                    reg [2:0] hit_idx;
                    hit = 0;
                    hit_idx = 0;
                    for (int c = 0; c < CACHE_SIZE; c = c + 1) begin
                        if (cache_valid[c] && cache_tags[c] == current_access) begin
                            hit = 1;
                            hit_idx = c;
                        end
                    end

                    if (!hit) begin
                        // Miss Handling
                        // Check for empty slot
                        reg empty_found;
                        reg [2:0] empty_slot;
                        empty_found = 0;
                        empty_slot = 0;
                        for (int c = 0; c < CACHE_SIZE; c = c + 1) begin
                            if (!cache_valid[c] && !empty_found) begin
                                empty_found = 1;
                                empty_slot = c;
                            end
                        end

                        if (empty_found) begin
                            // Load into empty slot
                            cache_valid[empty_slot] <= 1;
                            cache_tags[empty_slot] <= current_access;
                            read_count <= read_count + 1;
                        end else begin
                            // Eviction needed
                            // We need to find the eviction candidate.
                            // The PROCESS_ACCESS state should have calculated this.
                            // Since we are iterating in PROCESS_ACCESS, let's do the heavy lifting here or in PROCESS_ACCESS.
                            // Wait, the prompt implies PROCESS_ACCESS evaluates, UPDATE_CACHE applies.
                            // To make it work in 1 cycle per access (after window fill), we must compute eviction in PROCESS_ACCESS.
                            // Let's put the eviction logic in PROCESS_ACCESS and store the result in registers.

                            // If 'eviction_index' is valid (set in PROCESS_ACCESS), use it.
                            cache_valid[eviction_index] <= 1;
                            cache_tags[eviction_index] <= current_access;
                            read_count <= read_count + 1;
                        end
                    end
                end

                LOOKAHEAD_SHIFT: begin
                    // 1. Shift the lookahead buffer left by 1
                    // 2. Read new input if valid_i is high
                    // 3. Update valid_count

                    // Shift
                    for (int s = 0; s < LOOKAHEAD_DEPTH - 1; s = s + 1) begin
                        lookahead_buffer[s] <= lookahead_buffer[s+1];
                    end

                    // Load new
                    if (valid_i) begin
                        lookahead_buffer[LOOKAHEAD_DEPTH-1] <= access_i;
                        // valid_count remains same (consumed one, loaded one)
                    end else begin
                        // No new input, decrement count
                        if (valid_count > 0) valid_count <= valid_count - 1;
                    end
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Combinational Logic for Eviction Selection (Must happen in PROCESS_ACCESS)
    // Since we need to know the eviction victim before UPDATE_CACHE, we perform the calculation.
    // We use a combinational block triggered by state change or inputs.
    // However, inputs (lookahead buffer) change in LOOKAHEAD_SHIFT, which is before PROCESS_ACCESS. 
    // So it's safe to compute in PROCESS_ACCESS state.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset internal evict registers
        end else if (current_state == PROCESS_ACCESS) begin
            // 1. Check Hit
            // 2. If Miss & Full, Find Eviction

            reg hit;
            hit = 0;
            // Check Hit
            for (int c = 0; c < CACHE_SIZE; c = c + 1) begin
                if (cache_valid[c] && cache_tags[c] == lookahead_buffer[0]) hit = 1;
            end

            if (!hit) begin
                // Check Full
                reg full;
                full = 1;
                for (int c = 0; c < CACHE_SIZE; c = c + 1) begin
                    if (!cache_valid[c]) full = 0;
                end

                if (full) begin
                    // Find Eviction Candidate
                    // Iterate over all cached objects.
                    // For each cached object, find its next use in lookahead_buffer[1...15].
                    // If not found, distance is infinite (best candidate).
                    // If found, distance is index.
                    // Evict object with MAX distance (or infinite).

                    // We need registers to hold the best distance and candidate during the search loop.
                    // But this is sequential logic. We can't easily run a nested loop in one clock cycle 
                    // if the loop body has dependencies (updating max).
                    // However, 8 slots * 16 depth = 128 comparisons. It is fast enough in FPGA for 1 cycle?
                    // Usually not. We need a multi-cycle approach or combinatorial.
                    // The prompt asks for a module. Usually, we assume combinatorial for logic this small 
                    // OR we use a state machine inside.
                    // Given the requirement "processes one access per cycle", we assume 
                    // the logic must resolve in the state time.
                    // Let's try to do it in a combinational way (outside the always block) or 
                    // efficient sequential logic inside.

                    // To be strictly correct Verilog for synthesis without huge combinational paths:
                    // We can break the eviction search into a few cycles using 'k_iter' and 'j_iter'.
                    // But the state machine is fixed. PROCESS_ACCESS -> UPDATE_CACHE.
                    // This implies we need the eviction result in PROCESS_ACCESS.
                    // Let's rely on the fact that FPGAs can handle wide comparators.

                    // Algorithm:
                    // Iterate k from 0 to 7 (Cache Slots)
                    //   Find distance of cache_tags[k] in lookahead_buffer (indices 1 to 15)
                    //   Update eviction_index if distance > current_max_distance

                    // Let's define a few temporaries
                    reg [4:0] dist [0:CACHE_SIZE-1]; // Distance for each slot
                    reg [4:0] max_dist;
                    reg [2:0] best_idx;

                    max_dist = 0;
                    best_idx = 0;

                    for (int c = 0; c < CACHE_SIZE; c = c + 1) begin
                        // Find distance for cache_tags[c]
                        reg [4:0] d;
                        d = 20; // Infinite (larger than LOOKAHEAD_DEPTH)

                        if (cache_valid[c]) begin
                            for (int w = 1; w < LOOKAHEAD_DEPTH; w = w + 1) begin
                                // Check if input stream is still valid at this depth
                                // We use valid_count to know how deep valid data goes
                                if (w < valid_count) begin
                                    if (lookahead_buffer[w] == cache_tags[c]) begin
                                        d = w;
                                        break; // Found first future use
                                    end
                                end
                            end
                            // If not found, d remains 20 (infinite)
                        end else begin
                            // Slot empty, should not happen here if full=1 check passed, but treat as infinite distance (evictable)
                            d = 20;
                        end

                        // Compare and update max
                        if (d > max_dist) begin
                            max_dist = d;
                            best_idx = c;
                        end
                        // Tie-breaking: if equal distance, pick lower index (arbitrary preference, ensures determinism)
                        else if (d == max_dist) begin
                            if (c < best_idx) best_idx = c;
                        end
                    end

                    eviction_index <= best_idx;
                end
            end
        end
    end

endmodule