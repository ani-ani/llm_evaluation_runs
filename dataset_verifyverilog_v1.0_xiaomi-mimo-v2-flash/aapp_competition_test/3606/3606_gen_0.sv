module frog_jump (
    input clk,
    input rst_n,
    input start,
    input [15:0] plant_x [0:15],
    input [15:0] plant_y [0:15],
    input [63:0] dir_seq,
    input [3:0] num_plants,
    input [3:0] num_jumps,
    output reg [15:0] final_x,
    output reg [15:0] final_y,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] PROCESS    = 2'd1;
    localparam [1:0] FINISH     = 2'd2;

    // Direction constants
    localparam [1:0] DIR_A      = 2'd0;
    localparam [1:0] DIR_B      = 2'd1;
    localparam [1:0] DIR_C      = 2'd2;
    localparam [1:0] DIR_D      = 2'd3;

    // Internal Registers
    reg [1:0] state, next_state;
    reg [3:0] current_index;
    reg [3:0] jump_counter;
    reg [3:0] scan_index;
    reg [3:0] found_index;
    reg [15:0] curr_x;
    reg [15:0] curr_y;
    reg [1:0] current_dir;
    reg found_flag;
    reg [4:0] max_plants_idx; // 16 plants -> index 15
    
    // Helper wires for arithmetic (signed)
    wire signed [16:0] dx;
    wire signed [16:0] dy;
    assign dx = signed'({1'b0, plant_x[scan_index]}) - signed'({1'b0, curr_x});
    assign dy = signed'({1'b0, plant_y[scan_index]}) - signed'({1'b0, curr_y});

    // Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESS;
                else
                    next_state = IDLE;
            end
            PROCESS: begin
                // If we have processed K jumps (jump_counter == num_jumps), move to finish
                if (jump_counter == num_jumps)
                    next_state = FINISH;
                else
                    next_state = PROCESS;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            final_x <= 16'd0;
            final_y <= 16'd0;
            done <= 1'b0;
            current_index <= 4'd0;
            jump_counter <= 4'd0;
            scan_index <= 4'd0;
            found_index <= 4'd0;
            curr_x <= 16'd0;
            curr_y <= 16'd0;
            current_dir <= 2'd0;
            found_flag <= 1'b0;
            max_plants_idx <= 5'd16;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize for processing
                        current_index <= 4'd0; // Start at first plant (index 0)
                        jump_counter <= 4'd0;
                        max_plants_idx <= (num_plants < 16) ? num_plants : 16'd16;
                        // Initial coordinates from plant 0
                        curr_x <= plant_x[0];
                        curr_y <= plant_y[0];
                    end
                end

                PROCESS: begin
                    // If we are done with K jumps, assertion handled by next_state check
                    if (jump_counter < num_jumps) begin
                        // --- JUMP CYCLE LOGIC ---
                        
                        // 1. Decode Direction for current jump
                        // dir_seq stores 16 directions, 4 bits each. Jump counter 0-15.
                        // Bits [4*jump_counter + 3 : 4*jump_counter]
                        current_dir <= dir_seq[4*jump_counter +: 4];

                        // 2. Scan for next plant
                        // We use a pseudo-combinational scan behavior split over cycles or
                        // sequential scan. Given K<=16 and N<=16, we can scan in sequential cycles
                        // or combinatorially. To ensure timing, let's perform sequential scan.
                        // However, the requirement "done asserts after K cycles (or fewer if scan logic is multi-cycle)"
                        // suggests we might need multiple cycles per jump.
                        // To keep it robust and predictable, let's dedicate 16 cycles per jump for scanning,
                        // or scan combinatorially and latch the result.
                        // Given the instructions emphasize K cycles (implying 1 cycle per jump ideally)
                        // but scan logic is explicitly mentioned, we will do a combinatorial scan
                        // inside the cycle (assuming synthesis tools handle 16-length comparators).
                        
                        // Reset found flag for this scan
                        found_flag <= 1'b0;
                        found_index <= current_index; // Default to current if not found
                        
                        // Combinatorial-like scanning using sequential register updates
                        // We iterate scan_index from current_index + 1 to max_plants_idx
                        // To do this in 1 cycle, we need a loop. 
                        // However, Verilog loops in always blocks can be tricky if not unrolled.
                        // With N<=16, explicit unrolling is possible but verbose.
                        // Let's use a sequential scan counter 'scan_index' to iterate over valid cycles.
                        
                        // MODIFIED APPROACH FOR PREDICTABLE TIMING:
                        // Use 'scan_index' as a scan pointer.
                        // On entering PROCESS state for a new jump, we initialize scan_index.
                        // We will use 'found_flag' to latch if we found a target.
                        // Since the state machine stays in PROCESS, we need a way to move from
                        // scanning phase to 'updating current' phase.
                        // Let's introduce a SUB_STATE inside PROCESS or just use scan_index.
                        
                        // Let's refine the state machine to handle 1 jump per cycle if we treat scan as combinatorial.
                        // With N=16, the logic is small enough.
                        // Let's implement a combinatorial search logic that is registered at the end of the cycle.
                        
                        // Explicit loop for combinatorial search logic (unrolled by synthesis tool)
                        found_index <= current_index; // Default
                        found_flag <= 1'b0;
                        
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i >= current_index + 1 && i < max_plants_idx && !found_flag) begin
                                // Check if plant[i] is valid target based on current_dir
                                // We need to use the registered 'current_dir' decoded this cycle
                                // Note: 'current_dir' is a register updated this cycle, so it holds the correct value for this jump.
                                
                                // Calculations for direction check
                                // Use temporary wires or logic inside the loop (simulation only really, but synthesis unrolls)
                                // To avoid complex array logic inside a loop variable scope, we rely on 
                                // synthesis inference. We must be careful with arrays in loops.
                                // Actually, Icarus Verilog compatibility is key. Arrays in loops in always blocks are risky.
                                // Let's use a generate block for the comparison logic? No, that's for instances.
                                
                                // Safe method for Icarus: Use a sequential process for the scan.
                                // We will extend the PROCESS state to take 'num_plants' cycles.
                                // We'll use a 'sub_state' or just 'scan_active' flag.
                            end
                        end

                        // REVISION: Sequential Scan Logic
                        // To strictly follow "K cycles (or fewer if scan logic is multi-cycle)", 
                        // we will dedicate 1 cycle for the jump update, and the scan happens 
                        // by scanning indices 0..15 sequentially in separate clock cycles.
                        // But wait, that would be K * N cycles.
                        // The user likely expects K cycles total (1 per jump). 
                        // Let's try the combinatorial unrolling but using explicit indices to avoid array issues.
                        
                        // Explicit Comparison Logic for 16 elements
                        // This is verbose but robust for Icarus.
                        // We check elements 1 to 15.
                        
                        // Direction A: dx == dy > 0
                        // Direction B: dx == -dy > 0  (implies dy < 0, dx > 0)
                        // Direction C: dx == -dy < 0  (implies dy > 0, dx < 0)
                        // Direction D: dx == dy < 0   (implies dy < 0, dx < 0)
                        
                        // We need signed arithmetic. dx/dy defined outside.
                        // We need to compute values for each potential index to pick the first one.
                        // This is tricky combinatorially with arrays.
                        
                        // Let's stick to a reliable 2-state process inside PROCESS:
                        // 1. SCANNING: We check indices one by one (taking 16 cycles per jump if needed, or up to N).
                        // 2. UPDATING: We update the position.
                        // Since K<=16 and N<=16, worst case 16*16 = 256 cycles. This fits in 256 cycles.
                        
                        // Let's add a `scan_busy` signal or use `jump_counter` to track progress.
                        // Actually, let's just do a combinatorial search block.
                        // Icarus Verilog handles for-loops in generate blocks well. In always blocks, we need to be careful.
                        // Let's assume synthesis tools can unroll a simple for-loop if we index statically.
                        // We will use a 'found_index' register and 'found_flag' register.
                        // We will calculate a set of 'match' wires for each index.
                        
                        // Re-implementing the scan logic properly for 1-cycle per jump (combinatorial search)
                        // We need to know which index is the *first* one that matches.
                        // Since we can't use dynamic array indices in logic easily with Icarus,
                        // we will expand the array into 16 sets of wires or use a priority encoder approach.
                        
                        // Let's define match conditions for each index j > current_index
                        wire [15:0] match;
                        wire [15:0] dx_diff [0:15]; // We can't easily do this in SV with arrays of wires inside module in some contexts, but Verilog allows genvars.
                        
                        // To keep it clean and Icarus compatible without complex generate loops (which might be overkill):
                        // We will perform the scan SEQUENTIALLY inside the PROCESS state by adding a SUB-STEP.
                        // We introduce a new state: SEARCH.

                        // Let's modify the state definition:
                        // IDLE -> START_JUMP (parse dir) -> SEARCH (scan indices) -> UPDATE -> (back to SEARCH until found or end) -> DONE_JUMP -> FINISH
                        
                        // Simplification: 
                        // State IDLE: Wait for start
                        // State DECODE: Latch current dir, reset scan_idx
                        // State SCAN: Check current scan_idx. If match, go UPDATE. If scan_idx > max, go UPDATE (no match).
                        // State UPDATE: Set current_index to found_index, update curr_x/y. Increment jump_counter.
                        // If jump_counter < K, go DECODE. Else go FINISH.
                        
                        // This is a clean multi-cycle FSM.
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    final_x <= curr_x;
                    final_y <= curr_y;
                end
            endcase
        end
    end

    // Logic for the SEARCH state (Separated for clarity in code generation)
    // We will implement the FSM logic fully here with the added states.
    // Actually, the always block above is cleaner if we just add more states.
    
    // Re-writing the FSM logic with explicit sequential scan to be robust.
    
    // STATES:
    localparam [2:0] S_IDLE     = 3'd0;
    localparam [2:0] S_DECODE   = 3'd1; // Latch direction
    localparam [2:0] S_SCAN     = 3'd2; // Scan one plant
    localparam [2:0] S_UPDATE   = 3'd3; // Update current position
    localparam [2:0] S_FINISH   = 3'd4;

    reg [2:0] state_r;
    reg [3:0] scan_ptr;
    reg [3:0] best_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r <= S_IDLE;
            current_index <= 4'd0;
            jump_counter <= 4'd0;
            scan_ptr <= 4'd0;
            best_idx <= 4'd0;
            done <= 1'b0;
            curr_x <= 16'd0;
            curr_y <= 16'd0;
            final_x <= 16'd0;
            final_y <= 16'd0;
            found_flag <= 1'b0;
            current_dir <= 2'd0;
        end else begin
            case (state_r)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_index <= 4'd0;
                        curr_x <= plant_x[0];
                        curr_y <= plant_y[0];
                        jump_counter <= 4'd0;
                        if (num_jumps == 4'd0) begin
                            state_r <= S_FINISH;
                        end else begin
                            state_r <= S_DECODE;
                        end
                    end
                end

                S_DECODE: begin
                    // Latch direction for current jump
                    current_dir <= dir_seq[4*jump_counter +: 4];
                    scan_ptr <= current_index + 4'd1; // Start scan from next index
                    best_idx <= current_index;        // Default: stay at current
                    found_flag <= 1'b0;
                    state_r <= S_SCAN;
                end

                S_SCAN: begin
                    // Check plant at scan_ptr
                    if (scan_ptr < num_plants) begin
                        // Calculate dx, dy
                        // Note: plant_x/curr_x are 16 bits. diff needs 17 bits signed.
                        // We use temporary variables for comparison.
                        // To ensure no latch inference, we update best_idx only if a match is found and not already found.
                        
                        // Check conditions
                        // We need to ensure we don't update best_idx if we already found one (priority to lower index)
                        // Actually, since we scan sequentially increasing, the FIRST match is the lowest index.
                        // So we only update if !found_flag.
                        
                        // Direction Logic:
                        // A: dx > 0, dy > 0, dx == dy
                        // B: dx > 0, dy < 0, dx == -dy
                        // C: dx < 0, dy > 0, dx == -dy
                        // D: dx < 0, dy < 0, dx == dy
                        
                        // We need to compute dx and dy for this scan_ptr.
                        // Since arrays are inputs, we access them directly.
                        // We need signed arithmetic.
                        
                        // Note: access to 2D arrays in always blocks can be tricky. 
                        // `plant_x` is input [15:0] plant_x [0:15].
                        // In Icarus, this is unpacked array. It's usually supported for reading in synthesis.
                        
                        // We define local wires for the current comparison to avoid array index issues in complex expressions.
                        // However, we can't easily define wires inside a case block.
                        // We will do the calculation using intermediate registers or just compute inline.
                        
                        // Let's use explicit index checking. This is verbose but safe.
                        // We can't use `scan_ptr` as a variable index for 2D array in some older Verilog, but modern tools support it.
                        // Let's assume `plant_x[scan_ptr]` is valid.
                        
                        reg signed [16:0] dx_curr;
                        reg signed [16:0] dy_curr;
                        dx_curr = signed'({1'b0, plant_x[scan_ptr]}) - signed'({1'b0, curr_x});
                        dy_curr = signed'({1'b0, plant_y[scan_ptr]}) - signed'({1'b0, curr_y});

                        reg match_condition;
                        match_condition = 1'b0;
                        
                        case (current_dir)
                            DIR_A: begin
                                if (dx_curr > 0 && dy_curr > 0 && dx_curr == dy_curr)
                                    match_condition = 1'b1;
                            end
                            DIR_B: begin
                                if (dx_curr > 0 && dy_curr < 0 && dx_curr == -dy_curr)
                                    match_condition = 1'b1;
                            end
                            DIR_C: begin
                                if (dx_curr < 0 && dy_curr > 0 && dx_curr == -dy_curr)
                                    match_condition = 1'b1;
                            end
                            DIR_D: begin
                                if (dx_curr < 0 && dy_curr < 0 && dx_curr == dy_curr)
                                    match_condition = 1'b1;
                            end
                        endcase

                        if (match_condition && !found_flag) begin
                            best_idx <= scan_ptr;
                            found_flag <= 1'b1;
                        end

                        // Move to next
                        scan_ptr <= scan_ptr + 4'd1;
                        // Stay in SCAN state
                        
                    end else begin
                        // Finished scanning all plants
                        state_r <= S_UPDATE;
                    end
                end

                S_UPDATE: begin
                    // Update current index and coordinates
                    current_index <= best_idx;
                    curr_x <= plant_x[best_idx];
                    curr_y <= plant_y[best_idx];
                    
                    // Increment jump counter
                    jump_counter <= jump_counter + 4'd1;

                    // Check if we need more jumps
                    if (jump_counter + 4'd1 < num_jumps) begin
                        state_r <= S_DECODE;
                    end else begin
                        state_r <= S_FINISH;
                    end
                end

                S_FINISH: begin
                    final_x <= curr_x;
                    final_y <= curr_y;
                    done <= 1'b1;
                    state_r <= S_IDLE;
                end

                default: state_r <= S_IDLE;
            endcase
        end
    end

    // Assign state_r to a generic 'state' for compatibility with skeleton if needed, 
    // but we used state_r internally.
    // The module skeleton didn't specify state variable names, so internal is fine.

endmodule