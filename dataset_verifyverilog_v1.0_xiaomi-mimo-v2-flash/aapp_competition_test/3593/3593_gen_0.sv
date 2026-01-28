module tiling_dp_max_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] row_data [0:7][0:2],  // 8 rows, 3 cols, 8-bit each
    input wire [7:0] total_K,
    output reg [15:0] max_sum,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD_ROW   = 3'd1;
    localparam [2:0] PROCESS_K  = 3'd2;
    localparam [2:0] UPDATE_DP  = 3'd3;
    localparam [2:0] NEXT_ROW   = 3'd4;
    localparam [2:0] CALC_FINAL = 3'd5;
    localparam [2:0] FINISHED   = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] row_idx;           // 0 to 7
    reg [4:0] k_idx;             // 0 to 20 (K max is 16, need buffer)
    reg [2:0] prev_mask;         // 0 to 7
    reg [2:0] curr_mask_reg;     // 0 to 7
    reg [7:0] tiles_added;
    reg [15:0] sum_added;
    reg [15:0] current_val;
    reg valid_dp;
    
    // Memory for DP state: dp[k][mask] -> value
    // Dimensions: K max 16, masks 0-7. Size 17 x 8.
    reg [15:0] dp_mem [0:20][0:7];
    reg [15:0] next_dp_mem [0:20][0:7];
    
    // Constants
    localparam [15:0] NEG_INF = 16'h8000;
    localparam [2:0] M0 = 3'b000;
    localparam [2:0] M1 = 3'b001;
    localparam [2:0] M2 = 3'b010;
    localparam [2:0] M3 = 3'b011;
    localparam [2:0] M4 = 3'b100;
    localparam [2:0] M5 = 3'b101;
    localparam [2:0] M6 = 3'b110;
    localparam [2:0] M7 = 3'b111;

    // Current row values
    reg signed [7:0] val_col0, val_col1, val_col2;

    // Loop variables
    integer i, j;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_idx <= 4'd0;
            k_idx <= 5'd0;
            prev_mask <= 3'd0;
            max_sum <= 16'd0;
            done <= 1'b0;
            valid_dp <= 1'b0;
            // Initialize DP memory to NEG_INF
            for (i = 0; i < 21; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    dp_mem[i][j] <= NEG_INF;
                end
            end
        end else begin
            state <= next_state;
            if (state == IDLE && start) begin
                // Reset DP table on start
                dp_mem[0][0] <= 16'd0;
                for (i = 1; i < 21; i = i + 1) begin
                    for (j = 0; j < 8; j = j + 1) begin
                        dp_mem[i][j] <= NEG_INF;
                    end
                end
                row_idx <= 4'd0;
                done <= 1'b0;
            end else if (state == NEXT_ROW) begin
                // Advance row
                row_idx <= row_idx + 4'd1;
            end else if (state == UPDATE_DP) begin
                // Update DP memory with new values
                if (k_idx + tiles_added <= total_K + 4'd5) begin
                    dp_mem[k_idx + tiles_added][curr_mask_reg] <= next_dp_mem[k_idx + tiles_added][curr_mask_reg];
                end
            end
        end
    end

    // Combinational logic
    always @(*) begin
        next_state = state;
        // Default next DP memory copy
        for (i = 0; i < 21; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                next_dp_mem[i][j] = dp_mem[i][j];
            end
        end
        
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_ROW;
            end
            
            LOAD_ROW: begin
                if (row_idx < 8) next_state = PROCESS_K;
                else next_state = CALC_FINAL;
            end
            
            PROCESS_K: begin
                if (k_idx > total_K) next_state = NEXT_ROW;
                else next_state = UPDATE_DP;
            end
            
            UPDATE_DP: begin
                // Process only once per K, then increment k_idx
                next_state = PROCESS_K;
            end
            
            NEXT_ROW: begin
                if (row_idx < 8) next_state = LOAD_ROW;
                else next_state = CALC_FINAL;
            end
            
            CALC_FINAL: begin
                next_state = FINISHED;
            end
            
            FINISHED: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Data loading and DP Update Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            val_col0 <= 8'sd0;
            val_col1 <= 8'sd0;
            val_col2 <= 8'sd0;
            k_idx <= 5'd0;
            prev_mask <= 3'd0;
        end else begin
            if (state == LOAD_ROW) begin
                // Load row values from array input
                val_col0 <= row_data[row_idx][0][7:0];
                val_col1 <= row_data[row_idx][1][7:0];
                val_col2 <= row_data[row_idx][2][7:0];
                k_idx <= 5'd0;
                prev_mask <= 3'd0;
            end else if (state == PROCESS_K) begin
                // Check if current DP state is valid for current K
                if (k_idx <= total_K && dp_mem[k_idx][prev_mask] != NEG_INF) begin
                    // Compute valid tilings for this (k, prev_mask)
                    // 1. Check horizontal tilings
                    // 2. Check vertical tilings
                    // 3. Update next_dp_mem
                    
                    // Logic for tiling generation and update moved to separate always block
                    // to avoid large combinational path or logic errors.
                end
                // Increment counters logic handled in next state transition or here
                if (prev_mask == 3'd7) begin
                    prev_mask <= 3'd0;
                    k_idx <= k_idx + 5'd1;
                end else begin
                    prev_mask <= prev_mask + 5'd1;
                end
            end else if (state == NEXT_ROW) begin
                k_idx <= 5'd0;
                prev_mask <= 3'd0;
            end
        end
    end

    // Helper block to compute DP updates
    // This block computes additions for specific (k_idx, prev_mask) combination
    always @(*) begin
        // Defaults
        tiles_added = 8'd0;
        sum_added = 16'd0;
        current_val = dp_mem[k_idx][prev_mask];
        
        if (state == PROCESS_K && k_idx <= total_K && current_val != NEG_INF) begin
            // We have a valid state. Generate tilings.
            
            // Note: This is complex combinatorial logic.
            // We iterate through valid curr_mask (0-7) and check horizontal placements.
            // Since we can't iterate easily in combinational block without generating
            // all cases, we use a helper function style logic per case.
            
            // However, Verilog doesn't support recursive functions easily for synthesis.
            // We will unroll the logic for each prev_mask.
            
            // To keep it manageable, we assume a structure:
            // For each prev_mask, we try to generate valid curr_mask and tile counts.
            // This is essentially a Per-Row DP. 
            
            // Strategy: Define all valid transitions (prev_mask -> curr_mask) with (tiles_added, sum_added).
            // We generate these offline (conceptually) and code them.
            // But wait, sum_added depends on row values. 
            // So we must compute sum_added dynamically based on row values.
        end
    end

    // To implement the complex update logic, we use a Case statement based on prev_mask.
    // This is the only way to handle 8x8xN states without loops in combinational logic (which maps to state machines anyway).
    
    // We use a generate block to unroll the iteration over curr_mask
    // But since we are in a single always block, we must use if-else chains or case.
    
    // Correct approach for hardware DP:
    // 1. Determine valid (prev_mask, curr_mask) pairs.
    // 2. For each pair, calculate tiles and sum.
    // 3. Update dp[k + tiles][curr_mask].
    
    // We will implement a module that handles the update for the CURRENT (k, prev_mask).
    // We need to iterate curr_mask from 0 to 7.
    
    // Since we can't loop inside always @(*) easily for synthesis of DP array updates,
    // we will generate the update logic explicitly for all 8 prev_masks.
    
    // REVISION: To make this synthesizable and fit the prompt, we will use a helper block
    // that processes ONE specific (k, prev_mask) update in one cycle (or across cycles).
    // Actually, standard practice for small N is to unroll.
    
    // Let's define the transition logic functionally:
    // For a given `prev_mask` (vertical dominoes from above):
    // We need to find `curr_mask` (vertical dominoes starting here) and horizontal tiles.
    // 
    // Algorithm for one row (Permute through K):
    // Load row values.
    // Loop k 0..K:
    //   Loop pm 0..7:
    //     If dp[k][pm] is valid:
    //       Loop cm 0..7:
    //         Check if (pm, cm) is valid (non-overlapping free cells).
    //         Calculate horizontal placements on free cells.
    //         Update dp[k + tiles][cm].
    
    // Since we are doing this in hardware, we iterate `k` in outer loop, `pm` in inner loop.
    // We can process multiple `cm` per cycle, or one per cycle.
    // With small tables (K=16, M=8), we can iterate `cm` (0-7) in an inner loop.
    
    // State: IDLE -> LOAD_ROW -> LOOP_K -> LOOP_PM -> LOOP_CM -> UPDATE -> LOOP_CM -> LOOP_PM -> LOOP_K -> NEXT_ROW
    
    // Let's refine the FSM states to handle the triple loop.
    
endmodule

// Helper module to calculate tilings for a specific row configuration
// This is instantiated inside the main module to keep it clean.
module tiling_row_solver(
    input wire [2:0] prev_mask,
    input wire signed [7:0] v0, v1, v2,
    output reg [2:0] curr_mask,
    output reg [3:0] tiles,
    output reg [15:0] sum,
    output reg valid
);
    // This module generates valid configurations for a row.
    // Since Verilog functions can't have loops, we implement logic directly.
    
    // The logic:
    // 1. Cells covered by prev_mask are unavailable (already covered from below).
    // 2. We can place vertical dominoes (set bit in curr_mask).
    // 3. We can place horizontal dominoes on adjacent free cells.
    
    // We will generate all valid curr_masks for the given prev_mask.
    // But we need to return multiple solutions or iterate them.
    // Ideally, we return one solution at a time.
    // We can pass an index 'iteration' to get the N-th solution.
    // 
    // With 3 columns, the number of valid tilings is small.
    // We can pre-calculate all valid transitions (prev_mask, cm) and possible horizontal additions.
    
    // Let's implement the logic inside the main module using a case statement on prev_mask.
    // We will generate an update signal for each possible (cm, tiles, sum).
    
    // However, to strictly follow the prompt's "module" requirement, we keep it monolithic if possible,
    // or use the helper.
    // 
    // Given the complexity, I will implement the update logic inside the main module's combinational block.
    // The logic will be triggered when (state == PROCESS_K) and valid dp state.
    
    // The missing part of the previous code was the update logic generation.
    // Let's add it to the main module.
}

// Re-integrated Main Module with Update Logic
module TopModule(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] row_data [0:7][0:2],
    input wire [7:0] total_K,
    output reg [15:0] max_sum,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD_ROW   = 3'd1;
    localparam [2:0] LOOP_K     = 3'd2;
    localparam [2:0] LOOP_PM    = 3'd3;
    localparam [2:0] LOOP_CM    = 3'd4;
    localparam [2:0] UPDATE_DP  = 3'd5;
    localparam [2:0] NEXT_ROW   = 3'd6;
    localparam [2:0] CALC_FINAL = 3'd7;

    reg [2:0] state, next_state;
    reg [3:0] r_idx; // 0-7
    reg [4:0] k_idx; // 0-20
    reg [2:0] pm_idx; // prev mask
    reg [2:0] cm_idx; // curr mask

    // DP Memory
    // dp[k][mask] = max sum
    // Size: 21 x 8
    reg [15:0] dp [0:20][0:7];
    
    // Current row values
    reg signed [7:0] rv [0:2];
    
    // Temporary calculation variables
    reg signed [15:0] base_val;
    reg signed [15:0] added_sum;
    reg signed [15:0] new_val;
    reg [3:0] added_tiles;
    reg [15:0] NEG_INF;

    integer i, j;

    // Initialize variables
    initial begin
        NEG_INF = 16'h8000;
    end

    // FSM & Data Path
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            for (i = 0; i < 21; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    dp[i][j] <= NEG_INF;
                end
            end
            done <= 1'b0;
            max_sum <= 16'd0;
            r_idx <= 4'd0;
            k_idx <= 5'd0;
            pm_idx <= 3'd0;
            cm_idx <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        dp[0][0] <= 16'd0;
                        state <= LOAD_ROW;
                        r_idx <= 4'd0;
                    end
                end

                LOAD_ROW: begin
                    // Load row data
                    rv[0] <= row_data[r_idx][0][7:0];
                    rv[1] <= row_data[r_idx][1][7:0];
                    rv[2] <= row_data[r_idx][2][7:0];
                    k_idx <= 5'd0;
                    pm_idx <= 3'd0;
                    state <= LOOP_K;
                end

                LOOP_K: begin
                    if (k_idx > total_K) begin
                        // Finished this row
                        state <= NEXT_ROW;
                    end else begin
                        // Check if current k, pm is valid
                        if (dp[k_idx][pm_idx] != NEG_INF) begin
                            cm_idx <= 3'd0;
                            state <= LOOP_CM;
                        end else begin
                            // Advance pm
                            if (pm_idx == 3'd7) begin
                                pm_idx <= 3'd0;
                                k_idx <= k_idx + 5'd1;
                            end else begin
                                pm_idx <= pm_idx + 3'd1;
                            end
                        end
                    end
                end

                LOOP_CM: begin
                    // Calculate tiles and sum for (pm_idx -> cm_idx)
                    // This involves checking horizontal validity
                    // Validity: 
                    // 1. cm_idx bits cannot overlap with pm_idx (vertical continuity). 
                    //    Actually, pm_idx covers cells from previous row. 
                    //    Current row cells can ONLY be covered by:
                    //    a) Vertical domino from previous row (pm_idx bit set).
                    //    b) Vertical domino starting here (cm_idx bit set).
                    //    c) Horizontal domino (requires free cell).
                    //    d) Empty (if allowed, but we are maximizing sum, so we cover if value > 0?)
                    //    Wait, we must cover cells with exactly K dominoes? 
                    //    "Maximize sum of covered cells". 
                    //    If a cell is NOT covered, we get 0.
                    //    If a cell IS covered, we get its value.
                    //    We must use EXACTLY K dominoes?
                    //    "Given K dominoes, maximize sum". Yes, exactly K.
                    
                    // Constraints:
                    // - Cell j is covered if:
                    //   (pm_idx[j] == 1) OR (cm_idx[j] == 1) OR (horizontal tile covers j)
                    // - Dominoes must not overlap.
                    // - Horizontal tiles occupy 2 adjacent cells (j, j+1).
                    // - Horizontal tiles cannot overlap with verticals (pm or cm).
                    
                    // Let's compute 'free' cells in current row.
                    // Free = !pm_idx[j] && !cm_idx[j]
                    // On free cells, we can place horizontal dominoes.
                    
                    // We need to generate all valid horizontal layouts for a given (pm_idx, cm_idx).
                    // With 3 columns, there are few options:
                    // 1. No horizontal tiles.
                    // 2. Tile at (0,1) -> covers 0, 1. (Requires 0,1 free).
                    // 3. Tile at (1,2) -> covers 1, 2. (Requires 1,2 free).
                    // 4. Both tiles? Impossible on 3 cells.
                    
                    // We will iterate through these horizontal possibilities in the next cycle.
                    // For now, calculate the mandatory part (verticals).
                    
                    added_sum = 16'd0;
                    added_tiles = 4'd0;
                    
                    // Check vertical placements (starting here)
                    // Vertical domino occupies (r, j) and (r+1, j).
                    // If cm_idx[j] == 1, we add value of current cell.
                    // cm_idx cannot overlap with pm_idx. (pm_idx means cell is already occupied from above).
                    if (cm_idx[0] && !pm_idx[0]) begin added_sum = added_sum + rv[0]; added_tiles = added_tiles + 4'd1; end
                    if (cm_idx[1] && !pm_idx[1]) begin added_sum = added_sum + rv[1]; added_tiles = added_tiles + 4'd1; end
                    if (cm_idx[2] && !pm_idx[2]) begin added_sum = added_sum + rv[2]; added_tiles = added_tiles + 4'd1; end
                    
                    // If overlap, this cm_idx is invalid.
                    if ((cm_idx & pm_idx) != 3'd0) begin
                        // Invalid transition, skip to next
                        state <= LOOP_CM_ADVANCE;
                    end else begin
                        // Valid verticals. Now check horizontals.
                        // We iterate horiz_mode: 0=None, 1=Left, 2=Right
                        // We need a small sub-loop or state for this.
                        // Since we are already in LOOP_CM, we can add sub-states.
                        // Or, simply, we can handle 3 horizontal cases in one cycle if we are careful,
                        // but we need to write to dp_mem. 
                        // Writing to dp_mem multiple times in one cycle is okay if indices are unique,
                        // but here indices are same (k+added_tiles, cm_idx) for different horiz layouts?
                        // No, added_sum differs.
                        // So we must iterate.
                        
                        // Let's add HORIZ state.
                        state <= LOOP_HORIZ;
                        horiz_mode <= 3'd0;
                    end
                end

                LOOP_HORIZ: begin
                    // Calculate horizontal tiles based on horiz_mode
                    // 0: None
                    // 1: (0,1)
                    // 2: (1,2)
                    // 3: Done
                    
                    // Calculate temporary sum and tiles for this mode
                    reg signed [15:0] temp_sum;
                    reg [3:0] temp_tiles;
                    reg valid_horiz;
                    
                    temp_sum = added_sum;
                    temp_tiles = added_tiles;
                    valid_horiz = 1'b1;
                    
                    if (horiz_mode == 3'd1) begin
                        // Check (0,1)
                        // Must be free (not covered by pm or cm)
                        if (pm_idx[0] || cm_idx[0] || pm_idx[1] || cm_idx[1]) valid_horiz = 1'b0;
                        else begin
                            temp_sum = temp_sum + rv[0] + rv[1];
                            temp_tiles = temp_tiles + 4'd2;
                        end
                    end else if (horiz_mode == 3'd2) begin
                        // Check (1,2)
                        if (pm_idx[1] || cm_idx[1] || pm_idx[2] || cm_idx[2]) valid_horiz = 1'b0;
                        else begin
                            temp_sum = temp_sum + rv[1] + rv[2];
                            temp_tiles = temp_tiles + 4'd2;
                        end
                    end
                    // Mode 0 is always valid (no horizontal tiles)
                    
                    if (valid_horiz) begin
                        reg [4:0] next_k;
                        next_k = k_idx + temp_tiles;
                        
                        if (next_k <= total_K) begin
                            // Update DP
                            if (dp[next_k][cm_idx] < (dp[k_idx][pm_idx] + temp_sum)) begin
                                dp[next_k][cm_idx] <= dp[k_idx][pm_idx] + temp_sum;
                            end
                        end
                    end
                    
                    // Advance horiz_mode
                    if (horiz_mode == 3'd2) begin
                        state <= LOOP_CM_ADVANCE;
                    end else begin
                        horiz_mode <= horiz_mode + 3'd1;
                    end
                end

                LOOP_CM_ADVANCE: begin
                    if (cm_idx == 3'd7) begin
                        // Done with this (k, pm)
                        state <= LOOP_PM_ADVANCE;
                    end else begin
                        cm_idx <= cm_idx + 3'd1;
                        state <= LOOP_CM;
                    end
                end

                LOOP_PM_ADVANCE: begin
                    if (pm_idx == 3'd7) begin
                        k_idx <= k_idx + 5'd1;
                        pm_idx <= 3'd0;
                        state <= LOOP_K;
                    end else begin
                        pm_idx <= pm_idx + 3'd1;
                        state <= LOOP_K;
                    end
                end

                NEXT_ROW: begin
                    if (r_idx == 3'd7) begin
                        state <= CALC_FINAL;
                    end else begin
                        r_idx <= r_idx + 4'd1;
                        state <= LOAD_ROW;
                    end
                end

                CALC_FINAL: begin
                    // Find max sum for k <= total_K
                    // We scan the dp table. This takes a few cycles.
                    // Let's do it in a loop.
                    if (k_idx <= total_K) begin
                        for (int m = 0; m < 8; m++) begin
                            if (dp[k_idx][m] > max_sum) max_sum <= dp[k_idx][m];
                        end
                        k_idx <= k_idx + 5'd1;
                    end else begin
                        state <= FINISHED;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

    // Registers for sub-states
    reg [2:0] horiz_mode;

endmodule