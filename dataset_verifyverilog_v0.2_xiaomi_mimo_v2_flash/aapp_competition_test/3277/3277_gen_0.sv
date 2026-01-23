module ks_smooth_min_changes (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    input [5:0] N,
    input [3:0] K,
    input valid_in,
    output reg ready,
    output reg [7:0] min_changes,
    output reg done
);

    // Parameters for FSM states
    localparam IDLE = 3'b000;
    localparam RECV = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam DONE_STATE = 3'b011;
    localparam CLEAR_FREQ = 3'b100;

    // Registers for FSM
    reg [2:0] state, next_state;
    
    // Registers for input storage and counters
    reg [5:0] element_cnt;       // Counts elements received (0 to N-1)
    reg [5:0] group_size [0:7];  // Size of each group (K groups, K<=8)
    reg [2:0] current_group_idx; // Group index for current element (0 to K-1)
    
    // Registers for computation
    reg [7:0] val_ptr;           // Pointer for value loop (0 to 255)
    reg [2:0] grp_ptr;           // Pointer for group loop (0 to K-1)
    reg [7:0] freq_cnt;          // Frequency counter for current value in current group
    reg [7:0] max_freq;          // Mode count (highest frequency in current group)
    reg [7:0] temp_changes;      // Accumulated changes for current group
    reg [7:0] total_changes;     // Final total changes
    
    // Memory for frequency counting. 8 groups, 256 values each.
    // We use a dual-port RAM inference or simple logic for access.
    // To save area and follow simple sequential logic, we will use a shared block
    // or iterate efficiently. Given constraints (64+K*256 cycles), 
    // we can iterate: For each group (0..K-1), for each value (0..255), check count.
    // We need to store the counts. 
    // Depth 256 * 8 = 2048 entries. 
    // Let's use a 1KB SRAM structure or register file if synthesis allows, 
    // but standard logic usually implies LUTRAM or Flip-Flops.
    // Given 2048 bytes, FFs are too many (2048*8 = 16k bits). 
    // Use inferred RAM (reg [7:0] freq_mem [0:2047]).
    
    reg [7:0] freq_mem [0:2047]; // 8KB memory for frequencies
    
    // Helper signals
    wire [10:0] mem_addr; // {group[2:0], value[7:0]} -> 3+8=11 bits
    assign mem_addr = {current_group_idx, data_in}; // for writing input
    
    wire [10:0] calc_addr; // {grp_ptr, val_ptr}
    assign calc_addr = {grp_ptr, val_ptr};
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = RECV;
                else next_state = IDLE;
            end
            RECV: begin
                if (element_cnt == N && !valid_in) next_state = CLEAR_FREQ; // Wait for last valid to process
                else if (element_cnt == N && valid_in) next_state = CLEAR_FREQ; // Edge case: valid arrives on Nth count
                else next_state = RECV;
            end
            CLEAR_FREQ: begin
                // Transition to COMPUTE once clearing is done or skipped
                // Actually, we handle clearing inside COMPUTE logic or separate state.
                // Let's make a dedicated state to reset 'val_ptr' and 'grp_ptr' before compute loop starts.
                next_state = COMPUTE;
            end
            COMPUTE: begin
                // Logic: Loop Grp 0..K-1. Loop Val 0..255.
                // If (grp_ptr < K) -> process.
                // If (grp_ptr >= K) -> DONE.
                if (grp_ptr >= K) next_state = DONE_STATE;
                else next_state = COMPUTE;
            end
            DONE_STATE: begin
                if (start) next_state = RECV; // Restart on new start
                else next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b0;
            done <= 1'b0;
            min_changes <= 8'b0;
            element_cnt <= 6'b0;
            current_group_idx <= 3'b0;
            grp_ptr <= 3'b0;
            val_ptr <= 8'b0;
            max_freq <= 8'b0;
            temp_changes <= 8'b0;
            total_changes <= 8'b0;
            freq_cnt <= 8'b0;
            // We don't explicitly clear memory here to save reset time, 
            // but we will handle zeroing during computation.
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b0;
                    done <= 1'b0;
                    element_cnt <= 6'b0;
                    current_group_idx <= 3'b0;
                    total_changes <= 8'b0;
                    if (start) begin
                        ready <= 1'b1;
                    end
                end

                RECV: begin
                    // Handle data reception
                    if (valid_in && ready) begin
                        // Write to memory
                        // Address is based on group index and value
                        freq_mem[{current_group_idx, data_in}] <= freq_mem[{current_group_idx, data_in}] + 1;
                        
                        // Update group size
                        group_size[current_group_idx] <= group_size[current_group_idx] + 1;
                        
                        // Increment counters
                        element_cnt <= element_cnt + 1;
                        
                        // Update group index
                        if (current_group_idx == K - 1) begin
                            current_group_idx <= 0;
                        end else begin
                            current_group_idx <= current_group_idx + 1;
                        end
                    end
                    
                    // Stop accepting data when N reached
                    if (element_cnt >= N) begin
                        ready <= 1'b0;
                    end
                end

                CLEAR_FREQ: begin
                    // Reset computation registers
                    grp_ptr <= 3'b0;
                    val_ptr <= 8'd0; // Start checking from value 0
                    max_freq <= 8'b0;
                    temp_changes <= 8'b0;
                    total_changes <= 8'b0;
                    freq_cnt <= 8'b0;
                    // Note: We are not clearing the memory content here.
                    // Instead, we will zero out used memory slots during the computation loop
                    // or simply rely on the fact that we only care about the values we wrote.
                    // However, standard logic requires clearing for 'find mode in 0-255'.
                    // If memory is not cleared, previous values might exist. 
                    // To be safe and generic: We need to clear the memory OR iterate strictly.
                    // Given the area, let's implement a cleaning phase in the first cycles of COMPUTE.
                    // Actually, let's just do a quick synchronous clear in RECV->COMPUTE transition if needed.
                    // But the prompt says Latency ~64 + K*256. 
                    // This implies we iterate K * 256 times.
                    // We can reuse the memory if we iterate ALL 256 values for ALL groups.
                    // We just need to make sure we don't read stale data.
                    // Let's do an explicit clean phase to be safe and correct.
                    // We will add a few cycles to clear the memory regions we touch.
                    // Since N is small (<=64), we can clear just the entries we wrote.
                    // But iterating 2048 locations is 2048 cycles, exceeding latency.
                    // Alternative: Iterating 0..255 for 0..K-1 covers all possible inputs.
                    // If the memory contains garbage for values NOT in input, they are 0.
                    // If they are non-zero garbage, the mode might be wrong.
                    // Assumption: Valid reset clears memory. If not, synthesis tool infers initial 0.
                    // We will assume memory is clean or we clean it.
                    // Let's use a separate CLEAN state to clear memory pointers if we want 100% safety.
                    // Given the 'Latency' constraint, we assume we iterate loops.
                    // Let's start the loops.
                end

                COMPUTE: begin
                    // Logic for Mode Finding and Change Calculation
                    // For a specific group (grp_ptr):
                    //   Iterate val_ptr 0..255:
                    //     Read freq from memory.
                    //     If freq > max_freq: max_freq = freq.
                    //     total_changes += freq (actually, sum of all freqs = group_size)
                    //   After 256 loop: changes = group_size[grp_ptr] - max_freq.
                    //   Add to global accumulator.
                    //   Increment grp_ptr, reset val_ptr and max_freq.
                    
                    // We need to handle the loop timing. 
                    // In one cycle we can read memory, update max.
                    
                    // Operation:
                    // Read freq_mem at {grp_ptr, val_ptr}
                    // Check if val_ptr == 255 (done with group) or val_ptr < 255.
                    
                    // 1. Read memory (this happens implicitly or via logic)
                    // Since mem read is asynchronous in block RAM usually, we register the read.
                    // Let's assume we read in this cycle.
                    
                    // Wait, to avoid combinational loop with memory, we should handle the logic carefully.
                    // We will calculate address and read.
                    // To handle the loop, we need to increment val_ptr.
                    // We need to check if we are done with the group.
                    
                    if (grp_ptr < K) begin
                        // Process current group
                        // We are iterating val_ptr 0 to 255.
                        // The value is read from freq_mem[{grp_ptr, val_ptr}].
                        
                        // Logic to read memory:
                        // We need to ensure we are reading the correct address for the current cycle.
                        // The address logic is combinational based on grp_ptr and val_ptr.
                        // The data is available next cycle if standard RAM, or same cycle if LUTRAM.
                        // Let's assume we read 'freq_cnt' which is registered from memory read.
                        // Or simpler: Use combinational read inside always block (synthesizable for FPGAs).
                        
                        // Let's use direct access for clarity in simulation/synthesis (assuming RAM is synchronous read or async).
                        // We will assume we can read freq_mem[...] in the block.
                        // To pipeline or not? With small latency, let's do direct logic.
                        
                        // Reading memory:
                        freq_cnt <= freq_mem[{grp_ptr, val_ptr}];
                        
                        // Update Max Frequency found so far for this group
                        if (freq_mem[{grp_ptr, val_ptr}] > max_freq) begin
                            max_freq <= freq_mem[{grp_ptr, val_ptr}];
                        end
                        
                        // Increment val_ptr
                        if (val_ptr < 8'd255) begin
                            val_ptr <= val_ptr + 1;
                        end else begin
                            // End of values for this group
                            // Calculate changes for this group: group_size[grp_ptr] - max_freq
                            // Note: group_size[grp_ptr] is the count of elements in this group.
                            // Wait, max_freq is the mode count.
                            // Changes needed = group_size - max_freq.
                            // Add to total_changes.
                            
                            total_changes <= total_changes + (group_size[grp_ptr] - max_freq);
                            
                            // Reset for next group
                            grp_ptr <= grp_ptr + 1;
                            val_ptr <= 8'd0;
                            max_freq <= 8'd0;
                        end
                    end 
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    min_changes <= total_changes;
                    ready <= 1'b0;
                end
            endcase
        end
    end
    
    // Registers for memory write
    reg mem_write_en;
    reg [10:0] mem_write_addr;
    reg [7:0] mem_write_data;
    
    // Combinational logic for memory read address
    wire [10:0] mem_read_addr;
    assign mem_read_addr = (state == RECV) ? {current_group_idx, data_in} : 
                           (state == COMPUTE) ? {grp_ptr, val_ptr} : 11'b0;
    
    // Memory Block
    // We need to handle read and write in the same cycle if state == COMPUTE.
    // In COMPUTE, we read {grp_ptr, val_ptr}, update max, then write 0.
    // This requires synchronous write logic.
    
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            ready <= 1'b0;
            done <= 1'b0;
            min_changes <= 8'b0;
            element_cnt <= 6'b0;
            current_group_idx <= 3'b0;
            grp_ptr <= 3'b0;
            val_ptr <= 8'b0;
            max_freq <= 8'b0;
            total_changes <= 8'b0;
            // We do not reset memory content here to save reset cycles.
            // We will clear on the fly.
            
            // Initialize group_size
            for (i = 0; i < 8; i = i + 1) begin
                group_size[i] <= 6'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b0;
                    done <= 1'b0;
                    element_cnt <= 6'b0;
                    current_group_idx <= 3'b0;
                    total_changes <= 8'b0;
                    // Reset pointers
                    grp_ptr <= 3'b0;
                    val_ptr <= 8'd0;
                    max_freq <= 8'd0;
                    // Clear group sizes
                    for (i = 0; i < 8; i = i + 1) begin
                        group_size[i] <= 6'b0;
                    end
                    if (start) begin
                        ready <= 1'b1;
                    end
                end

                RECV: begin
                    if (valid_in && ready) begin
                        // Write to memory: Increment count at {group_idx, value}
                        // We assume memory content is either 0 or garbage from previous run.
                        // If garbage exists, we add to it. This is BAD if not cleared.
                        // But we will clear memory in the COMPUTE phase (read-back-to-zero).
                        // However, this implies the memory might have garbage for the CURRENT run if we didn't clear before writing.
                        // Wait, we write to address A. If address A has garbage G, we write G+1.
                        // If we clear A during compute, we clear the (G+1) value.
                        // So we need to clear BEFORE writing in RECV.
                        // But we can't clear everything.
                        
                        // SOLUTION: We must clear the specific address BEFORE incrementing in RECV.
                        // How? We can't read-modify-write in 1 cycle easily if RAM is read-dominant.
                        // But we can assume we clear memory in IDLE for the *entire* block? No.
                        
                        // Let's go back to the versioning idea or just clear in IDLE.
                        // To meet latency, maybe we assume the memory is reset by the system.
                        // OR, we use a different memory structure.
                        
                        // What if we don't use RAM for accumulation in RECV?
                        // We can use a small FIFO or shift register for the incoming values?
                        // N <= 64. We can store the values in a 64x8 RAM.
                        // Then in compute, we iterate through the stored values.
                        // We can find the mode of the group by iterating the stored values.
                        // This avoids the 256 iteration loop and the clearing problem!
                        
                        // Let's do that.
                        // Storage: A RAM of 64 entries, each entry is [7:0] value and [2:0] group_id.
                        // Or just a RAM for values, and we pass the group_id to the compute logic.
                        
                        // Wait, the prompt specifically says: 'Compute mode per group using frequency counting (values 0-256)'
                        // This suggests the 0-256 iteration method is preferred or required.
                        // If so, we MUST solve the clearing problem.
                        
                        // Let's assume the synthesis tool initializes memory to 0.
                        // Or, we use a 'dirty' bit array of 2048 bits.
                        // 2048 bits is 256 bytes. 
                        // We can store this in registers (256*8 = 2048 bits is small).
                        // Or we can use a single bit array to track if a location was touched.
                        
                        // Let's stick to the RAM approach but add a 'dirty' check.
                        // If 'dirty' is 0, we treat the value as 0.
                        // If 'dirty' is 1, we use the RAM value.
                        // 
                        // We will add a `dirty_mem` array of 2048 bits.
                        // In RECV: 
                        //   addr = {group_idx, data_in}
                        //   if (!dirty_mem[addr]) begin freq_mem[addr] <= 1; dirty_mem[addr] <= 1; end
                        //   else freq_mem[addr] <= freq_mem[addr] + 1;
                        // 
                        // In COMPUTE:
                        //   Read freq from RAM.
                        //   Read dirty bit.
                        //   If dirty: use value. Then write 0 to RAM, clear dirty bit.
                        //   
                        // This is robust and doesn't need global clear.
                        // Let's implement this.
                        
                        // However, we are limited to code size. 2048 bits `reg` is large but manageable in modern FPGAs.
                        // Let's implement this.
                    end
                    // Stop accepting when N reached
                    if (element_cnt >= N) ready <= 1'b0;
                end
                
                COMPUTE: begin
                    // Logic using dirty bits
                    // Read freq_mem[addr]
                    // If dirty_mem[addr] == 1:
                    //   max_freq = max(freq_mem[addr], max_freq)
                    //   // Then clear
                    //   freq_mem[addr] <= 0;
                    //   dirty_mem[addr] <= 0;
                    // If dirty_mem[addr] == 0:
                    //   // treat as 0
                    
                    // The loop logic remains: iterate val_ptr 0..255.
                end
            endcase
        end
    end
    
    // Re-declare memory and dirty bit array
    // We need to handle the memory write logic.
    // The memory is updated in three places: RECV (increment), COMPUTE (clear).
    // We need combinational read for the COMPUTE logic.
    
    // Let's merge the dirty bit array.
    reg [2047:0] dirty_bits; // 2048 bits
    
    // Signal for RAM access
    wire [10:0] rw_addr;
    wire write_en;
    wire [7:0] write_data;
    wire [7:0] read_data;
    wire dirty_read;
    
    // Read Logic (Combinational for RAM inference or Registered)
    // In COMPUTE, we read based on grp_ptr, val_ptr.
    // In RECV, we might need to read if we do Read-Modify-Write. 
    // With dirty bits, we need to check dirty bit first.
    // If we use synchronous RAM, read data is available next cycle.
    // But we want to keep latency low.
    // Let's assume we are using LUTRAM or Registers for small depth, or just logic.
    // Since we need to read and write in the same cycle in COMPUTE (to clear),
    // it's easier to describe as a register array.
    
    // We will model the memory as explicit logic.
    
    // Datapath Logic Revision
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset values
            ready <= 1'b0;
            done <= 1'b0;
            min_changes <= 8'b0;
            element_cnt <= 6'b0;
            current_group_idx <= 3'b0;
            grp_ptr <= 3'b0;
            val_ptr <= 8'd0;
            max_freq <= 8'd0;
            total_changes <= 8'b0;
            temp_changes <= 8'b0;
            dirty_bits <= 2048'b0;
            // Initialize freq_mem to 0 (only needed if not reset by default)
            // Since we use dirty bits, we can skip full reset of freq_mem.
            // But freq_mem values are only valid if dirty_bits is set.
            // So we don't need to reset freq_mem.
            for (i = 0; i < 8; i = i + 1) begin
                group_size[i] <= 6'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b0;
                    done <= 1'b0;
                    element_cnt <= 6'b0;
                    current_group_idx <= 3'b0;
                    total_changes <= 8'b0;
                    grp_ptr <= 3'b0;
                    val_ptr <= 8'd0;
                    max_freq <= 8'd0;
                    // Clear group sizes
                    for (i = 0; i < 8; i = i + 1) begin
                        group_size[i] <= 6'b0;
                    end
                    if (start) begin
                        ready <= 1'b1;
                    end
                end

                RECV: begin
                    if (valid_in && ready) begin
                        // Write Logic
                        // Address: {current_group_idx, data_in}
                        // We need to increment the count.
                        // We need to check dirty bit.
                        // To avoid combinational read delay for RAM, we can use a synchronous write.
                        // However, we need to know the OLD value to increment.
                        // If we assume freq_mem is updated every cycle, we need to read the previous value.
                        // We can use the `freq_mem` array directly.
                        // `freq_mem[{current_group_idx, data_in}]` refers to the value at the start of the cycle (if blocking) or previous cycle.
                        // Let's use non-blocking assignments carefully.
                        
                        // To be safe and standard:
                        // We need a way to read-modify-write in 1 cycle. 
                        // This is possible if we read, register the value, and write back.
                        // But here we are inside an always block.
                        
                        // Let's assume we can do this:
                        if (!dirty_bits[{current_group_idx, data_in}]) begin
                            freq_mem[{current_group_idx, data_in}] <= 8'd1;
                            dirty_bits[{current_group_idx, data_in}] <= 1'b1;
                        end else begin
                            freq_mem[{current_group_idx, data_in}] <= freq_mem[{current_group_idx, data_in}] + 1'b1;
                        end
                        
                        // Update group size
                        group_size[current_group_idx] <= group_size[current_group_idx] + 1;
                        
                        element_cnt <= element_cnt + 1;
                        
                        // Update group index
                        if (current_group_idx == K - 1) begin
                            current_group_idx <= 0;
                        end else begin
                            current_group_idx <= current_group_idx + 1;
                        end
                    end
                    if (element_cnt >= N) ready <= 1'b0;
                end

                COMPUTE: begin
                    // Loop: Grp 0..K-1, Val 0..255.
                    // We need to read freq_mem[{grp_ptr, val_ptr}].
                    // We need to read dirty_bits[{grp_ptr, val_ptr}].
                    
                    // Check dirty bit to see if we have valid data
                    if (dirty_bits[{grp_ptr, val_ptr}]) begin
                        // Valid data found
                        // Update max_freq
                        if (freq_mem[{grp_ptr, val_ptr}] > max_freq) begin
                            max_freq <= freq_mem[{grp_ptr, val_ptr}];
                        end
                        // Clear the entry (read-modify-write: read this cycle, write 0 next? No, we need to clear it for this cycle's logic if we iterate back? No, we iterate linearly.
                        // So we can clear it now.
                        freq_mem[{grp_ptr, val_ptr}] <= 8'd0;
                        dirty_bits[{grp_ptr, val_ptr}] <= 1'b0;
                    end
                    
                    // Increment Val pointer
                    if (val_ptr < 8'd255) begin
                        val_ptr <= val_ptr + 1;
                    end else begin
                        // End of values for this group
                        // Add changes to total
                        // changes = group_size[grp_ptr] - max_freq
                        total_changes <= total_changes + (group_size[grp_ptr] - max_freq);
                        
                        // Reset for next group
                        val_ptr <= 8'd0;
                        max_freq <= 8'd0;
                        
                        if (grp_ptr < K - 1) begin
                            grp_ptr <= grp_ptr + 1;
                        end else begin
                            // Done with all groups
                            // We can transition state here or rely on the FSM next_state logic.
                            // The FSM checks `grp_ptr >= K` to transition to DONE.
                            // So we set grp_ptr to K here to trigger the transition in the next cycle.
                            // But wait, we are inside the always block. The state transition logic checks `grp_ptr >= K`.
                            // If we increment `grp_ptr` to K-1 and then `val_ptr` to 255, we are done with group K-1.
                            // We need to mark completion.
                            // Let's set grp_ptr to a value >= K.
                            grp_ptr <= K; // Valid range for grp_ptr is 0..K-1. >= K means done.
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    min_changes <= total_changes;
                    ready <= 1'b0;
                end
            endcase
        end
    end
    
    // Combinational Logic for Next State (re-verified)
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = RECV;
                else next_state = IDLE;
            end
            RECV: begin
                if (element_cnt == N && !valid_in) next_state = COMPUTE;
                else if (element_cnt == N && valid_in) next_state = COMPUTE;
                else next_state = RECV;
            end
            COMPUTE: begin
                // Check if we are done.
                // We are done when grp_ptr >= K (meaning we processed K-1 and incremented to K or beyond)
                // OR when we are at K-1 and val_ptr reaches 255? 
                // The always block updates pointers. 
                // If grp_ptr is K-1 and val_ptr is 255, in this cycle we process the last value.
                // At the end of this cycle, val_ptr becomes 0 and grp_ptr becomes K (if we handle it that way).
                // Or we leave grp_ptr at K-1 and use a flag.
                // Let's check the condition: If (grp_ptr < K) stay in COMPUTE.
                // If (grp_ptr >= K) go to DONE.
                if (grp_ptr >= K) next_state = DONE_STATE;
                else next_state = COMPUTE;
            end
            DONE_STATE: begin
                if (start) next_state = RECV;
                else next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Initial block for simulation (not synthesizable but good for reference)
    // In synthesis, memory is uninitialized or initialized to 0 depending on tool.
    // We rely on dirty_bits to handle initialization state.

endmodule