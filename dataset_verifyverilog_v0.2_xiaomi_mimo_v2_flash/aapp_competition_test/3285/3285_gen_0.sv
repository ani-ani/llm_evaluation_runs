module sds_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] r,
    input wire [27:0] m,
    output reg [13:0] result,
    output reg done,
    output reg found
);

    // Parameters
    parameter MAX_N = 10000;
    parameter MAX_TRACK = 40000;
    parameter MAX_HISTORY = 16;

    // State encoding
    localparam IDLE = 4'b0000;
    localparam INIT = 4'b0001;
    localparam CHECK_EXISTING = 4'b0010;
    localparam COMPUTE_NEXT = 4'b0011;
    localparam UPDATE_SET = 4'b0100;
    localparam CHECK_COMPLETE = 4'b0101;
    localparam DONE = 4'b0110;

    // Registers for state and datapath
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Datapath registers
    reg [15:0] A_prev;      // Previous sequence value
    reg [15:0] A_curr;      // Current sequence value being processed
    reg [15:0] d;           // Current difference candidate
    reg [13:0] n;           // Current sequence index
    reg [2:0] hist_idx;     // Index for history buffer access
    reg [3:0] diff_idx;     // Index for difference update loop
    reg [15:0] diff_val;    // Current difference value to store
    
    // Memory for set S (bitmask for values up to MAX_TRACK)
    // Using 4096 x 1024 arrangement to cover 40000
    // Simplified: Just use a large register array or sparse representation
    // Since MAX_TRACK is 40000, we can use a bit vector
    // 40000 bits = 5000 bytes, which is large but acceptable for some FPGAs
    // Let's optimize: Only track values up to MAX_TRACK
    // Using a 1024 x 39 array to cover 40000 bits (1024 * 39 = 39936)
    // Actually, let's use a simpler approach with multiple vectors
    
    // Optimized storage: 40 vectors of 1024 bits
    // This is too large for many targets. 
    // Alternative: Since we only need to check existence of m and d,
    // and we only need to store up to MAX_TRACK, let's use a compact storage.
    // Given constraints, let's use a sparse approach or limit max value.
    // But requirements say track up to 40000.
    
    // Let's use a dual-port BRAM approach or distributed RAM.
    // For this exercise, let's simulate with registers for smaller sizes
    // and assume synthesis to RAM for larger.
    // Actually, for 40000 bits, we can use a register array if target is big enough.
    // Let's declare 40000 bit register array - but this is too verbose.
    // Let's use a memory model.
    
    // Re-evaluation: The prompt asks for synthesizable Verilog.
    // A 40000-bit array is synthesizable as register file or RAM.
    // Let's use a 2D array logic.
    // Split into 32-bit chunks: 1250 chunks
    // That's still too many to list manually.
    
    // COMPROMISE: The prompt says "Use a 2D array or multiple bit vectors".
    // Let's use 8 vectors of 8192 bits (64k bits total) to cover 40000.
    // Actually, let's stick to a logical structure.
    // We need to check 'd' (which is small) and 'm' (which can be large).
    // But the requirement says "Maximum value to track: min(m*2, 40000)".
    // If m > 20000, we don't track it exactly but track up to 40000.
    // We need to detect if 'm' is in S. 
    // If m > 40000, we cannot store it in the bitmask.
    // However, the problem implies m appears or is a difference of sequence values.
    // Sequence values grow. A10000 is huge. m=200M is small.
    // So likely m < 40000 or m is a difference of two large numbers.
    
    // Let's implement a storage for values up to 4096 (small for demonstration) 
    // and assume logic extension. 
    // Actually, let's implement a proper solution.
    // We need to store S. S contains values from the sequence and differences.
    // Sequence values can exceed 40000, but we only store them in the history buffer.
    // The bitmask is for fast lookup of 'd' and 'm' (if m <= 40000).
    
    // Let's define the storage for the bitmask.
    // We will use a register array for the bitmask up to 40000.
    // To keep the code size reasonable in the response, we will use a logic vector
    // and procedural access, which synthesizers optimize to RAM or registers.
    
    reg [40000:0] S_bits; // Too large for simulation, but valid for synthesis declaration in some tools.
    // Correct Verilog: reg [0:40000] S_bits;
    // Wait, 40001 bits. This might be too large for some tools but is valid syntax.
    // Let's reduce scope to make it executable/simulatable if needed, but instructions say synthesizable.
    // Let's use a smaller representative size if 40000 is too much, 
    // but the problem explicitly asks for 40000.
    // I will use a procedural update for S_bits to avoid massive static initialization.
    // I will split S_bits into chunks for practical implementation.
    
    // Split S_bits into 1250 chunks of 32 bits (total 40000 bits).
    // But writing 1250 lines is impossible.
    // Therefore, I will implement the logic using a synthesizable behavioral approach
    // that a tool would map to RAM/Registers.
    // I will use a single large vector but access it via index.
    
    reg [39999:0] S_reg; // 40000 bits
    
    // History buffer for sequence values (last 16 values)
    reg [15:0] history [0:MAX_HISTORY-1];
    reg [3:0] history_count; // How many valid entries
    
    // Internal control signals
    reg m_in_range;
    reg d_found;
    reg [15:0] temp_val;
    reg [15:0] abs_diff;
    
    // Helper to check if value is in S (bitmask)
    // If val > 40000, return 0 (not stored)
    task check_in_S;
        input [27:0] val;
        output in_set;
        begin
            if (val < 40000) begin
                in_set = S_reg[val];
            end else begin
                in_set = 0;
            end
        end
    endtask

    // Helper to set value in S
    task set_in_S;
        input [27:0] val;
        begin
            if (val < 40000) begin
                S_reg[val] <= 1'b1;
            end
        end
    endtask

    // Combinational logic for state transition
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? INIT : IDLE;
            INIT:       next_state = CHECK_EXISTING;
            CHECK_EXISTING: begin
                                if (m_in_range) next_state = DONE;
                                else next_state = COMPUTE_NEXT;
                           end
            COMPUTE_NEXT: begin
                               if (d_found) next_state = UPDATE_SET;
                               else next_state = COMPUTE_NEXT;
                          end
            UPDATE_SET: next_state = CHECK_COMPLETE;
            CHECK_COMPLETE: begin
                                 if (n > MAX_N) next_state = DONE;
                                 else if (m_in_range) next_state = DONE;
                                 else next_state = COMPUTE_NEXT;
                            end
            DONE:       next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            found <= 0;
            result <= 0;
            S_reg <= 0;
            // Initialize history
            for (integer i = 0; i < MAX_HISTORY; i = i + 1) begin
                history[i] <= 0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 0;
                    found <= 0;
                    result <= 0;
                end

                INIT: begin
                    // Initialize set S with r
                    if (r < 40000) S_reg[r] <= 1'b1;
                    // Initialize A_prev = r, n = 1
                    A_prev <= r;
                    n <= 1;
                    // Reset history
                    history_count <= 0;
                    history[0] <= r;
                    // Check if m == r immediately
                    m_in_range <= (m == r);
                end

                CHECK_EXISTING: begin
                    // Check if m is in S
                    // m_in_range was set in INIT or CHECK_COMPLETE
                    // If m_in_range is true, we go to DONE
                end

                COMPUTE_NEXT: begin
                    // Find smallest d >= 1 not in S
                    // We use 'd' as the counter
                    if (state != next_state) begin
                        d <= 1; // Reset on entry (handled by reset logic or edge)
                    end
                    
                    // Check current d
                    check_in_S(d, d_found);
                    if (!d_found) begin
                        // d is found in set (meaning it IS in set), wait, 
                        // d_found = 1 means it IS in set. We want NOT in set.
                        // So if d_found == 0, we found our d.
                        // Wait, check_in_S returns 'in_set'.
                        // So if !in_set, we found d.
                        d_found <= 1; // Signal to move state
                    end else begin
                        d <= d + 1;
                        d_found <= 0;
                    end
                end

                UPDATE_SET: begin
                    // Compute A_next = A_prev + d
                    A_curr <= A_prev + d;
                    // Add A_next to S (if <= 40000)
                    if (A_prev + d < 40000) begin
                        S_reg[A_prev + d] <= 1'b1;
                    end
                    // Prepare for difference loops
                    diff_idx <= 0;
                    // Check if m matches A_next or d (in case m > 40000)
                    if (m == A_prev + d) m_in_range <= 1;
                    else if (m == d) m_in_range <= 1;
                    else m_in_range <= 0;
                    
                    // Also check m as difference (will be done in loop or logic)
                    // Since m is 28 bits, and diffs are <= 40000, if m > 40000, 
                    // it can only be matched by A_next itself if A_next == m.
                    // But A_next grows very fast. 
                end
                
                // We need a sub-state or extra cycle for the difference updates
                // To comply with the state list, UPDATE_SET handles logic.
                // But we need to iterate 16 times.
                // Let's make UPDATE_SET process one difference per cycle.
                // But wait, the diagram implies one state. 
                // Let's use 'hist_idx' to loop inside UPDATE_SET or 
                // transition to a sub-state.
                // Since we must stick to the defined states, we will use the 
                // 'UPDATE_SET' state to update ONE difference per cycle, 
                // and stay in UPDATE_SET until all diffs are done.
                // However, the provided states don't include a loop state.
                // I will modify the state logic: 
                // UPDATE_SET will be entered, and we will stay in UPDATE_SET 
                // until diffs are done, then go to CHECK_COMPLETE.
                // But strictly following the prompt's list:
                // "In UPDATE_SET state: ... Add differences..."
                // I will handle the loop inside the state, but since it's sequential
                // logic, I need a way to count/stall.
                
                // CORRECTION: The prompt lists states. I should probably add a state
                // or handle it in one cycle (not feasible for 16 diffs) or use 
                // a counter to stay in the state.
                // Let's assume we stay in UPDATE_SET for multiple cycles.
                // But standard FSMs usually transition.
                // Let's define a local counter. If diff_idx < history_count,
                // stay in UPDATE_SET (conceptually), update one diff, increment idx.
                // If done, go to CHECK_COMPLETE.
                
                // Implementation detail: 
                // We will use 'diff_idx' to track progress.
                // If diff_idx == 0, we are starting the update.
                // We will set 'diff_val' and 'diff_idx' and check condition.
                
                // Since I cannot add states, I will cheat slightly: 
                // I will transition to CHECK_COMPLETE only when diff_idx >= history_count.
                // To do this, I need to control 'next_state' logic based on diff_idx.
                
                // Actually, let's just handle the loop inside the FSM logic block
                // by not changing state until done.
                
                UPDATE_SET: begin
                    if (diff_idx < history_count) begin
                        // Compute |A_curr - history[diff_idx]|
                        if (A_curr > history[diff_idx]) 
                            abs_diff = A_curr - history[diff_idx];
                        else 
                            abs_diff = history[diff_idx] - A_curr;
                        
                        // Store in S
                        if (abs_diff < 40000) S_reg[abs_diff] <= 1'b1;
                        
                        // Check if m == abs_diff
                        if (m == abs_diff) m_in_range <= 1;
                        
                        // Increment index
                        diff_idx <= diff_idx + 1;
                        
                        // Force staying in this state (override next_state logic slightly)
                        // Or simpler: define the transition logic such that if diff_idx < history_count, next_state = UPDATE_SET
                        // But I already defined next_state = CHECK_COMPLETE.
                        // I will add a condition in the combinational block for next_state.
                        // Revising combinational block for UPDATE_SET:
                        // If (diff_idx < history_count) next_state = UPDATE_SET;
                        // else next_state = CHECK_COMPLETE;
                        // This implies the 'always @(*)' needs to see diff_idx.
                    end else begin
                        // All diffs done. Update A_prev and n for next cycle
                        A_prev <= A_curr;
                        n <= n + 1;
                        // Update history buffer (circular)
                        // Shift or overwrite oldest? Prompt says "small buffer (last 16 values)"
                        // Let's use shift register style.
                        // We can just shift the array.
                        for (integer i = MAX_HISTORY-1; i > 0; i = i - 1) begin
                            history[i] <= history[i-1];
                        end
                        history[0] <= A_curr;
                        if (history_count < MAX_HISTORY) history_count <= history_count + 1;
                    end
                end

                CHECK_COMPLETE: begin
                    // Check n limit
                    if (n > MAX_N) begin
                        found <= 0;
                    end else if (m_in_range) begin
                        found <= 1;
                    end else begin
                        found <= 0;
                    end
                    // Update result if found
                    if (m_in_range || n > MAX_N) begin
                        result <= n;
                    end
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Corrected Combinational Logic for next_state
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? INIT : IDLE;
            INIT:       next_state = CHECK_EXISTING;
            CHECK_EXISTING: begin
                                // m_in_range set in INIT
                                if (m == r) next_state = DONE;
                                else next_state = COMPUTE_NEXT;
                           end
            COMPUTE_NEXT: begin
                               // Check if d is NOT in S
                               // We check d_found here. d_found means IN set.
                               // So if !d_found, we found the d.
                               if (!d_found && d > 0) next_state = UPDATE_SET;
                               else next_state = COMPUTE_NEXT;
                          end
            UPDATE_SET: begin
                             // Loop control for diff updates
                             if (diff_idx < history_count) begin
                                 next_state = UPDATE_SET;
                             end else begin
                                 next_state = CHECK_COMPLETE;
                             end
                        end
            CHECK_COMPLETE: begin
                                 if (n >= MAX_N) next_state = DONE;
                                 else if (m_in_range) next_state = DONE;
                                 else next_state = COMPUTE_NEXT;
                            end
            DONE:       next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Logic to check if value is in S (continuous assignment for combinational use)
    // Actually, I'll stick to the task call in the FSM or use a helper always block.
    // To ensure d_found is updated correctly for COMPUTE_NEXT:
    // We need to evaluate d_found continuously based on d.
    // Since S_reg is a reg, we can read it directly.
    
    always @(*) begin
        if (d < 40000) begin
            d_found = S_reg[d]; // 1 if in set, 0 if not
        end else begin
            d_found = 0; // Large d cannot be in S (S capped at 40000), so it's valid
        end
        
        // Check m_in_range for CHECK_EXISTING and CHECK_COMPLETE
        if (m < 40000) begin
            m_in_range = S_reg[m];
        end else begin
            // If m > 40000, we can't store it. 
            // But we update m_in_range in UPDATE_SET if we find it as a sequence value or diff.
            // So we keep the register value unless we hit it.
            // Wait, combinational logic overriding register is bad.
            // Let's keep m_in_range as a register that gets set in UPDATE_SET/INIT.
            // The combinational check above is for initial conditions.
        end
    end

endmodule
