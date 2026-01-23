module jelly_raid (
    input clk,
    input rst_n,
    input start,
    input [2:0] start_row,
    input [2:0] start_col,
    input [2:0] target_row,
    input [2:0] target_col,
    input [7:0] map_data [0:7][0:7],
    input [2:0] m1_path [0:3],
    input [2:0] m2_path [0:3],
    output reg [7:0] min_turns,
    output reg possible
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam COMPUTING = 2'b01;
    localparam DONE = 2'b10;

    // Registers
    reg [1:0] state;
    reg [7:0] t_counter; // Current turn (0 to 255)
    reg [63:0] reachable [0:7]; // Bitmask of reachable positions for current turn
    reg [63:0] next_reachable [0:7]; // Bitmask for next turn
    reg [1:0] m_phase; // 0: forward, 1: backward
    reg [2:0] m1_curr [0:3]; // Current indices for master 1
    reg [2:0] m2_curr [0:3]; // Current indices for master 2

    // Wires for master position calculation
    wire [2:0] m1_pos_r;
    wire [2:0] m1_pos_c;
    wire [2:0] m2_pos_r;
    wire [2:0] m2_pos_c;

    // Wires for detection logic
    wire [7:0] row_mask_m1;
    wire [7:0] row_mask_m2;
    wire [7:0] col_mask_m1 [0:7];
    wire [7:0] col_mask_m2 [0:7];
    wire [7:0] detect_mask_m1 [0:7];
    wire [7:0] detect_mask_m2 [0:7];
    wire [7:0] detect_mask_comb [0:7];

    // Helper for target hit
    reg target_hit;
    integer i, j;

    // Calculate Master 1 Current Position
    // Path: [0:3], cycle length 8. 
    // t=0:0, t=1:1 ... t=3:3, t=4:2, t=5:1, t=6:0, t=7:1 ...
    // Formula: if t%8 < 4 -> t%8; else -> 7 - (t%8).
    // Since indices are 0-3, let's compute index manually.
    // Actually, m1_path is [2:0] input [0:3].
    // We need to map t to an index 0..3.
    wire [2:0] t_mod_8;
    assign t_mod_8 = t_counter[2:0]; // 0..7

    reg [2:0] m1_idx;
    reg [2:0] m2_idx;

    always @(*) begin
        if (t_mod_8 < 4) m1_idx = t_mod_8;
        else m1_idx = 3'd7 - t_mod_8; // 4->3, 5->2, 6->1, 7->0

        if (t_mod_8 < 4) m2_idx = t_mod_8;
        else m2_idx = 3'd7 - t_mod_8;
    end

    // Map path index to actual row/col
    // m1_path stores packed coordinates? No, "input [2:0] m1_path [0:3]"
    // Wait, Verilog doesn't support unpacked arrays in ports easily unless SystemVerilog.
    // Assuming packed or we treat them as separate signals.
    // The prompt says "input [2:0] m1_path [0:3]". This is ambiguous in standard Verilog.
    // I will assume a flattened input or define them as separate regs/wires in the module port list if needed.
    // Given the prompt structure, I will assume they are unpacked arrays for readability.
    // But to be synthesizable and safe, I will access them as if they are defined.
    // Let's define internal arrays to hold inputs.
    reg [2:0] m1_path_reg [0:3];
    reg [2:0] m2_path_reg [0:3];
    reg [7:0] map_reg [0:7][0:7];

    // Master Position Logic (Combinational)
    wire [2:0] m1_r_out = m1_path_reg[m1_idx];
    wire [2:0] m2_r_out = m2_path_reg[m2_idx];
    // The prompt says "m1_path [0:3]". Usually path contains coordinates. 
    // If it's just row indices, we need column. 
    // Wait, standard pathfinding on grid needs (r,c). 
    // The input is described as "input [2:0] m1_path [0:3]". 
    // Interpretation: It's just the row. Or maybe it's packed (row, col).
    // Given [2:0], it's 3 bits. Row is 0-7. Col is 0-7. 
    // A 3-bit value can't hold both (6 bits needed).
    // Possibly it's just the ROW coordinate, and masters patrol horizontally/vertically? 
    // OR, maybe the input is just a list of rows, and masters are at those rows in specific columns?
    // Re-read: "Masters move one step per turn along their path".
    // If input is only [2:0], it implies only one dimension. 
    // Let's assume the input specifies the ROW coordinate, and the Masters stay in a fixed column? 
    // No, "Detection: Child is caught if on same row or column as a master".
    // If we only know row, we don't know column for row detection.
    // If we only know row, we can't detect column detection (except if master is on that row).
    // Maybe the problem implies Masters only change ROW, or only change COLUMN?
    // OR, maybe the input [2:0] is packed: bit 2 is row, bits 1:0 are column? No, that's 0-3.
    // Let's assume the prompt implies Masters are on the Grid, and we need both coords.
    // I'll treat the input `m1_path` as `(row, col)` packed into 3 bits? 
    // `input [2:0] m1_path [0:3]` -> 4 elements of 3 bits. 
    // Let's assume `m1_path` elements are just ROW indices. 
    // Wait, if `map_data` is 8x8, and masters patrol, they need coords.
    // Maybe the masters are restricted to specific columns? 
    // Let's assume `m1_path` stores ROW, and Masters are always at Column 0 (or some fixed col).
    // But `Detection` says "same row or column".
    // If Master is at (Row, Col), and we only know Row from path, we miss Col.
    // Alternative: The input `m1_path` is `[2:0]`, maybe it encodes position in a linear array? 
    // Let's assume the problem implies `m1_path` stores the ROW index, and the Master's Column is fixed (e.g., 0).
    // OR, the prompt is simplified and `m1_path` stores coordinates for one axis only.
    // Given the ambiguity, I will implement a generic path follower.
    // I will assume the input `m1_path` provides the `row` coordinate, and I will assume a constant column (say 0) for masters. 
    // To be more robust, let's check the "same row or column" logic.
    // If Master is (R_m, C_m), Child is (R_c, C_c).
    // Same row: R_m == R_c.
    // Same col: C_m == C_c.
    // Blocked if '#' between.
    // Without C_m, we can't do Same Col.
    // Maybe `m1_path` contains both? `[2:0]` is small.
    // Let's assume `m1_path` is a linear index 0..63, flattened.
    // `input [2:0] m1_path [0:3]` -> 4 indices of 0-7? That doesn't make sense.
    // Let's assume `m1_path` is the ROW, and the Master is ALWAYS at a specific COLUMN (e.g., 0).
    // Or, maybe the Masters move in 1D (Row) and detection is only Row-based?
    // "Same row OR column" suggests 2D.
    // Let's assume `m1_path` is the ROW coordinate. I will set Master Column to 0.
    // If the user intended something else, they'd need to clarify. 
    // Actually, looking at typical puzzles, sometimes Masters patrol specific ROWS.
    // Let's assume `m1_path` stores the ROW coordinate, and the Master stays at Column 0 (or maybe traverses the row?).
    // If Master is at Row X, it blocks the entire Row X (if no obstacle).
    // If Master is at Row X, does it block Column Y? No, unless it's at (X, Y).
    // I will assume Master positions are given by `m1_path` for Row, and Column is 0. 
    // Wait, `map_data` is used for obstacles. 
    // Let's assume `m1_path` stores the ROW index. Master is at that Row, Column 0.
    // This satisfies the input size.

    // Master State Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_turns <= 0;
            possible <= 0;
            // Reset arrays
            for (i = 0; i < 8; i = i + 1) begin
                reachable[i] <= 64'b0;
                next_reachable[i] <= 64'b0;
                m1_path_reg[i] <= 3'b0;
                m2_path_reg[i] <= 3'b0;
                if (i < 4) begin
                    m1_curr[i] <= 3'b0;
                    m2_curr[i] <= 3'b0;
                end
            end
            // map_reg reset not strictly needed if loaded every time, but good practice
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    map_reg[i][j] <= 8'b0;
                end
            end
            t_counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COMPUTING;
                        t_counter <= 0;
                        possible <= 1; // Assume reachable until proven otherwise
                        // Load Inputs
                        // map_data is 8x8 array. We need to register it to save routing/lookup per cycle?
                        // Or use it directly. Let's register to break timing if needed, though 8x8 is small.
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                map_reg[i][j] <= map_data[i][j];
                            end
                        end
                        // Load Paths
                        for (i = 0; i < 4; i = i + 1) begin
                            m1_path_reg[i] <= m1_path[i];
                            m2_path_reg[i] <= m2_path[i];
                        end
                        // Initialize Reachable Set
                        for (i = 0; i < 8; i = i + 1) reachable[i] <= 64'b0;
                        // Check if start is valid
                        // Note: map_data is 0=walkable, 1=blocked. 
                        // But map_reg is [7:0]. We assume bit 0 is column 0.
                        // So map_reg[row][col] is valid if 0.
                        if (map_data[start_row][start_col] == 0) begin
                            reachable[start_row][start_col] <= 1'b1;
                        end else begin
                            possible <= 0; // Start blocked
                            state <= DONE;
                        end
                    end
                end

                COMPUTING: begin
                    // 1. Check if target is reached
                    target_hit <= reachable[target_row][target_col];

                    if (reachable[target_row][target_col]) begin
                        min_turns <= t_counter;
                        state <= DONE;
                    end else if (t_counter == 255) begin
                        possible <= 0;
                        state <= DONE;
                    end else begin
                        // 2. Calculate Detection Masks
                        // We need to calculate where masters are at turn t_counter.
                        // t_counter updates every cycle.
                        // t_mod_8 = t_counter[2:0]

                        // Map index logic
                        reg [2:0] m1_idx_curr;
                        reg [2:0] m2_idx_curr;
                        if (t_counter[2:0] < 4) begin
                            m1_idx_curr = t_counter[2:0];
                            m2_idx_curr = t_counter[2:0];
                        end else begin
                            m1_idx_curr = 7 - t_counter[2:0];
                            m2_idx_curr = 7 - t_counter[2:0];
                        end

                        // Get Master Positions (Row only based on assumption)
                        // Master 1 Row
                        reg [2:0] m1_r;
                        m1_r = m1_path_reg[m1_idx_curr];
                        // Master 2 Row
                        reg [2:0] m2_r;
                        m2_r = m2_path_reg[m2_idx_curr];

                        // Master Columns (Assumed 0 as per earlier deduction)
                        // Wait, if Master is at Row R and Col 0, it blocks Row R and Col 0.
                        // But Col 0 is a whole column. 
                        // Let's assume Master moves on Row axis only, and is at Column 0.
                        // This means Master blocks the entire Row (R, 0..7) and entire Col (0, 0..7).

                        // 3. Prune Reachable Set
                        // Master 1 Detection: Row m1_r, Col m1_c (0)
                        // Master 2 Detection: Row m2_r, Col m2_c (0)

                        // Optimization: Generate Detect Masks
                        // Row Masks: Ones on the row where master is
                        // Col Masks: Ones on the column where master is
                        // Then check blockers.

                        // Row Masks
                        reg [7:0] m1_row_mask_val;
                        reg [7:0] m2_row_mask_val;
                        m1_row_mask_val = 8'b0; m1_row_mask_val[m1_r] = 1'b1;
                        m2_row_mask_val = 8'b0; m2_row_mask_val[m2_r] = 1'b1;

                        // Col Masks (Col 0)
                        reg [7:0] m1_col_mask_val;
                        reg [7:0] m2_col_mask_val;
                        m1_col_mask_val = 8'h01; // Col 0 (bit 0)
                        m2_col_mask_val = 8'h01;

                        // Blockers
                        reg [7:0] blockers_row_m1 [0:7];
                        reg [7:0] blockers_row_m2 [0:7];
                        reg [7:0] blockers_col_m1 [0:7];
                        reg [7:0] blockers_col_m2 [0:7];

                        // We need to check for every position in reachable set if it is spotted.
                        // Instead of iterating all 64, let's build a "Safe Mask".
                        // A position is unsafe if:
                        // 1. It is on Master Row AND there is no '#' between (Child Col, Master Col (0)).
                        //    Since Master Col is 0, path is from Child Col to 0 on the same row.
                        //    Check map_reg[Row][0...ChildCol] or 0..7. 
                        //    Actually, check for '#' in the row between col 0 and col 7?
                        //    "No '#' between them". 
                        //    If Master at (R_m, 0), Child at (R_m, C_c). Check map_reg[R_m][0...C_c].
                        //    If any 1, blocked. 
                        //    Wait, if map has 1=blocked. So we need all 0s.
                        //    So, if (map_reg[R_m][0:C_c] == 0) then visible.
                        //    If (map_reg[R_m][C_c:0] == 0) ... 
                        //    Since Master is at 0, we check 0 to C_c.

                        // 2. Master at (R_m, 0), Child at (R_c, 0). Same col.
                        //    Check map_reg[R_m...R_c][0].

                        // Let's create the masks for the current turn.
                        // We can optimize this by pre-calculating row/col visibility.

                        // For each row 0..7, check if it is visible by Master 1 or 2.
                        // Visible Row R if:
                        //    (Master 1 is at R) AND (map_reg[R][0:7] has no 1 between col 0 and any child col?)
                        //    Wait, the "between" check depends on the child's specific column.
                        //    So we can't just mask the whole row.
                        //    We can only mask the cell if the path is clear.
                        //    Logic: A cell (r, c) is unsafe if:
                        //       (r == m1_r) && (path_clear_row(m1_r, c))
                        //       OR (c == m1_c) && (path_clear_col(m1_c, r))
                        //       OR (r == m2_r) && ...
                        //       OR (c == m2_c) && ...

                        // Path Clear Row(r, c): Check map_reg[r][0] to map_reg[r][c]. No 1s.
                        // Since we are inside a sequential block, we need combinational logic or pre-calc.
                        // We can use a loop to calculate "safe" for each cell? 
                        // 64 cells, 8x8. 
                        // Let's do it sequentially but within one clock cycle.
                        // Since we have 256 cycles budget, 1 cycle per turn is fine.

                        // Step 3a: Prune
                        // Iterate all rows and cols
                        reg [63:0] safe_mask;
                        safe_mask = 64'b0;

                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                if (reachable[i][j]) begin
                                    // Check safety
                                    reg is_spotted;
                                    is_spotted = 0;

                                    // Master 1 (Row m1_r, Col 0)
                                    // Check Row Match
                                    if (i == m1_r) begin
                                        // Check clear path to col 0
                                        // if (j == 0) spotted (on top of master) 
                                        // or if map[i][0..j] clear.
                                        // Since map[i][0] is where master is, if map[i][0] == 1, blocked.
                                        // If j > 0, check 1..j. (Assuming 0 is master).
                                        // Actually, path between. 
                                        // Let's check all cols k between 0 and j (inclusive?)
                                        // Usually "between" means path excluding positions.
                                        // If map[i][0] is blocked, master is blocked (maybe he is blocked there).
                                        // Let's assume Master is physically there, we check path.
                                        // If any obstacle in (0, j), blocked.
                                        reg blocked_row1;
                                        blocked_row1 = 0;
                                        for (int k = 0; k < 8; k++) begin
                                            if (k <= j && map_reg[i][k] == 1) blocked_row1 = 1;
                                        end
                                        // Correction: map is 0=walkable, 1=blocked. 
                                        // Wait, prompt: "Grid map: 0=walkable, 1=blocked".
                                        // So if map is 1, it blocks.
                                        // So if we find a 1, blocked.
                                        // Logic: if (k <= j && map_reg[i][k]) blocked.
                                        // But we need to check if there is ANY blocker.
                                        // Let's optimize: Check if map_reg[i][j:0] contains 1.
                                        // We can reduce the logic.

                                        // Let's use a pre-calculated row visibility array?
                                        // No, doing it in loop is fine for 8x8.
                                        // But we are in always block. We can't use always inside always.
                                        // We can use a function or just unroll manually or use a generate loop? No.
                                        // We will use a helper logic.

                                        // Let's do: 
                                        // If (j == 0) blocked.
                                        // Else if (map_reg[i][0] == 1) blocked.
                                        // Else check 1..j.
                                        // Actually, simpler: check if ANY map_reg[i][k] for k in [0, j] is 1.

                                        // We need to do this for every (i,j) in the loop.
                                        // That's 64 * 8 iterations (max). 512 ops. 
                                        // 512 ops in one clock cycle is tight but possible with pipelining or smaller logic.
                                        // However, we are not pipelining. We have 1 cycle per turn.
                                        // 512 lookups might be slow for high freq, but let's try to be efficient.

                                        // Optimization: 
                                        // We can precompute for the current row i, the "blocked from left" mask.
                                        // But i changes in the loop.

                                        // Let's stick to the requirement: "simplified".
                                        // We can implement a small function or inline logic.
                                        // Since `map_reg` is a register array, access is fast.

                                        // Check Master 1 Row
                                        if (i == m1_r) begin
                                            // Check collision with master at (m1_r, 0)
                                            if (j == 0) is_spotted = 1;
                                            else begin
                                                // Check path 0 to j
                                                // We need to verify no 1s in map_reg[i][0:j]
                                                // In Verilog, we can do reduction OR on a slice if we generate slice.
                                                // map_reg[i][j:0] is not standard if j is variable.
                                                // We must loop.
                                                for (int k = 0; k < 8; k++) begin
                                                    if (k <= j && map_reg[i][k] == 1) is_spotted = 1;
                                                end
                                            end
                                        end

                                        // Check Master 1 Col (Col 0)
                                        if (j == 0) begin
                                            // Check path i to m1_r
                                            // Master is at (m1_r, 0), Child at (i, 0).
                                            if (i == m1_r) is_spotted = 1;
                                            else begin
                                                // Check map_reg[min:max][0]
                                                for (int k = 0; k < 8; k++) begin
                                                    // Check all rows between
                                                    if ((i < m1_r && k >= i && k <= m1_r) || (i > m1_r && k >= m1_r && k <= i)) begin
                                                        if (map_reg[k][0] == 1) is_spotted = 1;
                                                    end
                                                end
                                            end
                                        end
                                    end // End Master 1 checks

                                    // Master 2 (Same logic)
                                    // Row match
                                    if (i == m2_r) begin
                                        if (j == 0) is_spotted = 1;
                                        else begin
                                            for (int k = 0; k < 8; k++) begin
                                                if (k <= j && map_reg[i][k] == 1) is_spotted = 1;
                                            end
                                        end
                                    end
                                    // Col match
                                    if (j == 0) begin
                                        if (i == m2_r) is_spotted = 1;
                                        else begin
                                            for (int k = 0; k < 8; k++) begin
                                                if ((i < m2_r && k >= i && k <= m2_r) || (i > m2_r && k >= m2_r && k <= i)) begin
                                                    if (map_reg[k][0] == 1) is_spotted = 1;
                                                end
                                            end
                                        end
                                    end

                                    if (!is_spotted) safe_mask[i*8 + j] = 1'b1;
                                end
                            end
                        end

                        // Apply Pruning
                        // reachable = safe_mask
                        // But we need to unpack safe_mask into reachable array
                        for (i = 0; i < 8; i = i + 1) begin
                            reachable[i] <= safe_mask[i*8 +: 8];
                        end

                        // Step 3b: Generate Next Reachable (Expansion)
                        // For each safe position, add neighbors (Up, Down, Left, Right, Stay)
                        // We do this on the `reachable` set (which is now safe for current turn).
                        // Wait, order: 
                        // 1. Prune current reachable. (Effective Reachable)
                        // 2. Check if Target in Effective Reachable. -> Done.
                        // 3. Generate Next Reachable from Effective Reachable.
                        // 4. Increment Turn.

                        // We already checked target at start of state logic.
                        // Now generate next_reachable.
                        // We need to clear next_reachable first.
                        for (i = 0; i < 8; i = i + 1) next_reachable[i] <= 64'b0;

                        // Iterate current reachable (which is safe)
                        // We can reuse the `reachable` registers.
                        // We need to generate next_reachable for T+1.

                        // To avoid combinational loop, we can generate next_reachable into temp vars.
                        reg [63:0] next_set;
                        next_set = 64'b0;

                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                if (reachable[i][j]) begin
                                    // Stay
                                    if (map_reg[i][j] == 0) next_set[i*8+j] = 1'b1;
                                    // Up
                                    if (i > 0 && map_reg[i-1][j] == 0) next_set[(i-1)*8+j] = 1'b1;
                                    // Down
                                    if (i < 7 && map_reg[i+1][j] == 0) next_set[(i+1)*8+j] = 1'b1;
                                    // Left
                                    if (j > 0 && map_reg[i][j-1] == 0) next_set[i*8+(j-1)] = 1'b1;
                                    // Right
                                    if (j < 7 && map_reg[i][j+1] == 0) next_set[i*8+(j+1)] = 1'b1;
                                end
                            end
                        end

                        // Update Reachable for next turn
                        for (i = 0; i < 8; i = i + 1) begin
                            reachable[i] <= next_set[i*8 +: 8];
                        end

                        // Increment Turn
                        t_counter <= t_counter + 1;
                    end
                end

                DONE: begin
                    // Stay here until reset or new start? 
                    // Usually stays here. But if start comes again, we handled in IDLE.
                    // If start comes while DONE, we should probably reset.
                    // But we are in DONE. If start triggers, we need to transition to IDLE or COMPUTING.
                    // For simplicity, we assume system stays in DONE until reset.
                    // But to allow restart without reset:
                    if (start) begin
                        state <= IDLE; // Or restart logic?
                        // Better to go to IDLE to re-catch start.
                    end
                end
            endcase
        end
    end

endmodule

// Helper logic: 
// The loops inside always block using 'for (int k=0...)' are SystemVerilog (automatic static local).
// This is generally synthesizable by modern tools.
// If strictly Verilog, we might need to declare k outside, but 'int' is SV.
// To be safe and strictly Verilog 2001, we should avoid 'int' inside always.
// Let's refactor the loops to use integer defined at module level or explicit indices.

module jelly_raid_v2 (
    input clk,
    input rst_n,
    input start,
    input [2:0] start_row,
    input [2:0] start_col,
    input [2:0] target_row,
    input [2:0] target_col,
    input [7:0] map_data [0:7][0:7],
    input [2:0] m1_path [0:3],
    input [2:0] m2_path [0:3],
    output reg [7:0] min_turns,
    output reg possible
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam COMPUTING = 2'b01;
    localparam DONE = 2'b10;

    // Registers
    reg [1:0] state;
    reg [7:0] t_counter;
    reg [63:0] reachable [0:7];
    reg [63:0] map_reg_flat; // Flattened map for easier access? No, keep 2D.
    reg [7:0] map_reg [0:7]; // 8 rows of 8 bits. map_reg[row][col]

    // Path Registers
    reg [2:0] m1_path_reg [0:3];
    reg [2:0] m2_path_reg [0:3];

    // Helper integer for loops
    integer k, i, j;

    // Master Position Logic
    wire [2:0] t_mod_8 = t_counter[2:0];
    wire [2:0] m1_idx = (t_mod_8 < 4) ? t_mod_8 : (3'd7 - t_mod_8);
    wire [2:0] m2_idx = (t_mod_8 < 4) ? t_mod_8 : (3'd7 - t_mod_8);

    wire [2:0] m1_r = m1_path_reg[m1_idx];
    wire [2:0] m2_r = m2_path_reg[m2_idx];

    // Detection Helper Logic (Combinational)
    // We calculate a "spotted" mask based on current reachable and master positions.
    reg [63:0] safe_mask;

    always @(*) begin
        safe_mask = 64'b0;
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (reachable[i][j]) begin
                    reg is_spotted;
                    is_spotted = 0;

                    // --- Master 1 ---
                    // Row Match (Master at (m1_r, 0))
                    if (i == m1_r) begin
                        // Check path from col 0 to j
                        // If j == 0, spotted
                        if (j == 0) is_spotted = 1;
                        else begin
                            // Check map[i][0:j] for obstacles (value 1)
                            // Since j is variable, we loop 0 to 7 and condition
                            for (k = 0; k < 8; k = k + 1) begin
                                if (k <= j && map_reg[i][k]) is_spotted = 1;
                            end
                        end
                    end

                    // Col Match (Master at (m1_r, 0), Child at (i, 0))
                    if (j == 0) begin
                        // Check path from row i to m1_r
                        if (i == m1_r) is_spotted = 1;
                        else begin
                            for (k = 0; k < 8; k = k + 1) begin
                                if (i < m1_r) begin
                                    if (k >= i && k <= m1_r && map_reg[k][0]) is_spotted = 1;
                                end else begin
                                    if (k >= m1_r && k <= i && map_reg[k][0]) is_spotted = 1;
                                end
                            end
                        end
                    end

                    // --- Master 2 ---
                    // Row Match
                    if (i == m2_r) begin
                        if (j == 0) is_spotted = 1;
                        else begin
                            for (k = 0; k < 8; k = k + 1) begin
                                if (k <= j && map_reg[i][k]) is_spotted = 1;
                            end
                        end
                    end

                    // Col Match
                    if (j == 0) begin
                        if (i == m2_r) is_spotted = 1;
                        else begin
                            for (k = 0; k < 8; k = k + 1) begin
                                if (i < m2_r) begin
                                    if (k >= i && k <= m2_r && map_reg[k][0]) is_spotted = 1;
                                end else begin
                                    if (k >= m2_r && k <= i && map_reg[k][0]) is_spotted = 1;
                                end
                            end
                        end
                    end

                    if (!is_spotted) safe_mask[i*8 + j] = 1'b1;
                end
            end
        end
    end

    // Expansion Logic (Combinational)
    reg [63:0] next_set;
    always @(*) begin
        next_set = 64'b0;
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (reachable[i][j]) begin
                    // Stay
                    if (map_reg[i][j] == 0) next_set[i*8+j] = 1'b1;
                    // Up
                    if (i > 0 && map_reg[i-1][j] == 0) next_set[(i-1)*8+j] = 1'b1;
                    // Down
                    if (i < 7 && map_reg[i+1][j] == 0) next_set[(i+1)*8+j] = 1'b1;
                    // Left
                    if (j > 0 && map_reg[i][j-1] == 0) next_set[i*8+(j-1)] = 1'b1;
                    // Right
                    if (j < 7 && map_reg[i][j+1] == 0) next_set[i*8+(j+1)] = 1'b1;
                end
            end
        end
    end

    // State Machine Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_turns <= 0;
            possible <= 0;
            t_counter <= 0;
            for (i = 0; i < 8; i = i + 1) begin
                reachable[i] <= 64'b0;
                map_reg[i] <= 8'b0;
                if (i < 4) begin
                    m1_path_reg[i] <= 3'b0;
                    m2_path_reg[i] <= 3'b0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Load Inputs
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                map_reg[i][j] <= map_data[i][j];
                            end
                        end
                        for (i = 0; i < 4; i = i + 1) begin
                            m1_path_reg[i] <= m1_path[i];
                            m2_path_reg[i] <= m2_path[i];
                        end

                        // Init Reachable
                        for (i = 0; i < 8; i = i + 1) reachable[i] <= 64'b0;

                        if (map_data[start_row][start_col] == 0) begin
                            // Check if start is blocked (if map_data is loaded, we use it)
                            // We need to set the bit. map_reg isn't fully updated until next cycle?
                            // In IDLE, inputs are present on wires. map_reg is for next cycle.
                            // We can set reachable directly from inputs.
                            // But for consistency with loop logic, let's use a temporary set or just set the bit.
                            reachable[start_row][start_col] <= 1'b1;
                            state <= COMPUTING;
                            t_counter <= 0;
                            possible <= 1;
                        end else begin
                            possible <= 0;
                            min_turns <= 0;
                            state <= DONE;
                        end
                    end
                end

                COMPUTING: begin
                    // 1. Check Target in Reachable (Pruned set)
                    // Note: reachable currently holds the set for the PREVIOUS expansion step.
                    // Wait, let's trace the flow.
                    // Cycle N: reachable is set to "safe" positions of Cycle N.
                    // We check target. If found, min_turns = t_counter.
                    // If not, we generate next_reachable (Cycle N+1) and increment t.
                    // So at start of COMPUTING (t=0), reachable is start pos (safe).

                    if (reachable[target_row][target_col]) begin
                        min_turns <= t_counter;
                        state <= DONE;
                    end else if (t_counter >= 255) begin
                        // If t=255 and we haven't found it, we stop.
                        // Note: if t=0, we check start pos. 
                        // t_counter represents current turn.
                        possible <= 0;
                        state <= DONE;
                    end else begin
                        // 2. Prune current reachable using safe_mask
                        // safe_mask is combinational based on current reachable.
                        // Apply safe_mask to reachable.
                        for (i = 0; i < 8; i = i + 1) begin
                            reachable[i] <= safe_mask[i*8 +: 8];
                        end

                        // 3. Generate Next Reachable from Pruned Reachable
                        // But wait, safe_mask is combinational.
                        // If we update reachable to safe_mask, then next_set should be based on safe_mask.
                        // However, next_set is combinational and depends on `reachable`.
                        // There is a race condition here.
                        // `next_set` is always combinational of `reachable`. 
                        // At Cycle N, `reachable` holds set for Cycle N.
                        // `next_set` calculates expansion of Cycle N.
                        // We want to update `reachable` for Cycle N+1.
                        // So we need to take `reachable`, Prune it, then Expand.
                        // Since `safe_mask` is combinational on `reachable` (current), we can use `safe_mask` to drive expansion?
                        // No, `next_set` is combinational on `reachable`.
                        // Let's define `pruned_reachable` as combinational.
                        // Then `next_set` combinational on `pruned_reachable`.
                        // Or, we can do it in two steps in the always block:
                        // a. reachable = safe_mask (where safe_mask depends on old reachable)
                        // b. next_set depends on new reachable? No, that's one cycle delay.

                        // Correct flow:
                        // 1. Read `reachable` (Cycle N).
                        // 2. Compute `safe_reachable` = `reachable` AND safe conditions.
                        // 3. Compute `next_reachable` = neighbors(`safe_reachable`).
                        // 4. Update `reachable` = `next_reachable`.
                        // 5. Increment `t_counter`.

                        // To do this in one clock edge:
                        // We need `safe_reachable` combinational from `reachable`.
                        // Then `next_reachable` combinational from `safe_reachable`.
                        // Then assign `reachable` <= `next_reachable`.

                        // Let's create `safe_reachable` wire.
                        // We already have `safe_mask` which is exactly that.
                        // We need to derive `next_set` from `safe_mask`, not `reachable`.
                        // But `next_set` is defined as combinational on `reachable`.
                        // Let's redefine `next_set` or create a new wire.
                        // Let's create `next_set_from_safe` combinational block.

                        // Revised Logic inside Seq Block:
                        // We need to calculate `next_reachable` based on `safe_mask` (which is based on current `reachable`).
                        // `safe_mask` is combinational.
                        // We need a combinational block `next_calc` that takes `safe_mask` as input and outputs `next_reachable_calc`.

                        // Let's use the existing `next_set` logic but point it to `safe_mask`? 
                        // No, `next_set` uses `reachable`. 
                        // Let's assume `reachable` is updated to `safe_mask` in the previous cycle?
                        // No, we need to do it in one cycle.

                        // Optimization:
                        // Since we need `safe_mask` to compute `next_set`, let's declare `next_set_calc` which uses `safe_mask`.
                        // Then assign `reachable` <= `next_set_calc`.

                        // Define `next_set_calc` combinational.
                        reg [63:0] next_set_calc;
                        next_set_calc = 64'b0;
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                if (safe_mask[i*8 + j]) begin
                                    // Stay
                                    if (map_reg[i][j] == 0) next_set_calc[i*8+j] = 1'b1;
                                    // Up
                                    if (i > 0 && map_reg[i-1][j] == 0) next_set_calc[(i-1)*8+j] = 1'b1;
                                    // Down
                                    if (i < 7 && map_reg[i+1][j] == 0) next_set_calc[(i+1)*8+j] = 1'b1;
                                    // Left
                                    if (j > 0 && map_reg[i][j-1] == 0) next_set_calc[i*8+(j-1)] = 1'b1;
                                    // Right
                                    if (j < 7 && map_reg[i][j+1] == 0) next_set_calc[i*8+(j+1)] = 1'b1;
                                end
                            end
                        end

                        // Update Reachable
                        for (i = 0; i < 8; i = i + 1) begin
                            reachable[i] <= next_set_calc[i*8 +: 8];
                        end

                        // Increment Turn
                        t_counter <= t_counter + 1;
                    end
                end

                DONE: begin
                    if (start) begin
                        // Reset to IDLE to allow restart
                        state <= IDLE;
                        possible <= 0;
                        min_turns <= 0;
                    end
                end
            endcase
        end
    end

endmodule

// The above module is complex due to combinational loops. 
// To ensure robustness and avoid simulation/synthesis errors with nested loops and variable indexing in always blocks,
// a better approach for Verilog is to separate combinational logic into dedicated always @(*) blocks.
// However, the instructions imply a single module. 
// Let's refine the implementation to be cleaner and safer.

// Final clean version:
module jelly_raid (
    input clk,
    input rst_n,
    input start,
    input [2:0] start_row,
    input [2:0] start_col,
    input [2:0] target_row,
    input [2:0] target_col,
    input [7:0] map_data [0:7][0:7],
    input [2:0] m1_path [0:3],
    input [2:0] m2_path [0:3],
    output reg [7:0] min_turns,
    output reg possible
);

    // --- State Machine ---
    localparam IDLE = 0, COMPUTE = 1, DONE = 2;
    reg [1:0] state;

    // --- Datapath Registers ---
    reg [7:0] turn;
    reg [63:0] reachable [0:7]; // reachable[row] is bit mask of cols
    reg [7:0] map_reg [0:7];    // Registered map
    reg [2:0] m1_path_reg [0:3];
    reg [2:0] m2_path_reg [0:3];

    // --- Combinational Wires ---
    // Master Position Logic
    wire [2:0] t_phase = turn[2:0];
    wire [2:0] m1_idx = (t_phase < 4) ? t_phase : (7 - t_phase);
    wire [2:0] m2_idx = (t_phase < 4) ? t_phase : (7 - t_phase);
    wire [2:0] m1_r = m1_path_reg[m1_idx];
    wire [2:0] m2_r = m2_path_reg[m2_idx];

    // Helper for visibility check
    // Check if (row, col) is visible by masters
    wire [63:0] safe_mask;
    generate
        genvar r, c;
        for (r = 0; r < 8; r = r + 1) begin : gen_safe_row
            for (c = 0; c < 8; c = c + 1) begin : gen_safe_col
                // Visibility logic: 
                // 1. Cell must be reachable in current set
                // 2. Not visible by Master 1 (Row m1_r, Col 0)
                // 3. Not visible by Master 2 (Row m2_r, Col 0)
                // Visibility condition:
                //   (r == mX_r) && path_clear_horizontal(mX_r, c)
                //   OR
                //   (c == 0) && path_clear_vertical(mX_r, r)
                // Path clear: no 1s in map_reg between points.

                // We need to compute path_clear efficiently. 
                // Horizontal (m1_r): Check map_reg[m1_r][0:c]
                // Vertical (m1_r): Check map_reg[r:|m1_r][0]

                // Since generate blocks create static logic, we must unroll or use functions.
                // We can create arrays of "clear paths" for rows and cols.
                // Row i clear to col c: !(map_reg[i][0] || ... || map_reg[i][c])
                // Col 0 clear from row r to r2: !(map_reg[r][0] || ... || map_reg[r2][0])
            end
        end
    endgenerate

    // Since generate blocks are verbose for dynamic indexing, let's stick to explicit logic in always blocks
    // which is synthesizable for small sizes like 8x8.

    // --- Next Reachable Logic (Combinational) ---
    // To avoid race conditions, we define a combinational block that computes the NEXT state of reachable.
    // It takes current `reachable`, `map_reg`, and master positions.
    reg [63:0] next_reachable_calc;
    integer i, j, k;

    // Helper: check if (r,c) is safe at current turn
    function automatic logic is_safe(input [2:0] r, input [2:0] c);
        logic unsafe;
        unsafe = 0;
        // Master 1
        if (r == m1_r) begin
            // Check horizontal to col 0
            if (c == 0) unsafe = 1;
            else if (map_reg[r][0]) unsafe = 1; // Blocked at master pos
            else begin
                for (int k = 1; k <= c; k++) if (map_reg[r][k]) unsafe = 1;
            end
        end
        if (c == 0) begin
            // Check vertical to row m1_r
            if (r == m1_r) unsafe = 1;
            else begin
                int low, high;
                low = (r < m1_r) ? r : m1_r;
                high = (r > m1_r) ? r : m1_r;
                for (int k = low; k <= high; k++) if (map_reg[k][0]) unsafe = 1;
            end
        end
        // Master 2
        if (r == m2_r) begin
            if (c == 0) unsafe = 1;
            else if (map_reg[r][0]) unsafe = 1;
            else begin
                for (int k = 1; k <= c; k++) if (map_reg[r][k]) unsafe = 1;
            end
        end
        if (c == 0) begin
            if (r == m2_r) unsafe = 1;
            else begin
                int low, high;
                low = (r < m2_r) ? r : m2_r;
                high = (r > m2_r) ? r : m2_r;
                for (int k = low; k <= high; k++) if (map_reg[k][0]) unsafe = 1;
            end
        end
        is_safe = !unsafe;
    endfunction

    always @(*) begin
        // Default: zero out next
        next_reachable_calc = 64'b0;

        // Iterate current reachable
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (reachable[i][j]) begin
                    // 1. Prune: Only continue if safe
                    if (is_safe(i[2:0], j[2:0])) begin
                        // 2. Expand
                        // Stay
                        if (map_reg[i][j] == 0) next_reachable_calc[i*8+j] = 1'b1;
                        // Up
                        if (i > 0 && map_reg[i-1][j] == 0) next_reachable_calc[(i-1)*8+j] = 1'b1;
                        // Down
                        if (i < 7 && map_reg[i+1][j] == 0) next_reachable_calc[(i+1)*8+j] = 1'b1;
                        // Left
                        if (j > 0 && map_reg[i][j-1] == 0) next_reachable_calc[i*8+(j-1)] = 1'b1;
                        // Right
                        if (j < 7 && map_reg[i][j+1] == 0) next_reachable_calc[i*8+(j+1)] = 1'b1;
                    end
                end
            end
        end
    end

    // --- Sequential Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_turns <= 0;
            possible <= 0;
            turn <= 0;
            // Clear reachable
            for (i = 0; i < 8; i = i + 1) reachable[i] <= 64'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Register inputs
                        for (i = 0; i < 8; i = i + 1) begin
                            map_reg[i] <= map_data[i][0]; // Assuming map_data is packed, or need loop
                            // Wait, map_data is [7:0][0:7]. map_reg is [0:7].
                            // map_reg[i] should be 8 bits.
                            // If map_data is unpacked, we need to copy.
                            // Let's assume map_data[i] is the row.
                            // Actually, input [7:0] map_data [0:7][0:7] is ambiguous.
                            // Usually means map_data[row][col].
                            // Let's assume map_data[row][col] is a wire.
                            for (int c = 0; c < 8; c++) begin
                                map_reg[i][c] <= map_data[i][c];
                            end
                        end
                        for (i = 0; i < 4; i = i + 1) begin
                            m1_path_reg[i] <= m1_path[i];
                            m2_path_reg[i] <= m2_path[i];
                        end

                        // Initialize reachable
                        for (i = 0; i < 8; i = i + 1) reachable[i] <= 64'b0;
                        if (map_data[start_row][start_col] == 0) begin
                            reachable[start_row][start_col] <= 1'b1;
                            turn <= 0;
                            possible <= 1;
                            state <= COMPUTE;
                        end else begin
                            possible <= 0;
                            state <= DONE;
                        end
                    end
                end

                COMPUTE: begin
                    // Check Target in Reachable (before expansion)
                    // Reachable currently holds positions for this turn.
                    if (reachable[target_row][target_col]) begin
                        min_turns <= turn;
                        state <= DONE;
                    end else if (turn >= 255) begin // Max 256 turns (0-255)
                        possible <= 0;
                        state <= DONE;
                    end else begin
                        // Update reachable
                        // next_reachable_calc is combinational based on current reachable
                        // It handles pruning and expansion in one go.
                        for (i = 0; i < 8; i = i + 1) begin
                            reachable[i] <= next_reachable_calc[i*8 +: 8];
                        end
                        turn <= turn + 1;
                    end
                end

                DONE: begin
                    if (start) state <= IDLE; // Allow restart
                end
            endcase
        end
    end

endmodule

// Note on SystemVerilog features: `int` in function loops and array assignment syntax.
// If strictly Verilog 2001, the loops need `integer` variables declared at module scope.
// I'll adjust to be more Verilog compliant just in case.
// Also, `map_data` input handling needs to be robust.

module jelly_raid (
    input clk,
    input rst_n,
    input start,
    input [2:0] start_row,
    input [2:0] start_col,
    input [2:0] target_row,
    input [2:0] target_col,
    input [7:0] map_data [0:7][0:7],
    input [2:0] m1_path [0:3],
    input [2:0] m2_path [0:3],
    output reg [7:0] min_turns,
    output reg possible
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam COMPUTING = 2'b01;
    localparam DONE = 2'b10;

    // Registers
    reg [1:0] state;
    reg [7:0] t_counter;
    reg [63:0] reachable [0:7];
    reg [7:0] map_reg [0:7];
    reg [2:0] m1_path_reg [0:3];
    reg [2:0] m2_path_reg [0:3];

    // Variables for loops
    integer i, j, k;

    // Master Position Logic
    wire [2:0] t_phase = t_counter[2:0];
    wire [2:0] m1_idx = (t_phase < 4) ? t_phase : (7 - t_phase);
    wire [2:0] m2_idx = (t_phase < 4) ? t_phase : (7 - t_phase);
    wire [2:0] m1_r = m1_path_reg[m1_idx];
    wire [2:0] m2_r = m2_path_reg[m2_idx];

    // Combinational Logic for Next State Calculation
    reg [63:0] next_reachable;

    always @(*) begin
        next_reachable = 64'b0;

        // Iterate all positions
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (reachable[i][j]) begin
                    // 1. Check Safety of current position (i,j)
                    reg is_spotted;
                    is_spotted = 0;

                    // Master 1 Checks
                    // Row Match (Master at (m1_r, 0))
                    if (i == m1_r) begin
                        // Check path 0 to j
                        if (j == 0) is_spotted = 1;
                        else if (map_reg[i][0]) is_spotted = 1;
                        else begin
                            for (k = 1; k <= j; k = k + 1) begin
                                if (map_reg[i][k]) is_spotted = 1;
                            end
                        end
                    end
                    // Col Match (Master at (m1_r, 0), Child at (i, 0))
                    if (j == 0) begin
                        if (i == m1_r) is_spotted = 1;
                        else begin
                            // Check vertical path
                            if (i < m1_r) begin
                                for (k = i; k <= m1_r; k = k + 1) begin
                                    if (map_reg[k][0]) is_spotted = 1;
                                end
                            end else begin
                                for (k = m1_r; k <= i; k = k + 1) begin
                                    if (map_reg[k][0]) is_spotted = 1;
                                end
                            end
                        end
                    end

                    // Master 2 Checks (Identical logic)
                    if (i == m2_r) begin
                        if (j == 0) is_spotted = 1;
                        else if (map_reg[i][0]) is_spotted = 1;
                        else begin
                            for (k = 1; k <= j; k = k + 1) begin
                                if (map_reg[i][k]) is_spotted = 1;
                            end
                        end
                    end
                    if (j == 0) begin
                        if (i == m2_r) is_spotted = 1;
                        else begin
                            if (i < m2_r) begin
                                for (k = i; k <= m2_r; k = k + 1) begin
                                    if (map_reg[k][0]) is_spotted = 1;
                                end
                            end else begin
                                for (k = m2_r; k <= i; k = k + 1) begin
                                    if (map_reg[k][0]) is_spotted = 1;
                                end
                            end
                        end
                    end

                    // 2. Expand if not spotted
                    if (!is_spotted) begin
                        // Stay
                        if (map_reg[i][j] == 0) next_reachable[i*8+j] = 1'b1;
                        // Up
                        if (i > 0 && map_reg[i-1][j] == 0) next_reachable[(i-1)*8+j] = 1'b1;
                        // Down
                        if (i < 7 && map_reg[i+1][j] == 0) next_reachable[(i+1)*8+j] = 1'b1;
                        // Left
                        if (j > 0 && map_reg[i][j-1] == 0) next_reachable[i*8+(j-1)] = 1'b1;
                        // Right
                        if (j < 7 && map_reg[i][j+1] == 0) next_reachable[i*8+(j+1)] = 1'b1;
                    end
                end
            end
        end
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_turns <= 0;
            possible <= 0;
            t_counter <= 0;
            for (i = 0; i < 8; i = i + 1) reachable[i] <= 64'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Load Map
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                map_reg[i][j] <= map_data[i][j];
                            end
                        end
                        // Load Paths
                        for (i = 0; i < 4; i = i + 1) begin
                            m1_path_reg[i] <= m1_path[i];
                            m2_path_reg[i] <= m2_path[i];
                        end

                        // Init Reachable
                        for (i = 0; i < 8; i = i + 1) reachable[i] <= 64'b0;

                        // Check start position validity
                        // map_data is 0=walkable. map_reg loads it.
                        // But map_reg updates next cycle. We use map_data here.
                        if (map_data[start_row][start_col] == 0) begin
                            // Set start bit
                            // We can't index with variables in assign inside always usually, but for register it's okay if we generate logic
                            // Let's use a loop to set, or just direct indexing.
                            // reachable[start_row][start_col] <= 1'b1; works in SV, need loop for V2001 usually for array of vectors.
                            // But here reachable is array of 64-bit vectors. 
                            // reachable[row] is 64 bits. 
                            // We can do: reachable[start_row] <= (1 << start_col);
                            // But we need to preserve other bits? No, we clear them first.
                            // Actually, we should clear all, then set start.
                            // We cleared all above. Now set start.
                            reachable[start_row] <= (1 << start_col);
                            t_counter <= 0;
                            possible <= 1;
                            state <= COMPUTING;
                        end else begin
                            possible <= 0;
                            state <= DONE;
                        end
                    end
                end

                COMPUTING: begin
                    // Check if target is reached in CURRENT reachable (which is valid for turn t)
                    // We need to check bit. reachable[target_row][target_col] isn't valid syntax for array of vectors.
                    // We check: (reachable[target_row] >> target_col) & 1
                    if (((reachable[target_row] >> target_col) & 1)) begin
                        min_turns <= t_counter;
                        state <= DONE;
                    end else if (t_counter >= 255) begin
                        possible <= 0;
                        state <= DONE;
                    end else begin
                        // Update reachable with next_reachable
                        for (i = 0; i < 8; i = i + 1) begin
                            reachable[i] <= next_reachable[i*8 +: 8];
                        end
                        t_counter <= t_counter + 1;
                    end
                end

                DONE: begin
                    if (start) state <= IDLE;
                end
            endcase
        end
    end

endmodule
