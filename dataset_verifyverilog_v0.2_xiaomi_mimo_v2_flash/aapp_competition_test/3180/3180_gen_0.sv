module drawing_canvas (
    input clk,
    input rst_n,
    input start,
    input [5:0] cmd_type,
    input [3:0] color,
    input [1:0] x1, y1,
    input [1:0] x2, y2,
    input [1:0] load_idx,
    output reg [3:0] pixel_data,
    output reg [3:0] pixel_addr_x,
    output reg [3:0] pixel_addr_y,
    output reg pixel_wr,
    output reg done
);

    // Constants
    localparam CMD_PAINT = 6'd0;
    localparam CMD_SAVE = 6'd1;
    localparam CMD_LOAD = 6'd2;
    
    localparam MAX_CMDS = 8;
    
    // State Encoding
    localparam IDLE = 4'b0001;
    localparam FETCH_CMD = 4'b0010;
    localparam PAINT_LOOP = 4'b0100;
    localparam OP_EXECUTE = 4'b1000;
    // Note: SAVE/LOAD operations are combinational within OP_EXECUTE or use internal parallel logic.
    // To be safe and strictly sequential for state transitions, we use specific sub-states if needed,
    // but for 4x4 grid, we can do reads/writes in one cycle or a few.
    // However, to strictly follow the request for states like SAVE_OP, LOAD_OP, PAINT_LOOP:
    // Let's refine states: IDLE, FETCH, PAINT, SAVE, LOAD, DONE.
    // Since we need to handle multiple commands (up to 8), we need a command counter.
    
    // Re-defined States for clarity
    localparam S_IDLE = 3'b000;
    localparam S_FETCH = 3'b001;
    localparam S_PAINT = 3'b010;
    localparam S_SAVE = 3'b011;
    localparam S_LOAD = 3'b100;
    localparam S_DONE = 3'b101;

    // Registers for Grid (16x4-bit)
    // Using a 2D array or 16 separate regs. 1D array is easier to iterate.
    reg [3:0] grid [0:15];
    
    // Save Buffers (2 slots of 16x4-bit)
    reg [3:0] save_slot_1 [0:15];
    reg [3:0] save_slot_2 [0:15];
    
    // Internal State Machine Registers
    reg [2:0] state, next_state;
    
    // Command Counter
    reg [3:0] cmd_cnt; // 0 to 8
    
    // Loop Counters for PAINT
    reg [1:0] cx, cy; // Current x, y during paint loop
    
    // Helper wires for boundaries (registered inputs usually, but we use the inputs directly in logic)
    // To make it robust, we latch inputs in FETCH or use them directly in states.
    // Since inputs are held stable, we can use them directly.
    
    // Combinational Logic for Loop Next State
    wire [1:0] cx_next;
    wire [1:0] cy_next;
    wire loop_done;
    
    assign cx_next = (cx == x2) ? 2'b00 : (cx + 1);
    // Next row logic: if we reached x2 and reset x to 0, increment y.
    // If cx is x2, next cycle cx becomes 0, cy becomes cy+1.
    assign cy_next = (cx == x2) ? (cy + 1) : cy;
    
    // Check if loop is complete: current x == x2 AND current y == y2
    assign loop_done = (cx == x2) && (cy == y2);
    
    // Parity Check
    wire parity;
    assign parity = (cx + cy) % 2; // 0 for even, 1 for odd
    
    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next State Logic
    always @(*) begin
        case (state)
            S_IDLE: begin
                if (start && cmd_cnt < MAX_CMDS) next_state = S_FETCH;
                else if (start && cmd_cnt >= MAX_CMDS) next_state = S_DONE; // Edge case
                else next_state = S_IDLE;
            end
            S_FETCH: begin
                // Decode command immediately
                case (cmd_type)
                    CMD_PAINT: next_state = S_PAINT;
                    CMD_SAVE:  next_state = S_SAVE;
                    CMD_LOAD:  next_state = S_LOAD;
                    default:   next_state = S_IDLE; // Unknown cmd, skip or error
                endcase
            end
            S_PAINT: begin
                // We iterate through the rectangle.
                // If loop_done is true after processing the last pixel, we go back to IDLE to fetch next or DONE.
                // Note: In PAINT state, we process one pixel per cycle or handle state transitions inside.
                // To be safe, we stay in PAINT until loop finishes.
                if (loop_done) begin
                    // Just finished the last pixel. Check if we have more commands.
                    if (cmd_cnt + 1 >= MAX_CMDS) next_state = S_DONE;
                    else next_state = S_IDLE; // Go back to IDLE to wait for next command or immediate fetch?
                    // Requirement says: "assume cmd_type, color, etc. are held stable or updated externally, and FSM advances through the internal command queue."
                    // The testbench will drive inputs. We need to increment cmd_cnt.
                    // If we go to IDLE, we might miss the immediate next command if inputs change next cycle.
                    // Better to go to FETCH if more commands expected, or DONE.
                    // But the instruction says IDLE waits for `start`.
                    // Let's assume `start` is a pulse for the whole sequence, or we process M commands after start.
                    // Let's look at: "In IDLE, wait for start signal."
                    // "Assume cmd_type... are held stable or updated externally, and FSM advances through the internal command queue."
                    // This implies we might not need `start` for every command if we are in a burst.
                    // But to strictly follow the spec: "In IDLE, wait for start."
                    // However, the example trace implies a sequence.
                    // Let's implement a counter. If start is high, we process M commands. 
                    // We stay in IDLE until start is high. Once start is high, we process commands continuously until M is reached.
                    // Then we assert done. 
                    // If we go back to IDLE after one command, we need start again. 
                    // But the requirement says "start processing the log".
                    // Let's assume `start` initiates the sequence, then we execute M commands.
                    // So, in IDLE, if start, go to FETCH. 
                    // In FETCH, if we finished a command, go to next state. 
                    // After processing, if cmd_cnt < M-1, go to FETCH (or IDLE if we need start again).
                    // Given the ambiguity, I will implement: 
                    // 1. `start` triggers processing of the ENTIRE log (up to M commands).
                    // 2. Once `done` is asserted, it stays high until reset.
                    // 3. `start` is ignored while processing.
                    // So, after PAINT_LOOP finishes, if we have commands left, we go to FETCH directly (assuming continuous stream).
                    // If `start` is required per command, the user can modify. But for hardware acceleration, continuous is better.
                    // Let's go to FETCH if cmd_cnt < MAX_CMDS - 1 (since we increment at end of op).
                    // Wait, we increment cmd_cnt when operation completes.
                    // If we just finished cmd_cnt, next is cmd_cnt+1. 
                    // If cmd_cnt < MAX_CMDS, go FETCH. Else DONE.
                    next_state = (cmd_cnt < MAX_CMDS) ? S_FETCH : S_DONE;
                end else begin
                    next_state = S_PAINT; // Continue loop
                end
            end
            S_SAVE: begin
                // Save operation is atomic (1 cycle for logic, but FSM transition is immediate)
                // Since we can't write to 16 regs in one line of Verilog without a loop or generate,
                // we need a cycle or we do it inside the state logic.
                // Let's spend 1 cycle here to latch data.
                // Then move to next command.
                next_state = (cmd_cnt < MAX_CMDS) ? S_FETCH : S_DONE;
            end
            S_LOAD: begin
                // Similar to save
                next_state = (cmd_cnt < MAX_CMDS) ? S_FETCH : S_DONE;
            end
            S_DONE: begin
                next_state = S_DONE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    // Datapath Logic (Registers Update)
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset grid and save slots to 0 (or default color)
            for (i = 0; i < 16; i = i + 1) begin
                grid[i] <= 4'b0;
                save_slot_1[i] <= 4'b0;
                save_slot_2[i] <= 4'b0;
            end
            cmd_cnt <= 0;
            done <= 0;
            pixel_wr <= 0;
            // Reset loop vars
            cx <= 0;
            cy <= 0;
        end else begin
            // Default outputs
            pixel_wr <= 0;
            // done stays high if in DONE state
            if (state != S_DONE) done <= 0;
            if (state == S_DONE) done <= 1;
            
            case (state)
                S_IDLE: begin
                    if (start && !done) begin
                        cmd_cnt <= 0;
                        cx <= x1; // Initialize loop start
                        cy <= y1;
                    end
                end
                
                S_FETCH: begin
                    // Just a pass-through state to decode.
                    // Initialize loop vars for PAINT if needed.
                    if (cmd_type == CMD_PAINT) begin
                        cx <= x1;
                        cy <= y1;
                    end
                end
                
                S_PAINT: begin
                    // Process current pixel (cx, cy)
                    // Parity check: 0 is even (update), 1 is odd (skip)
                    if (parity == 0) begin
                        // Update grid
                        // Map 2D (cx, cy) to 1D index: y * 4 + x
                        grid[cy*4 + cx] <= color;
                        
                        // Drive outputs
                        pixel_addr_x <= {2'b00, cx}; // Extend to 4 bit if needed, inputs are 2 bit
                        pixel_addr_y <= {2'b00, cy};
                        pixel_data <= color;
                        pixel_wr <= 1;
                    end
                    
                    // Update loop counters for next cycle
                    if (!loop_done) begin
                        if (cx == x2) begin
                            cx <= 0;
                            cy <= cy + 1;
                        end else begin
                            cx <= cx + 1;
                        end
                    end else begin
                        // Loop finished this cycle. Increment command counter.
                        // Note: If loop_done is true, we are processing the last pixel (x2, y2).
                        // Next state will be FETCH or DONE. We must increment cmd_cnt now.
                        // But wait, if we increment cmd_cnt here, we are incrementing it for the *next* command.
                        // It makes sense to count completed commands.
                        cmd_cnt <= cmd_cnt + 1;
                        // Reset counters for next use
                        cx <= 0;
                        cy <= 0;
                    end
                end
                
                S_SAVE: begin
                    // Copy grid to save buffer
                    // Since we can't iterate in one block effectively without generate or loop,
                    // we rely on the fact that this state is entered and left in one cycle.
                    // We will use a combinational block or do it here with assignments.
                    // Doing 16 assignments in one always block is valid Verilog.
                    // Index mapping: save_slot_1[i] <= grid[i]
                    if (load_idx == 1) begin // Wait, save_idx isn't input. The instruction says "Snapshot... into one of two internal memory banks".
                        // It doesn't specify how to choose the bank for SAVE. 
                        // Usually, SAVE would push to a stack. Or we might need an input. 
                        // The interface only has load_idx for LOAD.
                        // Let's implement a simple stack: SAVE pushes to the next available slot or overwrites 'current'?
                        // Or maybe SAVE is just one slot? No, "Save Slot 1 or 2".
                        // Let's assume we cycle through them or save to both? 
                        // Wait, the description says: "Snapshot... into one of two internal memory banks".
                        // And LOAD takes load_idx. 
                        // Without a specific input for SAVE index, I will implement a rotating counter or just save to Slot 1 then Slot 2 then overwrite Slot 1.
                        // Or, simpler: Use `cmd_type` specific logic? 
                        // Let's use `cmd_cnt` as a pseudo-stack pointer? No.
                        // Let's assume SAVE always overwrites Slot 1? That seems bad.
                        // Let's look at `load_idx`. It selects 1 or 2. 
                        // If SAVE had no index, maybe we just save to 'current' context? 
                        // Given strict constraints and no index for save, I will save to BOTH slots? 
                        // No, that wastes space.
                        // Let's invent a logic: Since we have M=8 commands, let's say SAVE increments an internal pointer `sp`, LOAD decrements it? 
                        // No, that's stack. 
                        // Let's assume SAVE writes to a buffer indexed by `sp` (stack pointer). 
                        // Let's implement a standard stack: 
                        // SAVE: push current grid to stack. 
                        // LOAD: pop from stack (or just read by index). 
                        // The requirement says "LOAD index (1-2)". This implies random access, not strict stack pop.
                        // So, SAVE must decide where to put data. 
                        // I will use a simple counter `save_ptr` that cycles 1->2->1.
                        // But to be safe and simple for the testbench: 
                        // Let's just save to Slot 1 if we haven't used it, else Slot 2? 
                        // Or, strictly: The user might intend to drive `color` or `x1` to select slot? 
                        // Since it's not specified, I will use an internal register `current_save_slot` that toggles on every SAVE.
                        
                        // Implementation:
                        // Use `current_save_slot` reg.
                        // If current_save_slot == 0, save to slot 1, set to 1.
                        // If current_save_slot == 1, save to slot 2, set to 0.
                        // But wait, this creates a ring buffer. 
                        // If user does SAVE, LOAD 1, then SAVE again, slot 1 is overwritten. 
                        // This is acceptable for simulation unless specified otherwise.
                        
                        // Let's do it: 
                        // We need to know which slot to write to. 
                        // Let's use a register `save_ptr`.
                        // If `save_ptr` is 0, write to slot 1. If 1, write to slot 2. 
                        // Then increment `save_ptr`. 
                        // But LOAD takes an index. So we need to map `save_ptr` to index 1 or 2.
                        // Let's say: 
                        // `save_ptr` 0 -> Slot 1
                        // `save_ptr` 1 -> Slot 2
                        // Next SAVE: `save_ptr` becomes 2? No, only 2 slots. 
                        // Let's just overwrite Slot 1 then Slot 2 then Slot 1...
                    end
                    
                    // To implement the update: 
                    // We will update registers based on `save_ptr`.
                    // We need a way to persist `save_ptr` across cycles.
                    // Let's add `reg save_ptr`.
                    // In S_SAVE state:
                    if (!save_ptr) begin // save_ptr 0 -> Slot 1
                        save_slot_1[0] <= grid[0]; save_slot_1[1] <= grid[1]; save_slot_1[2] <= grid[2]; save_slot_1[3] <= grid[3];
                        save_slot_1[4] <= grid[4]; save_slot_1[5] <= grid[5]; save_slot_1[6] <= grid[6]; save_slot_1[7] <= grid[7];
                        save_slot_1[8] <= grid[8]; save_slot_1[9] <= grid[9]; save_slot_1[10] <= grid[10]; save_slot_1[11] <= grid[11];
                        save_slot_1[12] <= grid[12]; save_slot_1[13] <= grid[13]; save_slot_1[14] <= grid[14]; save_slot_1[15] <= grid[15];
                    end else begin // save_ptr 1 -> Slot 2
                        save_slot_2[0] <= grid[0]; save_slot_2[1] <= grid[1]; save_slot_2[2] <= grid[2]; save_slot_2[3] <= grid[3];
                        save_slot_2[4] <= grid[4]; save_slot_2[5] <= grid[5]; save_slot_2[6] <= grid[6]; save_slot_2[7] <= grid[7];
                        save_slot_2[8] <= grid[8]; save_slot_2[9] <= grid[9]; save_slot_2[10] <= grid[10]; save_slot_2[11] <= grid[11];
                        save_slot_2[12] <= grid[12]; save_slot_2[13] <= grid[13]; save_slot_2[14] <= grid[14]; save_slot_2[15] <= grid[15];
                    end
                    // Update command counter
                    cmd_cnt <= cmd_cnt + 1;
                end
                
                S_LOAD: begin
                    // Restore grid from specified slot
                    // load_idx is 1 or 2 (input is 2 bits, so 0,1,2,3. Mask it or check range)
                    // We assume load_idx 1 or 2 are valid. 
                    if (load_idx == 2'd1) begin
                        grid[0] <= save_slot_1[0]; grid[1] <= save_slot_1[1]; grid[2] <= save_slot_1[2]; grid[3] <= save_slot_1[3];
                        grid[4] <= save_slot_1[4]; grid[5] <= save_slot_1[5]; grid[6] <= save_slot_1[6]; grid[7] <= save_slot_1[7];
                        grid[8] <= save_slot_1[8]; grid[9] <= save_slot_1[9]; grid[10] <= save_slot_1[10]; grid[11] <= save_slot_1[11];
                        grid[12] <= save_slot_1[12]; grid[13] <= save_slot_1[13]; grid[14] <= save_slot_1[14]; grid[15] <= save_slot_1[15];
                    end else begin
                        // Default to slot 2 if not 1 (assuming input correctness)
                        grid[0] <= save_slot_2[0]; grid[1] <= save_slot_2[1]; grid[2] <= save_slot_2[2]; grid[3] <= save_slot_2[3];
                        grid[4] <= save_slot_2[4]; grid[5] <= save_slot_2[5]; grid[6] <= save_slot_2[6]; grid[7] <= save_slot_2[7];
                        grid[8] <= save_slot_2[8]; grid[9] <= save_slot_2[9]; grid[10] <= save_slot_2[10]; grid[11] <= save_slot_2[11];
                        grid[12] <= save_slot_2[12]; grid[13] <= save_slot_2[13]; grid[14] <= save_slot_2[14]; grid[15] <= save_slot_2[15];
                    end
                    // Update command counter
                    cmd_cnt <= cmd_cnt + 1;
                end
                
                S_DONE: begin
                    // Nothing to do, done is asserted
                end
            endcase
        end
    end
    
    // Internal register for SAVE pointer (not specified in interface, so internal)
    reg save_ptr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            save_ptr <= 0;
        end else if (state == S_SAVE) begin
            save_ptr <= ~save_ptr; // Toggle 0<->1
        end
    end

endmodule