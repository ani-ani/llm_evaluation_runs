module ZerglingRush (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] config_addr,
    input wire [7:0] config_data,
    input wire [7:0] map_data,
    output reg ready,
    output reg done,
    output reg [7:0] result_addr,
    output reg [7:0] result_data
);

    // Parameters
    localparam [3:0] MAX_N = 8;
    localparam [5:0] MAX_CELLS = 8'd64;
    localparam [3:0] MAX_ZERGS = 4'd16;
    localparam [7:0] MAX_CYCLES = 8'd160;

    // Configuration Registers (1-based address for config_addr)
    reg [3:0] N;          // Grid size (2-8)
    reg [3:0] P1_ATK;     // Attack Upg
    reg [3:0] P1_ARM;     // Armor Upg
    reg [3:0] P2_ATK;     // Attack Upg
    reg [3:0] P2_ARM;     // Armor Upg
    reg [3:0] T;          // Turns (0-15)

    // State Definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_MAP = 4'd1;
    localparam [3:0] SIM_START = 4'd2;
    localparam [3:0] SIM_TURN_DECISION = 4'd3;
    localparam [3:0] SIM_TURN_ATTACK = 4'd4;
    localparam [3:0] SIM_TURN_MOVE = 4'd5;
    localparam [3:0] SIM_TURN_REGEN = 4'd6;
    localparam [3:0] SIM_DONE = 4'd7;
    localparam [3:0] OUTPUT_READ = 4'd8;

    reg [3:0] state;
    reg [3:0] next_state;

    // Internal Counters and Indices
    reg [5:0] cell_idx;        // 0 to 63 (8x8 grid)
    reg [3:0] zerg_idx;        // 0 to 15
    reg [3:0] turn_count;
    reg [7:0] cycle_count;

    // Grid Storage (Dual Bank: current and next state)
    // Cell Format: [7]: Occupied (1), [6]: Owner (1=P1, 0=P2), [5:0]: HP (0-63)
    reg [7:0] grid_a [0:63];
    reg [7:0] grid_b [0:63];
    reg active_bank; // 0 = grid_a is current, 1 = grid_b is current

    // Zergling Decision Storage (from Phase 1 to Phase 5)
    // Stores desired direction (0-7) and if attacking (1) or moving (0)
    // [3:0]: target_cell_idx, [4]: is_attack
    reg [4:0] zerg_action [0:15];
    reg [3:0] zerg_active_count; // Number of zerglings currently alive

    // Temporary Variables for Calculation
    integer i, j;
    reg [5:0] current_cell;
    reg [7:0] current_owner;
    reg [5:0] current_hp;
    reg [7:0] current_occ;
    
    reg [5:0] neighbor_cell;
    reg [7:0] neighbor_owner;
    reg [5:0] neighbor_hp;
    reg [7:0] neighbor_occ;
    
    reg signed [15:0] dist_x;
    reg signed [15:0] dist_y;
    reg [15:0] abs_dx;
    reg [15:0] abs_dy;
    reg [31:0] manhattan_dist;
    reg [31:0] best_dist;
    reg [3:0] best_dir;
    reg best_is_attack;

    // Cell Coordinates
    reg [2:0] cx, cy;
    reg [2:0] nx, ny;

    // --- Helper: Get Owner from ASCII ---
    function [1:0] get_owner_from_ascii;
        input [7:0] char;
        begin
            if (char == "P" || char == "p") get_owner_from_ascii = 2'd1; // P1
            else if (char == "Q" || char == "q") get_owner_from_ascii = 2'd2; // P2
            else get_owner_from_ascii = 2'd0; // Neutral or empty
        end
    endfunction

    // --- Helper: Get HP from ASCII ---
    function [5:0] get_hp_from_ascii;
        input [7:0] char;
        begin
            if (char >= "0" && char <= "9") get_hp_from_ascii = char - "0";
            else if (char >= "A" && char <= "F") get_hp_from_ascii = char - "A" + 8'd10;
            else if (char >= "a" && char <= "f") get_hp_from_ascii = char - "a" + 8'd10;
            else get_hp_from_ascii = 6'd0;
        end
    endfunction

    // --- Helper: Convert to ASCII for Output ---
    function [7:0] to_ascii;
        input [1:0] owner;
        input [5:0] hp;
        input occ;
        begin
            if (!occ) to_ascii = ".";
            else begin
                if (owner == 2'd1) to_ascii = "P"; // P1
                else to_ascii = "Q"; // P2
                // Note: This is simplified. Real spec says just char, but simulation needs state.
                // We will output the stored ASCII char.
            end
        end
    endfunction

    // --- Helper: Get Distance (Manhattan Q8.8) ---
    function [31:0] calc_manhattan;
        input [2:0] x1, y1;
        input [2:0] x2, y2;
        reg signed [15:0] dx, dy;
        begin
            dx = (x1 > x2) ? (x1 - x2) : (x2 - x1);
            dy = (y1 > y2) ? (y1 - y2) : (y2 - y1);
            // Scale up by 256 (8.8 fixed point) for comparison resolution
            // Actually, integer math is fine for comparison, but spec says Q8.8
            // We'll do: (|dx| + |dy|) * 256
            calc_manhattan = (dx + dy) * 256;
        end
    endfunction

    // --- State Transition Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b0;
            done <= 1'b0;
            result_addr <= 8'd0;
            result_data <= 8'd0;
            N <= 4'd0;
            P1_ATK <= 4'd0;
            P1_ARM <= 4'd0;
            P2_ATK <= 4'd0;
            P2_ARM <= 4'd0;
            T <= 4'd0;
            cell_idx <= 6'd0;
            turn_count <= 4'd0;
            cycle_count <= 8'd0;
            zerg_active_count <= 4'd0;
            active_bank <= 1'b0;
            // Initialize grids
            for (i = 0; i < 64; i = i + 1) begin
                grid_a[i] <= 8'b0;
                grid_b[i] <= 8'b0;
                zerg_action[i] <= 5'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b0;
                    if (start) begin
                        // Start configuration phase (implicit) then map load
                        // We rely on config_addr being set before start or handled during IDLE
                        state <= LOAD_MAP;
                        ready <= 1'b1;
                        cell_idx <= 6'd0;
                        active_bank <= 1'b0; // Reset bank to A
                    end
                end

                LOAD_MAP: begin
                    // Wait for map_data input
                    // We assume map_data is valid when ready is high
                    if (ready && cell_idx < (N * N)) begin
                        // Parse input char to cell format
                        // Format: {Occupied(1), Owner(1), HP(6)}
                        // We store this in grid_a (initialization bank)
                        if (map_data != ".") begin
                            grid_a[cell_idx][7] <= 1'b1; // Occupied
                            grid_a[cell_idx][6] <= (map_data == "P" || map_data == "p"); // Owner (1=P1, 0=P2)
                            grid_a[cell_idx][5:0] <= get_hp_from_ascii(map_data);
                        end else begin
                            grid_a[cell_idx] <= 8'd0;
                        end
                        cell_idx <= cell_idx + 6'd1;
                    end
                    
                    if (cell_idx >= (N * N)) begin
                        ready <= 1'b0;
                        state <= SIM_START;
                    end
                end

                SIM_START: begin
                    turn_count <= 4'd0;
                    cycle_count <= 8'd0;
                    zerg_active_count <= 4'd0;
                    // Count initial zerglings
                    for (i = 0; i < MAX_CELLS; i = i + 1) begin
                        if (i < (N*N) && grid_a[i][7]) begin
                            zerg_active_count <= zerg_active_count + 4'd1;
                        end
                    end
                    // Flip bank if needed (simulation always uses grid_a as source for turn 0)
                    active_bank <= 1'b0;
                    if (T > 0 && zerg_active_count > 0) state <= SIM_TURN_DECISION;
                    else state <= SIM_DONE;
                end

                SIM_TURN_DECISION: begin
                    // Iterate through all cells to decide action for each zergling
                    // Max 16 zerglings logic or iterate grid
                    // Use cell_idx for grid scan
                    // Logic in combinational block below updates zerg_action
                    // Once scan complete -> SIM_TURN_ATTACK
                    if (cell_idx < (N * N)) begin
                        // Decisions handled in comb logic or sequential update here
                        // We'll use sequential state traversal
                        // Handled in the comb block triggering next_state
                        // Here we just advance index or switch state
                        // To keep it simple: switch to attack immediately, calc done in comb
                        // Actually, proper way: iterate here.
                    end
                    
                    // To avoid complex iterations in one state, we do it in a burst or split states.
                    // Let's use a loop structure in the comb block to fill zerg_action, 
                    // then move to attack.
                    // We need to reset zerg_action first.
                    // Let's do: 
                    // 1. Reset zerg_action (or clear as we scan)
                    // 2. Scan Grid (0 to N*N-1)
                    // 3. Find targets
                    // 4. Go to Attack
                    
                    // We will implement the calculation logic in the always block associated with next_state
                    // but strictly sequential updates might be cleaner.
                    
                    // Transition to Attack immediately after a "calculation cycle".
                    // Since we can't do it instantly, let's assume "SIM_TURN_DECISION" takes 1 cycle.
                    state <= SIM_TURN_ATTACK;
                    cell_idx <= 6'd0; // Reset for Attack phase iteration
                end

                SIM_TURN_ATTACK: begin
                    // Apply damage based on zerg_action
                    // Iterate zerg_action array
                    // Update HP in a temp buffer or directly? 
                    // SIMULTANEOUS: Read from Bank A, Write to Bank B.
                    
                    if (zerg_idx < zerg_active_count) begin
                        // Process attack for zerg_idx
                        // zerg_action[zerg_idx] contains target info
                        // Apply damage to target cell in grid_b
                    end else begin
                        state <= SIM_TURN_MOVE;
                        zerg_idx <= 4'd0;
                        // Fill holes in grid_b (dead bodies)
                    end
                end

                SIM_TURN_MOVE: begin
                    // Apply movement based on zerg_action
                    // Iterate zerg_action
                    // Check conflicts
                    // Update positions in grid_b
                    if (zerg_idx < zerg_active_count) begin
                        // Process move
                    end else begin
                        state <= SIM_TURN_REGEN;
                        zerg_idx <= 4'd0;
                    end
                end

                SIM_TURN_REGEN: begin
                    // Increment HP < 35 in grid_b
                    // If cell occupied in grid_b
                    if (cell_idx < (N * N)) begin
                        if (grid_b[cell_idx][7] && grid_b[cell_idx][5:0] < 6'd35) begin
                            grid_b[cell_idx][5:0] <= grid_b[cell_idx][5:0] + 6'd1;
                        end
                        cell_idx <= cell_idx + 6'd1;
                    end else begin
                        // Switch Banks
                        active_bank <= 1'b1; // Now Grid B is current
                        // Swap logic conceptually, or just toggle pointer. 
                        // In hardware, we'd copy B to A or swap pointers.
                        // For this sim, we copy B contents back to A (or just toggle flag and use A as scratch next time)
                        // Let's copy B to A for simplicity in the next cycle or logic below.
                        
                        turn_count <= turn_count + 4'd1;
                        cycle_count <= cycle_count + 8'd1;
                        
                        if (turn_count >= T || cycle_count >= MAX_CYCLES || zerg_active_count == 0) begin
                            state <= SIM_DONE;
                        end else begin
                            state <= SIM_TURN_DECISION;
                            // Prepare for next turn: Copy B to A
                            // Since we can't do it all in one cycle easily without loops, 
                            // let's add a "COPY_BACK" state or do it here.
                            // Let's do it here quickly for the active cells.
                            cell_idx <= 6'd0;
                            // We need to copy B to A before next decision.
                            // Actually, let's add a "COPY" sub-state or just handle it.
                            // To keep states clean, we can copy B to A in SIM_START of next turn.
                        end
                    end
                end

                SIM_DONE: begin
                    // Final copy from B to A if simulation ended during regen/move
                    // Or ensure A has the final state.
                    // If active_bank is 1 (B is current), we need to read from B for output.
                    done <= 1'b1;
                    result_addr <= 8'd0;
                    state <= OUTPUT_READ;
                end

                OUTPUT_READ: begin
                    // Output final map
                    // result_addr is the address
                    // result_data is the ASCII char of the cell at result_addr
                    // If result_addr < N*N, increment. Else stop (stay in state or wait).
                    if (result_addr < (N * N)) begin
                        // Read from current bank (active_bank)
                        if (active_bank) begin
                            result_data <= {grid_b[result_addr][6] ? 8'd80 : 8'd81, // 'P' or 'Q'}
                        end else begin
                            result_data <= {grid_a[result_addr][6] ? 8'd80 : 8'd81,
                        end
                        result_addr <= result_addr + 8'd1;
                    end
                    // Stay in state until reset or new start
                end

                default: state <= IDLE;
            endcase
        end
    end

    // --- Combinational Logic for Complex Operations ---
    // This block handles the heavy lifting: Decision, Attack, Move
    
    always @(*) begin
        // Defaults
        next_state = state;
        
        // --- DECISION LOGIC (SIM_TURN_DECISION) ---
        // We need to scan the grid (current bank) and populate zerg_action
        // Since this is complex, we might need a dedicated sub-state or 
        // we perform this logic in the sequential block using a "busy" flag.
        // Given the constraints, let's structure the Decision phase to be fast.
        
        // Actually, let's rewrite the sequential block to be more granular for the simulation steps.
        // 
        // REFACTORED SEQUENTIAL LOGIC FOR SIMULATION:
        // 1. IDLE -> LOAD_MAP (as before)
        // 2. LOAD_MAP -> SIM_INIT (count zergs, reset flags)
        // 3. SIM_INIT -> SIM_DECIDE (scan grid, find targets)
        // 4. SIM_DECIDE -> SIM_ATTACK (apply damage)
        // 5. SIM_ATTACK -> SIM_MOVE (move units)
        // 6. SIM_MOVE -> SIM_REGEN (heal)
        // 7. SIM_REGEN -> SIM_CHECK (check end condition)
        // 8. SIM_CHECK -> LOOP or DONE
    end

    // Re-implementation of Sequential Logic for Clarity and Conformance
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b0;
            done <= 1'b0;
            result_addr <= 8'd0;
            result_data <= 8'd0;
            N <= 4'd0;
            cell_idx <= 6'd0;
            zerg_idx <= 4'd0;
            turn_count <= 4'd0;
            cycle_count <= 8'd0;
            active_bank <= 1'b0;
            // Reset grids
            for (i = 0; i < 64; i = i + 1) begin
                grid_a[i] <= 8'd0;
                grid_b[i] <= 8'd0;
                zerg_action[i] <= 5'b0;
            end
        end else begin
            // Defaults for next state
            next_state = state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Config is handled externally or captured on start
                        // We assume config happens before start or during IDLE
                        // Since config_addr is provided, we can update registers in IDLE
                        if (config_addr == 4'd0) N <= config_data[3:0];
                        else if (config_addr == 4'd1) P1_ATK <= config_data[3:0];
                        else if (config_addr == 4'd2) P1_ARM <= config_data[3:0];
                        else if (config_addr == 4'd3) P2_ATK <= config_data[3:0];
                        else if (config_addr == 4'd4) P2_ARM <= config_data[3:0];
                        else if (config_addr == 4'd5) T <= config_data[3:0];
                        
                        // If start pulse is high, transition to load
                        // Wait for start to go low? No, start is 1-cycle pulse usually.
                        // But here we need to set up.
                        state <= LOAD_MAP;
                        ready <= 1'b1;
                        cell_idx <= 6'd0;
                    end else begin
                        // Capture config
                        if (config_addr == 4'd0) N <= config_data[3:0];
                        else if (config_addr == 4'd1) P1_ATK <= config_data[3:0];
                        else if (config_addr == 4'd2) P1_ARM <= config_data[3:0];
                        else if (config_addr == 4'd3) P2_ATK <= config_data[3:0];
                        else if (config_addr == 4'd4) P2_ARM <= config_data[3:0];
                        else if (config_addr == 4'd5) T <= config_data[3:0];
                    end
                end

                LOAD_MAP: begin
                    if (cell_idx < N * N) begin
                        // Capture map_data
                        // Map format: ASCII char. 
                        // Store in grid_a: {Occupied(1), Owner(1), HP(6)}
                        grid_a[cell_idx][7] <= (map_data != ".");
                        grid_a[cell_idx][6] <= (map_data == "P" || map_data == "p"); // 1 for P1
                        if (map_data >= "0" && map_data <= "9") grid_a[cell_idx][5:0] <= map_data - "0";
                        else if (map_data >= "A" && map_data <= "F") grid_a[cell_idx][5:0] <= map_data - "A" + 10;
                        else if (map_data >= "a" && map_data <= "f") grid_a[cell_idx][5:0] <= map_data - "a" + 10;
                        else grid_a[cell_idx][5:0] <= 6'd0;
                        
                        cell_idx <= cell_idx + 6'd1;
                    end else begin
                        ready <= 1'b0;
                        state <= SIM_START;
                        cell_idx <= 6'd0;
                    end
                end

                SIM_START: begin
                    turn_count <= 4'd0;
                    cycle_count <= 8'd0;
                    active_bank <= 1'b0; // 0 = grid_a active, 1 = grid_b active (current)
                    // For turn 0, we read from grid_a. 
                    // If T > 0, go to decision. Else done.
                    if (T > 0) state <= SIM_DECIDE;
                    else state <= SIM_DONE;
                    zerg_idx <= 4'd0;
                    // Reset zerg_action array
                    for (i = 0; i < 16; i = i + 1) zerg_action[i] <= 5'd0;
                end

                // --- PHASE 1: DECISION ---
                SIM_DECIDE: begin
                    // We need to iterate through all cells in the CURRENT grid (active_bank)
                    // and find all zerglings. For each, find best target.
                    // Since we can't do full scan instantly, we do it index by index.
                    // 
                    // Strategy: Use cell_idx to scan the grid.
                    // If we find a zergling, calculate its action and store in zerg_action[zerg_idx].
                    // Increment zerg_idx.
                    
                    if (cell_idx < N * N) begin
                        // Check if current cell has a zergling
                        if ( (active_bank == 0 && grid_a[cell_idx][7]) || 
                             (active_bank == 1 && grid_b[cell_idx][7]) ) begin
                            
                            // It is a zergling. Find best target.
                            // Get my coordinates
                            cx = cell_idx % N;
                            cy = cell_idx / N;
                            
                            // Default: No target found
                            best_dist = 32'hFFFFFFFF;
                            best_dir = 4'd8;
                            best_is_attack = 1'b0;
                            
                            // Scan neighbors (Attack) and all enemies (Move)
                            // We need to scan the whole grid for enemies to calculate distances.
                            // Given constraints (8x8, 64 cells), this fits in one cycle logic?
                            // No, 64 iterations in comb logic is heavy but possible.
                            // To be safe and verilog compatible, let's do it sequentially.
                            // 
                            // Actually, let's use a temporary index for the inner loop.
                            // This makes the state machine complex. 
                            // 
                            // Compromise: We calculate the best target in the SAME cycle cell_idx increments.
                            // We scan the whole grid (0 to N*N) for this one zergling.
                            // This might take too many cycles if done sequentially.
                            // 
                            // Optimization: We will calculate the action immediately in this state.
                            // We need a temporary loop counter. Let's use `j` as inner scan index.
                            // If `j` < N*N, we are scanning for targets.
                            
                            // To avoid nested states, we will perform the scan logic here.
                            // We need a flag to know if we are scanning or not.
                            // Let's assume `zerg_action` is populated one per cycle? 
                            // No, we have 256 cycles limit. 16 zerglings * 64 checks = 1024 cycles. Too slow.
                            // 
                            // We must do it faster. 
                            // We will use the logic that we iterate `cell_idx` for the CURRENT zergling.
                            // When `cell_idx` reaches N*N, we switch to Attack phase.
                            
                            // Let's use a sub-state or a flag `calc_busy`.
                            // 
                            // Implemented Approach:
                            // 1. `cell_idx` points to current zergling.
                            // 2. `j` (temp) points to potential target cell.
                            // 3. If `j` < N*N, calculate distance. Update best.
                            // 4. If `j` == N*N, store result in `zerg_action`, increment `zerg_idx`, reset `j`, move `cell_idx`.
                            // 5. If `cell_idx` == N*N, go to Attack.
                            
                            // Wait, `j` needs to persist. Let's use `cycle_count` or a dedicated register `target_scan_idx`.
                        end
                        // Increment cell_idx to move to next zergling or next cell
                        cell_idx <= cell_idx + 6'd1;
                    end else begin
                        // Done scanning grid
                        state <= SIM_ATTACK;
                        cell_idx <= 6'd0;
                        zerg_idx <= 4'd0;
                    end
                end

                // --- PHASE 2: ATTACK RESOLUTION ---
                SIM_ATTACK: begin
                    // Apply damage based on zerg_action
                    // zerg_action[i] contains target cell and is_attack flag.
                    // We iterate zerg_idx (0 to 15).
                    // We read from Active Bank, Write to Inactive Bank.
                    
                    if (zerg_idx < 16) begin
                        // If this zergling is active (exists in grid)
                        // Check if zerg_action[zerg_idx] is valid.
                        // We need to map zerg_idx back to grid coordinates. 
                        // This is hard without a list.
                        // 
                        // Alternative: Iterate Grid Cells again. If cell has zerg, apply its stored action.
                        // We need to store actions by Grid Index, not Zerg Index.
                        // 
                        // CORRECTION: Let's store `zerg_action` by Grid Index (0-63).
                        // `zerg_action[grid_idx]`.
                        // So we iterate `cell_idx` 0 to N*N.
                        // 
                        // Let's change `zerg_action` to 64 entries. 64 * 5 bits = 320 bits. 
                        // Acceptable.
                        
                        if (cell_idx < N * N) begin
                            // Check if this cell had a zergling in the Active Bank
                            if ( (active_bank == 0 && grid_a[cell_idx][7]) ||
                                 (active_bank == 1 && grid_b[cell_idx][7]) ) begin
                                
                                // Retrieve action for this cell
                                // If action is Attack (bit 4 set)
                                if (zerg_action[cell_idx][4]) begin
                                    // Apply damage to target cell
                                    // Target cell index is zerg_action[cell_idx][3:0]
                                    // But wait, target cell index needs 6 bits for 64 cells.
                                    // zerg_action is only 5 bits. 
                                    // Wait, 8x8 grid = 64 cells. Address needs 6 bits.
                                    // Spec says 4-bit address? No, grid indices are 6-bit.
                                    // Re-read spec: "config_addr: 4-bit address".
                                    // Result_addr: 8-bit.
                                    // Movement: Target is adjacent cell. 
                                    // Distance calculation: To closest enemy.
                                    // 
                                    // If we store only 4 bits of target, we can't index 64 cells.
                                    // Let's expand zerg_action to 8 bits: [7:2] target_idx, [1] is_attack, [0] valid.
                                end
                            end
                            cell_idx <= cell_idx + 6'd1;
                        end else begin
                            state <= SIM_MOVE;
                            cell_idx <= 6'd0;
                        end
                    end
                end

                // --- PHASE 3: MOVEMENT ---
                SIM_MOVE: begin
                    // Resolve movement
                    // Iterate cells. If action is Move, update Inactive Bank.
                    // Conflict resolution: Check Inactive Bank target cell occupancy.
                    // If occupied, stay (copy old position).
                    // If multiple to same, North/West wins. 
                    // We can do this iteratively.
                    
                    if (cell_idx < N * N) begin
                        // Logic here
                        cell_idx <= cell_idx + 6'd1;
                    end else begin
                        state <= SIM_REGEN;
                        cell_idx <= 6'd0;
                    end
                end

                // --- PHASE 4: REGENERATION ---
                SIM_REGEN: begin
                    // Increment HP < 35
                    // Read from Inactive Bank (which now has moved/attacked units)
                    // Update Inactive Bank.
                    // Then SWAP banks.
                    if (cell_idx < N * N) begin
                        if (active_bank == 0) begin
                            // Current is A, modifying B
                            if (grid_b[cell_idx][7] && grid_b[cell_idx][5:0] < 6'd35) begin
                                grid_b[cell_idx][5:0] <= grid_b[cell_idx][5:0] + 6'd1;
                            end
                        end else begin
                            // Current is B, modifying A
                            if (grid_a[cell_idx][7] && grid_a[cell_idx][5:0] < 6'd35) begin
                                grid_a[cell_idx][5:0] <= grid_a[cell_idx][5:0] + 6'd1;
                            end
                        end
                        cell_idx <= cell_idx + 6'd1;
                    end else begin
                        // Swap banks
                        active_bank <= ~active_bank;
                        
                        // Check termination
                        turn_count <= turn_count + 4'd1;
                        cycle_count <= cycle_count + 8'd1;
                        
                        if (turn_count >= T || cycle_count >= MAX_CYCLES) begin
                            state <= SIM_DONE;
                        end else begin
                            state <= SIM_DECIDE;
                            cell_idx <= 6'd0;
                            // Reset zerg_action for next turn
                            for (i = 0; i < 64; i = i + 1) zerg_action[i] <= 8'd0;
                        end
                    end
                end

                SIM_DONE: begin
                    done <= 1'b1;
                    result_addr <= 8'd0;
                    state <= OUTPUT_READ;
                end

                OUTPUT_READ: begin
                    if (result_addr < N * N) begin
                        // Read from active_bank
                        if (active_bank) begin
                            result_data <= to_ascii_output(grid_b[result_addr]);
                        end else begin
                            result_data <= to_ascii_output(grid_a[result_addr]);
                        end
                        result_addr <= result_addr + 8'd1;
                    end
                    // Stay here
                end
            endcase
        end
    end

    // --- Helper Function for ASCII Output ---
    function [7:0] to_ascii_output;
        input [7:0] cell;
        begin
            if (!cell[7]) to_ascii_output = ".";
            else if (cell[6]) to_ascii_output = "P";
            else to_ascii_output = "Q";
        end
    endfunction

    // --- COMBINATIONAL LOGIC FOR DISTANCE AND ACTION (Decision Phase) ---
    // This handles the complex math inside SIM_DECIDE state.
    // We need to fill `zerg_action` array.
    // Since we can't easily do loops in comb logic without generate, we do it sequentially in the state machine.
    // To make it fit, we need to break down SIM_DECIDE into smaller steps.
    
    // REFINED DECISION LOGIC (Integrated into Sequential FSM):
    // We will add an inner loop state.
    
    // Due to length limits, I will condense the logic.
    // The provided skeleton in the prompt implies a single module.
    // I will modify the FSM to include specific cycles for the math.

endmodule

// Note: The above module structure is correct but the decision logic is implicitly defined.
// To be fully compliant with the "Algorithm Details", I must implement the distance calc.
// Since Verilog requires explicit wiring, I will add the logic blocks below.
// The previous code block was a skeleton. 

// Let's refine the module with a more concrete Decision state implementation.
// We will introduce a state `SIM_DECIDE_SCAN` and `SIM_DECIDE_CALC`.

// FINAL REVISION OF ZerglingRush MODULE WITH CONCRETE LOGIC:

module ZerglingRush (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] config_addr,
    input wire [7:0] config_data,
    input wire [7:0] map_data,
    output reg ready,
    output reg done,
    output reg [7:0] result_addr,
    output reg [7:0] result_data
);

    // --- Parameters ---
    localparam [3:0] MAX_N = 8;
    localparam [5:0] MAX_CELLS = 8'd64;

    // --- State Definitions ---
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_MAP = 4'd1;
    localparam [3:0] SIM_START = 4'd2;
    localparam [3:0] SIM_DECIDE_SCAN = 4'd3; // Scan grid for zergs
    localparam [3:0] SIM_DECIDE_INNER = 4'd4; // Inner loop for distance
    localparam [3:0] SIM_ATTACK = 4'd5;
    localparam [3:0] SIM_MOVE = 4'd6;
    localparam [3:0] SIM_REGEN = 4'd7;
    localparam [3:0] SIM_DONE = 4'd8;
    localparam [3:0] OUTPUT_READ = 4'd9;

    reg [3:0] state;

    // --- Registers ---
    reg [3:0] N;
    reg [3:0] P1_ATK, P1_ARM, P2_ATK, P2_ARM, T;
    reg [5:0] cell_idx; // 0 to 63
    reg [5:0] inner_idx; // 0 to 63 (for scanning targets)
    reg [3:0] turn_count;
    reg [7:0] cycle_count;
    reg active_bank; // 0: A active, 1: B active

    // Grids: {Occupied(1), Owner(1), HP(6)}
    reg [7:0] grid_a [0:63];
    reg [7:0] grid_b [0:63];

    // Action Storage: {Target[5:0], IsAttack(1), Valid(1)} - 8 bits
    reg [7:0] zerg_action [0:63];

    // Temporary registers for calculations
    reg [5:0] current_zerg_idx;
    reg [5:0] target_cell_idx;
    reg [31:0] best_distance;
    reg [5:0] best_target;
    reg best_is_attack;
    
    // Coordinates
    reg signed [15:0] x1, y1, x2, y2, dx, dy;
    reg [15:0] abs_d;

    // --- Sequential Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b0;
            done <= 1'b0;
            result_addr <= 8'd0;
            result_data <= 8'd0;
            N <= 4'd0;
            P1_ATK <= 4'd0;
            P1_ARM <= 4'd0;
            P2_ATK <= 4'd0;
            P2_ARM <= 4'd0;
            T <= 4'd0;
            cell_idx <= 6'd0;
            inner_idx <= 6'd0;
            turn_count <= 4'd0;
            cycle_count <= 8'd0;
            active_bank <= 1'b0;
            current_zerg_idx <= 6'd0;
            best_distance <= 32'hFFFFFFFF;
            best_target <= 6'd0;
            best_is_attack <= 1'b0;
            
            // Initialize grids and actions
            for (int i = 0; i < 64; i++) begin
                grid_a[i] <= 8'd0;
                grid_b[i] <= 8'd0;
                zerg_action[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_MAP;
                        ready <= 1'b1;
                        cell_idx <= 6'd0;
                    end
                    // Configuration capture (always active in IDLE as per spec interpretation)
                    case (config_addr)
                        4'd0: N <= config_data[3:0];
                        4'd1: P1_ATK <= config_data[3:0];
                        4'd2: P1_ARM <= config_data[3:0];
                        4'd3: P2_ATK <= config_data[3:0];
                        4'd4: P2_ARM <= config_data[3:0];
                        4'd5: T <= config_data[3:0];
                    endcase
                end

                LOAD_MAP: begin
                    if (cell_idx < N * N) begin
                        // Parse map_data to grid_a
                        grid_a[cell_idx][7] <= (map_data != ".");
                        grid_a[cell_idx][6] <= (map_data == "P" || map_data == "p");
                        // HP: 0-9, A-F
                        if (map_data >= 8'd48 && map_data <= 8'd57) grid_a[cell_idx][5:0] <= map_data - 8'd48;
                        else if (map_data >= 8'd65 && map_data <= 8'd70) grid_a[cell_idx][5:0] <= map_data - 8'd65 + 10;
                        else if (map_data >= 8'd97 && map_data <= 8'd102) grid_a[cell_idx][5:0] <= map_data - 8'd97 + 10;
                        else grid_a[cell_idx][5:0] <= 6'd0;
                        
                        cell_idx <= cell_idx + 6'd1;
                    end else begin
                        ready <= 1'b0;
                        state <= SIM_START;
                    end
                end

                SIM_START: begin
                    turn_count <= 4'd0;
                    cycle_count <= 8'd0;
                    active_bank <= 1'b0; // Start reading from A
                    if (T > 0) state <= SIM_DECIDE_SCAN;
                    else state <= SIM_DONE;
                    cell_idx <= 6'd0;
                    // Clear actions
                    for (int i = 0; i < 64; i++) zerg_action[i] <= 8'd0;
                end

                // --- DECISION PHASE ---
                // Iterates through all cells to find zerglings.
                // For each zergling, iterates through all cells to find best target.
                // To save states, we combine scanning and calculation.
                SIM_DECIDE_SCAN: begin
                    // Find next zergling
                    if (cell_idx < N * N) begin
                        // Check if occupied in active bank
                        if ((active_bank == 0 && grid_a[cell_idx][7]) || (active_bank == 1 && grid_b[cell_idx][7])) begin
                            // Found zergling at cell_idx
                            current_zerg_idx <= cell_idx;
                            inner_idx <= 6'd0;
                            best_distance <= 32'hFFFFFFFF;
                            best_target <= 6'd0;
                            best_is_attack <= 1'b0;
                            state <= SIM_DECIDE_INNER;
                        end else begin
                            cell_idx <= cell_idx + 6'd1;
                        end
                    end else begin
                        // Done scanning all cells
                        state <= SIM_ATTACK;
                        cell_idx <= 6'd0;
                    end
                end

                SIM_DECIDE_INNER: begin
                    // Scan all cells (inner_idx) to find best target for current_zerg_idx
                    if (inner_idx < N * N) begin
                        // Check if inner_idx contains an enemy
                        // Note: We skip self and empty cells
                        if (inner_idx != current_zerg_idx) begin
                            // Get owner of current zerg and target
                            // current zerg is in active bank. target is in active bank.
                            if ((active_bank == 0 && grid_a[inner_idx][7]) || (active_bank == 1 && grid_b[inner_idx][7])) begin
                                
                                // Check if enemies
                                reg my_owner, target_owner;
                                if (active_bank == 0) begin
                                    my_owner = grid_a[current_zerg_idx][6];
                                    target_owner = grid_a[inner_idx][6];
                                end else begin
                                    my_owner = grid_b[current_zerg_idx][6];
                                    target_owner = grid_b[inner_idx][6];
                                end

                                if (my_owner != target_owner) begin
                                    // Calculate Distance (Manhattan)
                                    // Coordinates: x = idx % N, y = idx / N
                                    x1 = current_zerg_idx % N;
                                    y1 = current_zerg_idx / N;
                                    x2 = inner_idx % N;
                                    y2 = inner_idx / N;
                                    
                                    dx = (x1 > x2) ? (x1 - x2) : (x2 - x1);
                                    dy = (y1 > y2) ? (y1 - y2) : (y2 - y1);
                                    // Use fixed point (scaled by 256) or just integer. Integer is sufficient for comparison.
                                    // But spec says Q8.8. Let's do integer logic, it's equivalent for comparison.
                                    
                                    if (dx + dy < best_distance) begin
                                        best_distance <= dx + dy;
                                        best_target <= inner_idx;
                                        // Check attack range (Manhattan dist = 1)
                                        best_is_attack <= ((dx + dy) == 1);
                                    end else if (dx + dy == best_distance) begin
                                        // Tie breaking: Prefer Attack over Move, then North->Clockwise
                                        // North->Clockwise: Smaller Y, then smaller X.
                                        // But spec says: "Tie-breaking (North -> Clockwise)".
                                        // This usually applies to movement choice if no enemy in range.
                                        // Here it's distance tie. 
                                        // Let's prioritize attacks in tie.
                                        if (best_is_attack && !((dx + dy) == 1)) begin
                                            // Keep existing (which is attack)
                                        end else if (!((dx + dy) == 1) && best_is_attack) begin
                                            // New is move, old is attack -> keep old
                                        end else begin
                                            // Both move or both attack. Tie break by coordinates (N then W)
                                            // N (smaller y) wins. If y same, W (smaller x) wins.
                                            if (y2 < (best_target / N)) begin
                                                best_target <= inner_idx;
                                            end else if (y2 == (best_target / N)) begin
                                                if (x2 < (best_target % N)) begin
                                                    best_target <= inner_idx;
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        inner_idx <= inner_idx + 6'd1;
                    end else begin
                        // Finished scanning for this zergling
                        // Store action
                        // Action format: {Target[5:0], IsAttack(1), Valid(1)}
                        zerg_action[current_zerg_idx] <= {best_target, best_is_attack, 1'b1};
                        
                        // Move to next cell in outer scan
                        cell_idx <= cell_idx + 6'd1;
                        state <= SIM_DECIDE_SCAN;
                    end
                end

                // --- ATTACK PHASE ---
                // Simultaneous damage
                // Read from active_bank, write to !active_bank
                SIM_ATTACK: begin
                    if (cell_idx < N * N) begin
                        // 1. Copy current cell state to inactive bank (default)
                        if (active_bank == 0) begin
                            grid_b[cell_idx] <= grid_a[cell_idx];
                        end else begin
                            grid_a[cell_idx] <= grid_b[cell_idx];
                        end

                        // 2. If this cell is an attacker (has action and is attack), apply damage
                        if (zerg_action[cell_idx][0] && zerg_action[cell_idx][1]) begin
                            // Target is zerg_action[cell_idx][7:2]
                            // Apply damage to target in inactive bank
                            
                            // Note: HP formula. 
                            // Attacker P1: 5 + P1_ATK - Target Armor.
                            // Attacker P2: 5 + P2_ATK - Target Armor.
                            
                            // We need to know target's current HP and Owner to apply damage.
                            // We read target's HP from Active Bank (since damage is simultaneous based on start of turn state).
                            
                            reg [5:0] damage;
                            reg [5:0] target_hp;
                            reg target_owner;
                            
                            if (active_bank == 0) begin
                                target_hp = grid_a[zerg_action[cell_idx][7:2]][5:0];
                                target_owner = grid_a[zerg_action[cell_idx][7:2]][6];
                            end else begin
                                target_hp = grid_b[zerg_action[cell_idx][7:2]][5:0];
                                target_owner = grid_b[zerg_action[cell_idx][7:2]][6];
                            end

                            // Calculate damage
                            // My owner
                            reg my_owner;
                            if (active_bank == 0) my_owner = grid_a[cell_idx][6];
                            else my_owner = grid_b[cell_idx][6];

                            if (my_owner == 1) begin // P1
                                damage = 5 + P1_ATK;
                                if (P2_ARM > damage) damage = 0; else damage = damage - P2_ARM;
                            end else begin // P2
                                damage = 5 + P2_ATK;
                                if (P1_ARM > damage) damage = 0; else damage = damage - P1_ARM;
                            end

                            // Update HP in inactive bank
                            // Check if target is still alive (HP > 0)
                            if (target_hp > 0) begin
                                reg [5:0] new_hp;
                                if (target_hp > damage) new_hp = target_hp - damage;
                                else new_hp = 0;
                                
                                // Perform write to inactive bank
                                if (active_bank == 0) begin // Writing to B
                                    grid_b[zerg_action[cell_idx][7:2]][5:0] <= new_hp;
                                    if (new_hp == 0) grid_b[zerg_action[cell_idx][7:2]][7] <= 1'b0; // Kill
                                end else begin // Writing to A
                                    grid_a[zerg_action[cell_idx][7:2]][5:0] <= new_hp;
                                    if (new_hp == 0) grid_a[zerg_action[cell_idx][7:2]][7] <= 1'b0;
                                end
                            end
                        end
                        
                        cell_idx <= cell_idx + 6'd1;
                    end else begin
                        state <= SIM_MOVE;
                        cell_idx <= 6'd0;
                    end
                end

                // --- MOVEMENT PHASE ---
                // Resolve movement actions
                // Apply to inactive bank.
                // Conflict: If target cell is occupied in inactive bank (by previous moves), stay.
                // North/West priority for multiple to same cell.
                SIM_MOVE: begin
                    if (cell_idx < N * N) begin
                        // Check if this cell has a Move action
                        // And ensure it is still alive (occupancy bit check)
                        reg occ;
                        if (active_bank == 0) occ = grid_a[cell_idx][7];
                        else occ = grid_b[cell_idx][7];
                        
                        if (occ && zerg_action[cell_idx][0] && !zerg_action[cell_idx][1]) begin
                            // It is a valid move
                            reg [5:0] dest = zerg_action[cell_idx][7:2];
                            
                            // Check destination occupancy in INACTIVE bank
                            // Note: INACTIVE bank currently has Attack results (and copied old positions)
                            reg dest_occ;
                            if (active_bank == 0) dest_occ = grid_b[dest][7];
                            else dest_occ = grid_a[dest][7];
                            
                            if (!dest_occ) begin
                                // Move allowed. 
                                // 1. Clear source in inactive bank
                                if (active_bank == 0) grid_b[cell_idx] <= 8'd0;
                                else grid_a[cell_idx] <= 8'd0;
                                
                                // 2. Set destination in inactive bank
                                // Copy stats from Active Bank (original state)
                                if (active_bank == 0) begin
                                    grid_b[dest] <= grid_a[cell_idx];
                                end else begin
                                    grid_a[dest] <= grid_b[cell_idx];
                                end
                            end
                        end
                        cell_idx <= cell_idx + 6'd1;
                    end else begin
                        state <= SIM_REGEN;
                        cell_idx <= 6'd0;
                    end
                end

                // --- REGENERATION PHASE ---
                SIM_REGEN: begin
                    if (cell_idx < N * N) begin
                        // Check if occupied in inactive bank and HP < 35
                        if (active_bank == 0) begin
                            if (grid_b[cell_idx][7] && grid_b[cell_idx][5:0] < 6'd35) begin
                                grid_b[cell_idx][5:0] <= grid_b[cell_idx][5:0] + 6'd1;
                            end
                        end else begin
                            if (grid_a[cell_idx][7] && grid_a[cell_idx][5:0] < 6'd35) begin
                                grid_a[cell_idx][5:0] <= grid_a[cell_idx][5:0] + 6'd1;
                            end
                        end
                        cell_idx <= cell_idx + 6'd1;
                    end else begin
                        // End of Turn
                        active_bank <= ~active_bank; // Switch banks
                        turn_count <= turn_count + 4'd1;
                        cycle_count <= cycle_count + 8'd1;
                        
                        // Check End Conditions
                        if (turn_count >= T || cycle_count >= MAX_CYCLES) begin
                            state <= SIM_DONE;
                        end else begin
                            state <= SIM_DECIDE_SCAN;
                            cell_idx <= 6'd0;
                            // Clear actions for next turn
                            for (int k = 0; k < 64; k++) zerg_action[k] <= 8'd0;
                        end
                    end
                end

                SIM_DONE: begin
                    done <= 1'b1;
                    result_addr <= 8'd0;
                    state <= OUTPUT_READ;
                end

                OUTPUT_READ: begin
                    if (result_addr < N * N) begin
                        // Read from active_bank (which is the FINAL state)
                        if (active_bank) begin
                            if (grid_b[result_addr][7]) begin
                                result_data <= grid_b[result_addr][6] ? "P" : "Q";
                            end else begin
                                result_data <= ".";
                            end
                        end else begin
                            if (grid_a[result_addr][7]) begin
                                result_data <= grid_a[result_addr][6] ? "P" : "Q";
                            end else begin
                                result_data <= ".";
                            end
                        end
                        result_addr <= result_addr + 8'd1;
                    end
                end
            endcase
        end
    end
endmodule