module MaxDisarm(
    input clk,
    input rst_n,
    input start,
    input grid_valid,
    input [2:0] grid_row,
    input [2:0] grid_col,
    input is_bomb,
    output reg [3:0] result,
    output reg done,
    output reg busy
);

    // Internal memory: 8x8 grid
    reg [7:0] grid [0:7];  // Each row is 8 bits
    integer i;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT = 3'd1;
    localparam [2:0] SETUP = 3'd2;
    localparam [2:0] SEARCH = 3'd3;
    localparam [2:0] MATCHING = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Matching arrays
    reg [2:0] match_right [0:7];  // match_right[col] = row index
    reg seen [0:7];                // Visited array for DFS
    reg [2:0] current_row;         // Iterating through rows
    reg [2:0] current_col;         // Iterating through cols for DFS
    reg [2:0] dfs_row;             // Current row in DFS path
    reg [2:0] prev_match;          // Previous match for backtracking
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] match_count;
    reg dfs_result;                // Result of DFS attempt
    reg found_path;                // Flag for augmenting path found
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Initialize all arrays in reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize grid
            for (i = 0; i < 8; i = i + 1) begin
                grid[i] <= 8'd0;
            end
            // Initialize matching arrays
            for (i = 0; i < 8; i = i + 1) begin
                match_right[i] <= 3'd7;  // 7 indicates no match (since rows 0-7)
                seen[i] <= 1'b0;
            end
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            busy <= 1'b0;
            current_row <= 3'd0;
            current_col <= 3'd0;
            dfs_row <= 3'd0;
            match_count <= 4'd0;
            cycle_counter <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    match_count <= 4'd0;
                    cycle_counter <= 8'd0;
                    // Reset arrays when starting new operation
                    if (start) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            grid[i] <= 8'd0;
                            match_right[i] <= 3'd7;
                        end
                    end
                end

                INPUT: begin
                    // Store grid data
                    if (grid_valid) begin
                        grid[grid_row][grid_col] <= is_bomb;
                    end
                end

                SETUP: begin
                    // Initialize for matching
                    current_row <= 3'd0;
                    match_count <= 4'd0;
                    // match_right already reset in IDLE
                end

                SEARCH: begin
                    // Initialize DFS for this row
                    for (i = 0; i < 8; i = i + 1) begin
                        seen[i] <= 1'b0;
                    end
                    current_col <= 3'd0;
                end

                MATCHING: begin
                    // DFS logic is combinational, state handles flow
                    if (dfs_result && !seen[current_col]) begin
                        // Found augmenting path
                        match_right[current_col] <= current_row;
                        match_count <= match_count + 4'd1;
                    end
                end

                FINISH: begin
                    result <= match_count;
                    done <= 1'b1;
                    busy <= 1'b0;
                    cycle_counter <= 8'd0;
                end
            endcase
            
            // Update cycle counter
            if (busy && state != FINISH && state != IDLE) begin
                cycle_counter <= cycle_counter + 8'd1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INPUT;
            end
            
            INPUT: begin
                // Wait for valid signal to go low or timeout
                if (!grid_valid || cycle_counter > 8'd100) begin
                    next_state = SETUP;
                end
            end
            
            SETUP: begin
                if (current_row < 8'd8) begin
                    next_state = SEARCH;
                end else begin
                    next_state = FINISH;
                end
            end
            
            SEARCH: begin
                // Check if current_row has any non-bomb cells
                // If no edges, skip directly to next row
                if (grid[current_row] == 8'd0) begin
                    next_state = SETUP;
                    current_row = current_row + 3'd1;  // Increment here
                end else begin
                    next_state = MATCHING;
                end
            end
            
            MATCHING: begin
                // Check if we found augmenting path or exhausted cols
                if (dfs_result && !seen[current_col]) begin
                    // Success, move to next row
                    next_state = SETUP;
                    current_row = current_row + 3'd1;
                end else if (current_col < 3'd7) begin
                    // Try next column
                    next_state = MATCHING;
                    current_col = current_col + 3'd1;
                end else begin
                    // No augmenting path found for this row
                    next_state = SETUP;
                    current_row = current_row + 3'd1;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // DFS helper logic (combinational for path finding)
    // This checks if there's an augmenting path from current_row through current_col
    always @(*) begin
        dfs_result = 1'b0;
        
        if (state == MATCHING) begin
            // Check if current_col is connected to current_row
            if (grid[current_row][current_col] == 1'b0 && !seen[current_col]) begin
                // Valid edge (no bomb)
                if (match_right[current_col] == 3'd7) begin
                    // Unmatched column - augmenting path found
                    dfs_result = 1'b1;
                end else begin
                    // Try to reassign matched row
                    // Recursively check if we can find augmenting path from matched row
                    dfs_result = dfs_recursive(match_right[current_col], current_col);
                end
            end
        end
    end

    // Recursive DFS function for augmenting path
    function automatic dfs_recursive;
        input [2:0] row;
        input [2:0] col;
        integer j;
        begin
            seen[col] = 1'b1;
            dfs_recursive = 1'b0;
            
            // Check all columns for this row
            for (j = 0; j < 8; j = j + 1) begin
                if (!seen[j] && grid[row][j] == 1'b0 && match_right[j] != 3'd7) begin
                    // Recursively try to find augmenting path
                    if (dfs_recursive(match_right[j], j)) begin
                        match_right[j] = row;  // Update match in recursion
                        dfs_recursive = 1'b1;
                        seen[col] = 1'b0;
                        return 1;
                    end
                end
            end
            
            seen[col] = 1'b0;
        end
    endfunction

endmodule