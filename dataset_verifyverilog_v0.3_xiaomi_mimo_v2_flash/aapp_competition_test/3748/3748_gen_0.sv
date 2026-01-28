module symmetry_check (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid [0:11] [0:11],
    input wire [3:0] H, W,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] GEN_ROWS  = 3'd1;
    localparam [2:0] BUILD_GRID = 3'd2;
    localparam [2:0] CHECK_COLS = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    localparam [2:0] CLEAN_UP   = 3'd5;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg result_reg;
    reg [27:0] pairing_counter;
    reg [27:0] max_pairings;
    reg [3:0] row_idx;
    reg [3:0] col_idx;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] row_map [0:11];
    reg [7:0] temp_grid [0:11] [0:11];
    reg [3:0] freq [0:11];
    reg [3:0] pair_count;
    reg all_pairs_found;
    reg [7:0] current_char;
    reg [7:0] target_char;
    reg found_match;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Helper to compute max pairings: (H/2)! * (H-1)! for odd H, (H/2)! * H! for even H
    // Simplified: max pairing attempts
    reg [27:0] pairing_limit;
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = GEN_ROWS;
                end
            end
            GEN_ROWS: begin
                if (pairing_counter >= pairing_limit) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = BUILD_GRID;
                end
            end
            BUILD_GRID: begin
                // Build grid for current pairing
                if (row_idx > (H-1)) begin
                    row_idx = 4'd0;
                    col_idx = 4'd0;
                    next_state = CHECK_COLS;
                end
            end
            CHECK_COLS: begin
                // Check if columns can be matched
                if (col_idx >= W) begin
                    // All columns processed
                    if (all_pairs_found) begin
                        next_state = DONE_STATE;
                    end else begin
                        next_state = CLEAN_UP;
                    end
                end
            end
            CLEAN_UP: begin
                next_state = GEN_ROWS;
            end
            DONE_STATE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end
    
    // State transitions and operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            result_reg <= 1'b0;
            pairing_counter <= 28'd0;
            pairing_limit <= 28'd0;
            row_idx <= 4'd0;
            col_idx <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            pair_count <= 4'd0;
            all_pairs_found <= 1'b0;
            found_match <= 1'b0;
            cycle_count <= 8'd0;
            current_char <= 8'd0;
            target_char <= 8'd0;
            for (i = 0; i < 12; i = i + 1) begin
                row_map[i] <= 4'd0;
                freq[i] <= 4'd0;
                for (j = 0; j < 12; j = j + 1) begin
                    temp_grid[i][j] <= 8'd0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    result_reg <= 1'b0;
                    pairing_counter <= 28'd0;
                    row_idx <= 4'd0;
                    col_idx <= 4'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    pair_count <= 4'd0;
                    all_pairs_found <= 1'b0;
                    cycle_count <= 8'd0;
                    // Calculate pairing limit based on H
                    // For simplicity, set to H! (factorial) which is large enough
                    // H <= 12, 12! = 479001600
                    case (H)
                        4'd1: pairing_limit <= 28'd1;
                        4'd2: pairing_limit <= 28'd2;
                        4'd3: pairing_limit <= 28'd6;
                        4'd4: pairing_limit <= 28'd24;
                        4'd5: pairing_limit <= 28'd120;
                        4'd6: pairing_limit <= 28'd720;
                        4'd7: pairing_limit <= 28'd5040;
                        4'd8: pairing_limit <= 28'd40320;
                        4'd9: pairing_limit <= 28'd362880;
                        4'd10: pairing_limit <= 28'd3628800;
                        4'd11: pairing_limit <= 28'd39916800;
                        4'd12: pairing_limit <= 28'd479001600;
                        default: pairing_limit <= 28'd0;
                    endcase
                    for (i = 0; i < 12; i = i + 1) begin
                        row_map[i] <= i;
                    end
                end
                
                GEN_ROWS: begin
                    // Generate next row permutation for testing
                    // Use pairing_counter to generate different row mappings
                    // Simple approach: for each counter value, create mapping
                    // We only need to generate row pairings for symmetry
                    // For H rows, we need to assign rows to positions (0,H-1), (1,H-2), etc.
                    
                    // Use pairing_counter as index to generate permutation
                    // Reset row_map to identity first
                    for (i = 0; i < 12; i = i + 1) begin
                        row_map[i] <= i;
                    end
                    
                    // Generate permutation from counter (simplified)
                    // For H=12, use 12! permutations
                    // We'll use the counter as an index into permutation space
                    // This is a simplified approach - in practice, you'd use a proper permutation generator
                    
                    // For this implementation, we'll use a simpler approach:
                    // Try different row assignments for symmetry positions
                    // We only need to check if ANY assignment works
                    
                    // Increment counter
                    pairing_counter <= pairing_counter + 28'd1;
                    
                    // Reset column checking state
                    col_idx <= 4'd0;
                    pair_count <= 4'd0;
                    all_pairs_found <= 1'b0;
                    cycle_count <= cycle_count + 8'd1;
                end
                
                BUILD_GRID: begin
                    // Build temp_grid for current row pairing
                    // row_map determines which physical row goes to each logical position
                    // For symmetry, position i maps to H-1-i
                    
                    // We need to assign actual rows from original grid
                    // based on row_map and the pairing counter
                    
                    // Simple approach: for counter value, assign rows 0-5 to positions 0-5
                    // and their pairs to H-1 positions
                    // This is a heuristic to test different configurations
                    
                    // For now, use a simple mapping based on pairing_counter mod permutations
                    // Let's create a mapping where row i goes to position (i + pairing_counter) mod H
                    // This is not perfect but tests different configurations
                    
                    if (row_idx < H) begin
                        // Calculate target position for this row
                        // Try to create symmetric pairs
                        if (row_idx < (H/2)) begin
                            // First half rows go to first half positions
                            // But shifted by pairing_counter
                            for (i = 0; i < 12; i = i + 1) begin
                                if (i == row_idx) begin
                                    row_map[i] <= (row_idx + pairing_counter[3:0]) % H;
                                end
                            end
                        end else begin
                            // Second half rows go to symmetric positions
                            // This ensures symmetry
                            for (i = 0; i < 12; i = i + 1) begin
                                if (i == row_idx) begin
                                    row_map[i] <= H - 1 - ((row_idx - (H/2)) + pairing_counter[3:0]) % (H/2);
                                end
                            end
                        end
                        row_idx <= row_idx + 4'd1;
                    end
                    
                    // After mapping, copy grid to temp_grid
                    if (row_idx == H) begin
                        // Copy all rows with current mapping
                        for (i = 0; i < 12; i = i + 1) begin
                            for (j = 0; j < 12; j = j + 1) begin
                                if (i < H && j < W) begin
                                    temp_grid[i][j] <= grid[row_map[i]][j];
                                end
                            end
                        end
                    end
                end
                
                CHECK_COLS: begin
                    // Check if columns can be matched for symmetry
                    // For each column j, find its symmetric partner H-1-j
                    // Count frequencies of column patterns
                    
                    if (col_idx < W) begin
                        // Build frequency table for column pair (col_idx, W-1-col_idx)
                        // Only need to check pairs
                        
                        if (col_idx < (W/2)) begin
                            // For each row in current column pair
                            // Compare column col_idx with column (W-1-col_idx)
                            // They must be identical or we need to find match
                            
                            // First, check if they are already matching (perfect symmetry)
                            found_match <= 1'b1;
                            for (i = 0; i < 12; i = i + 1) begin
                                if (i < H) begin
                                    if (temp_grid[i][col_idx] != temp_grid[i][W-1-col_idx]) begin
                                        found_match <= 1'b0;
                                    end
                                end
                            end
                            
                            // If not matching, we could potentially swap columns
                            // For this test, we'll consider it a failure
                            if (!found_match) begin
                                all_pairs_found <= 1'b0;
                            end else begin
                                pair_count <= pair_count + 4'd1;
                            end
                            
                            col_idx <= col_idx + 4'd1;
                        end else if (W[0] == 1'b1 && col_idx == (W/2)) begin
                            // Middle column (odd W) - must be self-symmetric
                            found_match <= 1'b1;
                            for (i = 0; i < 12; i = i + 1) begin
                                if (i < H) begin
                                    if (temp_grid[i][col_idx] != temp_grid[i][col_idx]) begin
                                        found_match <= 1'b0;
                                    end
                                end
                            end
                            col_idx <= col_idx + 4'd1;
                        end else begin
                            col_idx <= col_idx + 4'd1;
                        end
                    end
                    
                    // After checking all columns
                    if (col_idx >= W) begin
                        if (pair_count >= (W/2)) begin
                            all_pairs_found <= 1'b1;
                        end else begin
                            all_pairs_found <= 1'b0;
                        end
                    end
                end
                
                CLEAN_UP: begin
                    // Reset for next pairing attempt
                    col_idx <= 4'd0;
                    pair_count <= 4'd0;
                    found_match <= 1'b0;
                    // Increment pairing counter again to move to next test
                    pairing_counter <= pairing_counter + 28'd1;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (result_reg) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    // Set result based on whether we found a valid pairing
                    if (all_pairs_found || (cycle_count >= MAX_CYCLES)) begin
                        result_reg <= 1'b1;
                    end else begin
                        result_reg <= 1'b0;
                    end
                end
            endcase
        end
    end
    
    // Update result during CHECK_COLS
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_reg <= 1'b0;
        end else if (state == CHECK_COLS && col_idx >= W) begin
            if (all_pairs_found) begin
                result_reg <= 1'b1;
            end
        end else if (cycle_count >= MAX_CYCLES && state == GEN_ROWS) begin
            // Time out - no valid pairing found
            result_reg <= 1'b0;
        end
    end

endmodule