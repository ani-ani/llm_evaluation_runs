module AlienSurgeryPuzzle(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [7:0] arr_8,
    input [7:0] arr_9,
    input [7:0] arr_10,
    input [7:0] arr_11,
    input [7:0] arr_12,
    input [7:0] arr_13,
    output reg result,
    output reg done,
    output reg [511:0] moves_out
);

    // Constants for k=3 (grid 2x7, 13 organs + 1 empty)
    localparam [3:0] K_MAX = 4'd3;
    localparam [3:0] NUM_ROWS = 4'd2;
    localparam [3:0] NUM_COLS = 4'd7;
    localparam [6:0] TOTAL_CELLS = 7'd14;
    localparam [7:0] MAX_DEPTH = 8'd256;
    localparam [7:0] MAX_MOVES = 8'd256;
    localparam [6:0] TARGET_SIZE = 7'd13;
    
    // Target configuration for k=3
    // Row 0: 1,2,3,4,5,6,7
    // Row 1: 13,12,11,10,9,8,0 (right to left)
    localparam [7:0] TARGET_0 = 8'd1;
    localparam [7:0] TARGET_1 = 8'd2;
    localparam [7:0] TARGET_2 = 8'd3;
    localparam [7:0] TARGET_3 = 8'd4;
    localparam [7:0] TARGET_4 = 8'd5;
    localparam [7:0] TARGET_5 = 8'd6;
    localparam [7:0] TARGET_6 = 8'd7;
    localparam [7:0] TARGET_7 = 8'd13;
    localparam [7:0] TARGET_8 = 8'd12;
    localparam [7:0] TARGET_9 = 8'd11;
    localparam [7:0] TARGET_10 = 8'd10;
    localparam [7:0] TARGET_11 = 8'd9;
    localparam [7:0] TARGET_12 = 8'd8;
    localparam [7:0] TARGET_13 = 8'd0;

    // State machine states
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_INPUT = 4'd1;
    localparam [3:0] CHECK_TARGET = 4'd2;
    localparam [3:0] FIND_EMPTY = 4'd3;
    localparam [3:0] DFS_START = 4'd4;
    localparam [3:0] DFS_SEARCH = 4'd5;
    localparam [3:0] CHECK_SOLUTION = 4'd6;
    localparam [3:0] FOUND_SOLUTION = 4'd7;
    localparam [3:0] NO_SOLUTION = 4'd8;
    localparam [3:0] OUTPUT_RESULT = 4'd9;

    // Move encoding
    localparam [1:0] MOVE_UP = 2'd0;
    localparam [1:0] MOVE_DOWN = 2'd1;
    localparam [1:0] MOVE_LEFT = 2'd2;
    localparam [1:0] MOVE_RIGHT = 2'd3;

    // Internal registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [7:0] cycle_count;
    
    // Grid storage (14 cells, 8-bit each)
    reg [7:0] grid [0:13];
    
    // Empty cell position
    reg [2:0] empty_row;
    reg [2:0] empty_col;
    
    // DFS stack - store grid states and move sequences
    reg [7:0] stack_grid [0:255][0:13];  // 256 depth, 14 cells
    reg [7:0] stack_depth [0:255];        // Current depth
    reg [1:0] stack_move [0:255];         // Move taken to reach this state
    reg [7:0] stack_ptr;
    reg [7:0] current_depth;
    
    // Current DFS state
    reg [7:0] current_grid [0:13];
    reg [2:0] current_empty_row;
    reg [2:0] current_empty_col;
    reg [7:0] depth_counter;
    
    // Move history
    reg [1:0] move_history [0:255];
    reg [7:0] move_count;
    
    // Validity flags
    reg valid_up;
    reg valid_down;
    reg valid_left;
    reg valid_right;
    
    // Heuristic calculation
    reg [15:0] manhattan_dist;
    reg [15:0] min_dist;
    reg [7:0] target_pos;
    
    // Solution found flag
    reg solution_found;
    
    // Temporary registers for comparison
    reg [7:0] i_temp;
    reg [7:0] j_temp;
    reg [7:0] temp_val;
    reg match_flag;
    
    // Backtracking control
    reg backtrack_flag;
    reg [7:0] backtrack_depth;

    // Counter for DFS loops
    reg [7:0] loop_idx;
    reg [7:0] loop_idx2;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            moves_out <= 512'd0;
            cycle_count <= 8'd0;
            empty_row <= 3'd0;
            empty_col <= 3'd0;
            stack_ptr <= 8'd0;
            current_depth <= 8'd0;
            depth_counter <= 8'd0;
            move_count <= 8'd0;
            solution_found <= 1'b0;
            backtrack_flag <= 1'b0;
            backtrack_depth <= 8'd0;
            loop_idx <= 8'd0;
            loop_idx2 <= 8'd0;
            
            // Initialize arrays
            for (i_temp = 0; i_temp < 14; i_temp = i_temp + 1) begin
                grid[i_temp] <= 8'd0;
                current_grid[i_temp] <= 8'd0;
                move_history[i_temp] <= 2'd0;
            end
            for (i_temp = 0; i_temp < 256; i_temp = i_temp + 1) begin
                stack_depth[i_temp] <= 8'd0;
                stack_move[i_temp] <= 2'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 8'd0;
                    solution_found <= 1'b0;
                    backtrack_flag <= 1'b0;
                    if (start) begin
                        state <= LOAD_INPUT;
                    end
                end
                
                LOAD_INPUT: begin
                    // Load input into grid
                    grid[0] <= arr_0;
                    grid[1] <= arr_1;
                    grid[2] <= arr_2;
                    grid[3] <= arr_3;
                    grid[4] <= arr_4;
                    grid[5] <= arr_5;
                    grid[6] <= arr_6;
                    grid[7] <= arr_7;
                    grid[8] <= arr_8;
                    grid[9] <= arr_9;
                    grid[10] <= arr_10;
                    grid[11] <= arr_11;
                    grid[12] <= arr_12;
                    grid[13] <= arr_13;
                    
                    // Copy to current grid
                    current_grid[0] <= arr_0;
                    current_grid[1] <= arr_1;
                    current_grid[2] <= arr_2;
                    current_grid[3] <= arr_3;
                    current_grid[4] <= arr_4;
                    current_grid[5] <= arr_5;
                    current_grid[6] <= arr_6;
                    current_grid[7] <= arr_7;
                    current_grid[8] <= arr_8;
                    current_grid[9] <= arr_9;
                    current_grid[10] <= arr_10;
                    current_grid[11] <= arr_11;
                    current_grid[12] <= arr_12;
                    current_grid[13] <= arr_13;
                    
                    state <= CHECK_TARGET;
                end
                
                CHECK_TARGET: begin
                    // Check if already in target configuration
                    match_flag <= 1'b1;
                    if (grid[0] != TARGET_0 || grid[1] != TARGET_1 || grid[2] != TARGET_2 ||
                        grid[3] != TARGET_3 || grid[4] != TARGET_4 || grid[5] != TARGET_5 ||
                        grid[6] != TARGET_6 || grid[7] != TARGET_7 || grid[8] != TARGET_8 ||
                        grid[9] != TARGET_9 || grid[10] != TARGET_10 || grid[11] != TARGET_11 ||
                        grid[12] != TARGET_12 || grid[13] != TARGET_13) begin
                        match_flag <= 1'b0;
                    end
                    
                    if (match_flag) begin
                        solution_found <= 1'b1;
                        move_count <= 8'd0;
                        state <= FOUND_SOLUTION;
                    end else begin
                        state <= FIND_EMPTY;
                    end
                end
                
                FIND_EMPTY: begin
                    // Find empty cell position (value 0)
                    if (grid[0] == 8'd0) begin empty_row <= 3'd0; empty_col <= 3'd0; end
                    else if (grid[1] == 8'd0) begin empty_row <= 3'd0; empty_col <= 3'd1; end
                    else if (grid[2] == 8'd0) begin empty_row <= 3'd0; empty_col <= 3'd2; end
                    else if (grid[3] == 8'd0) begin empty_row <= 3'd0; empty_col <= 3'd3; end
                    else if (grid[4] == 8'd0) begin empty_row <= 3'd0; empty_col <= 3'd4; end
                    else if (grid[5] == 8'd0) begin empty_row <= 3'd0; empty_col <= 3'd5; end
                    else if (grid[6] == 8'd0) begin empty_row <= 3'd0; empty_col <= 3'd6; end
                    else if (grid[7] == 8'd0) begin empty_row <= 3'd1; empty_col <= 3'd0; end
                    else if (grid[8] == 8'd0) begin empty_row <= 3'd1; empty_col <= 3'd1; end
                    else if (grid[9] == 8'd0) begin empty_row <= 3'd1; empty_col <= 3'd2; end
                    else if (grid[10] == 8'd0) begin empty_row <= 3'd1; empty_col <= 3'd3; end
                    else if (grid[11] == 8'd0) begin empty_row <= 3'd1; empty_col <= 3'd4; end
                    else if (grid[12] == 8'd0) begin empty_row <= 3'd1; empty_col <= 3'd5; end
                    else if (grid[13] == 8'd0) begin empty_row <= 3'd1; empty_col <= 3'd6; end
                    
                    // Copy initial state to stack
                    for (loop_idx = 0; loop_idx < 14; loop_idx = loop_idx + 1) begin
                        stack_grid[0][loop_idx] <= grid[loop_idx];
                    end
                    stack_depth[0] <= 8'd0;
                    stack_ptr <= 8'd1;
                    current_depth <= 8'd0;
                    move_count <= 8'd0;
                    depth_counter <= 8'd0;
                    
                    // Clear move history
                    for (loop_idx = 0; loop_idx < 256; loop_idx = loop_idx + 1) begin
                        move_history[loop_idx] <= 2'd0;
                    end
                    
                    state <= DFS_START;
                end
                
                DFS_START: begin
                    // Initialize DFS from current state
                    for (loop_idx = 0; loop_idx < 14; loop_idx = loop_idx + 1) begin
                        current_grid[loop_idx] <= grid[loop_idx];
                    end
                    current_empty_row <= empty_row;
                    current_empty_col <= empty_col;
                    depth_counter <= 8'd0;
                    
                    state <= DFS_SEARCH;
                end
                
                DFS_SEARCH: begin
                    // Check if we reached max depth
                    if (depth_counter >= MAX_DEPTH) begin
                        state <= NO_SOLUTION;
                    end else if (stack_ptr == 8'd0) begin
                        // Stack empty, no solution
                        state <= NO_SOLUTION;
                    end else begin
                        // Pop from stack
                        stack_ptr <= stack_ptr - 8'd1;
                        
                        // Load current state from stack
                        for (loop_idx = 0; loop_idx < 14; loop_idx = loop_idx + 1) begin
                            current_grid[loop_idx] <= stack_grid[stack_ptr - 8'd1][loop_idx];
                        end
                        current_depth <= stack_depth[stack_ptr - 8'd1];
                        
                        // Calculate empty position from grid
                        // Find empty cell
                        if (stack_grid[stack_ptr - 8'd1][0] == 8'd0) begin
                            current_empty_row <= 3'd0;
                            current_empty_col <= 3'd0;
                        end else if (stack_grid[stack_ptr - 8'd1][1] == 8'd0) begin
                            current_empty_row <= 3'd0;
                            current_empty_col <= 3'd1;
                        end else if (stack_grid[stack_ptr - 8'd1][2] == 8'd0) begin
                            current_empty_row <= 3'd0;
                            current_empty_col <= 3'd2;
                        end else if (stack_grid[stack_ptr - 8'd1][3] == 8'd0) begin
                            current_empty_row <= 3'd0;
                            current_empty_col <= 3'd3;
                        end else if (stack_grid[stack_ptr - 8'd1][4] == 8'd0) begin
                            current_empty_row <= 3'd0;
                            current_empty_col <= 3'd4;
                        end else if (stack_grid[stack_ptr - 8'd1][5] == 8'd0) begin
                            current_empty_row <= 3'd0;
                            current_empty_col <= 3'd5;
                        end else if (stack_grid[stack_ptr - 8'd1][6] == 8'd0) begin
                            current_empty_row <= 3'd0;
                            current_empty_col <= 3'd6;
                        end else if (stack_grid[stack_ptr - 8'd1][7] == 8'd0) begin
                            current_empty_row <= 3'd1;
                            current_empty_col <= 3'd0;
                        end else if (stack_grid[stack_ptr - 8'd1][8] == 8'd0) begin
                            current_empty_row <= 3'd1;
                            current_empty_col <= 3'd1;
                        end else if (stack_grid[stack_ptr - 8'd1][9] == 8'd0) begin
                            current_empty_row <= 3'd1;
                            current_empty_col <= 3'd2;
                        end else if (stack_grid[stack_ptr - 8'd1][10] == 8'd0) begin
                            current_empty_row <= 3'd1;
                            current_empty_col <= 3'd3;
                        end else if (stack_grid[stack_ptr - 8'd1][11] == 8'd0) begin
                            current_empty_row <= 3'd1;
                            current_empty_col <= 3'd4;
                        end else if (stack_grid[stack_ptr - 8'd1][12] == 8'd0) begin
                            current_empty_row <= 3'd1;
                            current_empty_col <= 3'd5;
                        end else begin
                            current_empty_row <= 3'd1;
                            current_empty_col <= 3'd6;
                        end
                        
                        state <= CHECK_SOLUTION;
                    end
                end
                
                CHECK_SOLUTION: begin
                    // Check if current state matches target
                    match_flag <= 1'b1;
                    if (current_grid[0] != TARGET_0 || current_grid[1] != TARGET_1 || current_grid[2] != TARGET_2 ||
                        current_grid[3] != TARGET_3 || current_grid[4] != TARGET_4 || current_grid[5] != TARGET_5 ||
                        current_grid[6] != TARGET_6 || current_grid[7] != TARGET_7 || current_grid[8] != TARGET_8 ||
                        current_grid[9] != TARGET_9 || current_grid[10] != TARGET_10 || current_grid[11] != TARGET_11 ||
                        current_grid[12] != TARGET_12 || current_grid[13] != TARGET_13) begin
                        match_flag <= 1'b0;
                    end
                    
                    if (match_flag) begin
                        solution_found <= 1'b1;
                        move_count <= current_depth;
                        // Need to reconstruct moves - for now, just mark as found
                        state <= FOUND_SOLUTION;
                    end else begin
                        // Calculate valid moves based on empty position
                        valid_up <= 1'b0;
                        valid_down <= 1'b0;
                        valid_left <= 1'b0;
                        valid_right <= 1'b0;
                        
                        // Right always allowed
                        if (current_empty_col < 6) valid_right <= 1'b1;
                        
                        // Left always allowed
                        if (current_empty_col > 0) valid_left <= 1'b1;
                        
                        // Up allowed if in special columns
                        if (current_empty_row > 0 && (current_empty_col == 0 || current_empty_col == 6 || current_empty_col == 3)) begin
                            valid_up <= 1'b1;
                        end
                        
                        // Down allowed if in special columns
                        if (current_empty_row < 1 && (current_empty_col == 0 || current_empty_col == 6 || current_empty_col == 3)) begin
                            valid_down <= 1'b1;
                        end
                        
                        // Push valid moves to stack
                        if (current_depth < MAX_DEPTH) begin
                            if (valid_up && stack_ptr < 255) begin
                                // Apply up move
                                for (loop_idx = 0; loop_idx < 14; loop_idx = loop_idx + 1) begin
                                    stack_grid[stack_ptr][loop_idx] <= current_grid[loop_idx];
                                end
                                // Swap empty with element above
                                if (current_empty_row == 1) begin
                                    // Index calculation: if empty is at (1, col), above is (0, col)
                                    if (current_empty_col == 0) begin stack_grid[stack_ptr][7] <= current_grid[0]; stack_grid[stack_ptr][0] <= 8'd0; end
                                    else if (current_empty_col == 1) begin stack_grid[stack_ptr][8] <= current_grid[1]; stack_grid[stack_ptr][1] <= 8'd0; end
                                    else if (current_empty_col == 2) begin stack_grid[stack_ptr][9] <= current_grid[2]; stack_grid[stack_ptr][2] <= 8'd0; end
                                    else if (current_empty_col == 3) begin stack_grid[stack_ptr][10] <= current_grid[3]; stack_grid[stack_ptr][3] <= 8'd0; end
                                    else if (current_empty_col == 4) begin stack_grid[stack_ptr][11] <= current_grid[4]; stack_grid[stack_ptr][4] <= 8'd0; end
                                    else if (current_empty_col == 5) begin stack_grid[stack_ptr][12] <= current_grid[5]; stack_grid[stack_ptr][5] <= 8'd0; end
                                    else begin stack_grid[stack_ptr][13] <= current_grid[6]; stack_grid[stack_ptr][6] <= 8'd0; end
                                end
                                stack_depth[stack_ptr] <= current_depth + 8'd1;
                                stack_ptr <= stack_ptr + 8'd1;
                            end
                            
                            if (valid_down && stack_ptr < 255) begin
                                // Apply down move
                                for (loop_idx = 0; loop_idx < 14; loop_idx = loop_idx + 1) begin
                                    stack_grid[stack_ptr][loop_idx] <= current_grid[loop_idx];
                                end
                                // Swap empty with element below
                                if (current_empty_row == 0) begin
                                    if (current_empty_col == 0) begin stack_grid[stack_ptr][0] <= current_grid[7]; stack_grid[stack_ptr][7] <= 8'd0; end
                                    else if (current_empty_col == 1) begin stack_grid[stack_ptr][1] <= current_grid[8]; stack_grid[stack_ptr][8] <= 8'd0; end
                                    else if (current_empty_col == 2) begin stack_grid[stack_ptr][2] <= current_grid[9]; stack_grid[stack_ptr][9] <= 8'd0; end
                                    else if (current_empty_col == 3) begin stack_grid[stack_ptr][3] <= current_grid[10]; stack_grid[stack_ptr][10] <= 8'd0; end
                                    else if (current_empty_col == 4) begin stack_grid[stack_ptr][4] <= current_grid[11]; stack_grid[stack_ptr][11] <= 8'd0; end
                                    else if (current_empty_col == 5) begin stack_grid[stack_ptr][5] <= current_grid[12]; stack_grid[stack_ptr][12] <= 8'd0; end
                                    else begin stack_grid[stack_ptr][6] <= current_grid[13]; stack_grid[stack_ptr][13] <= 8'd0; end
                                end
                                stack_depth[stack_ptr] <= current_depth + 8'd1;
                                stack_ptr <= stack_ptr + 8'd1;
                            end
                            
                            if (valid_left && stack_ptr < 255) begin
                                // Apply left move
                                for (loop_idx = 0; loop_idx < 14; loop_idx = loop_idx + 1) begin
                                    stack_grid[stack_ptr][loop_idx] <= current_grid[loop_idx];
                                end
                                // Swap empty with element to left
                                if (current_empty_col > 0) begin
                                    if (current_empty_row == 0) begin
                                        // Row 0 indices: 0-6
                                        if (current_empty_col == 1) begin stack_grid[stack_ptr][1] <= current_grid[0]; stack_grid[stack_ptr][0] <= 8'd0; end
                                        else if (current_empty_col == 2) begin stack_grid[stack_ptr][2] <= current_grid[1]; stack_grid[stack_ptr][1] <= 8'd0; end
                                        else if (current_empty_col == 3) begin stack_grid[stack_ptr][3] <= current_grid[2]; stack_grid[stack_ptr][2] <= 8'd0; end
                                        else if (current_empty_col == 4) begin stack_grid[stack_ptr][4] <= current_grid[3]; stack_grid[stack_ptr][3] <= 8'd0; end
                                        else if (current_empty_col == 5) begin stack_grid[stack_ptr][5] <= current_grid[4]; stack_grid[stack_ptr][4] <= 8'd0; end
                                        else if (current_empty_col == 6) begin stack_grid[stack_ptr][6] <= current_grid[5]; stack_grid[stack_ptr][5] <= 8'd0; end
                                    end else begin
                                        // Row 1 indices: 7-13
                                        if (current_empty_col == 1) begin stack_grid[stack_ptr][8] <= current_grid[7]; stack_grid[stack_ptr][7] <= 8'd0; end
                                        else if (current_empty_col == 2) begin stack_grid[stack_ptr][9] <= current_grid[8]; stack_grid[stack_ptr][8] <= 8'd0; end
                                        else if (current_empty_col == 3) begin stack_grid[stack_ptr][10] <= current_grid[9]; stack_grid[stack_ptr][9] <= 8'd0; end
                                        else if (current_empty_col == 4) begin stack_grid[stack_ptr][11] <= current_grid[10]; stack_grid[stack_ptr][10] <= 8'd0; end
                                        else if (current_empty_col == 5) begin stack_grid[stack_ptr][12] <= current_grid[11]; stack_grid[stack_ptr][11] <= 8'd0; end
                                        else if (current_empty_col == 6) begin stack_grid[stack_ptr][13] <= current_grid[12]; stack_grid[stack_ptr][12] <= 8'd0; end
                                    end
                                end
                                stack_depth[stack_ptr] <= current_depth + 8'd1;
                                stack_ptr <= stack_ptr + 8'd1;
                            end
                            
                            if (valid_right && stack_ptr < 255) begin
                                // Apply right move
                                for (loop_idx = 0; loop_idx < 14; loop_idx = loop_idx + 1) begin
                                    stack_grid[stack_ptr][loop_idx] <= current_grid[loop_idx];
                                end
                                // Swap empty with element to right
                                if (current_empty_col < 6) begin
                                    if (current_empty_row == 0) begin
                                        // Row 0 indices: 0-6
                                        if (current_empty_col == 0) begin stack_grid[stack_ptr][0] <= current_grid[1]; stack_grid[stack_ptr][1] <= 8'd0; end
                                        else if (current_empty_col == 1) begin stack_grid[stack_ptr][1] <= current_grid[2]; stack_grid[stack_ptr][2] <= 8'd0; end
                                        else if (current_empty_col == 2) begin stack_grid[stack_ptr][2] <= current_grid[3]; stack_grid[stack_ptr][3] <= 8'd0; end
                                        else if (current_empty_col == 3) begin stack_grid[stack_ptr][3] <= current_grid[4]; stack_grid[stack_ptr][4] <= 8'd0; end
                                        else if (current_empty_col == 4) begin stack_grid[stack_ptr][4] <= current_grid[5]; stack_grid[stack_ptr][5] <= 8'd0; end
                                        else if (current_empty_col == 5) begin stack_grid[stack_ptr][5] <= current_grid[6]; stack_grid[stack_ptr][6] <= 8'd0; end
                                    end else begin
                                        // Row 1 indices: 7-13
                                        if (current_empty_col == 0) begin stack_grid[stack_ptr][7] <= current_grid[8]; stack_grid[stack_ptr][8] <= 8'd0; end
                                        else if (current_empty_col == 1) begin stack_grid[stack_ptr][8] <= current_grid[9]; stack_grid[stack_ptr][9] <= 8'd0; end
                                        else if (current_empty_col == 2) begin stack_grid[stack_ptr][9] <= current_grid[10]; stack_grid[stack_ptr][10] <= 8'd0; end
                                        else if (current_empty_col == 3) begin stack_grid[stack_ptr][10] <= current_grid[11]; stack_grid[stack_ptr][11] <= 8'd0; end
                                        else if (current_empty_col == 4) begin stack_grid[stack_ptr][11] <= current_grid[12]; stack_grid[stack_ptr][12] <= 8'd0; end
                                        else if (current_empty_col == 5) begin stack_grid[stack_ptr][12] <= current_grid[13]; stack_grid[stack_ptr][13] <= 8'd0; end
                                    end
                                end
                                stack_depth[stack_ptr] <= current_depth + 8'd1;
                                stack_ptr <= stack_ptr + 8'd1;
                            end
                        end
                        
                        depth_counter <= depth_counter + 8'd1;
                        state <= DFS_SEARCH;
                    end
                end
                
                FOUND_SOLUTION: begin
                    result <= 1'b1;
                    // Generate simple move sequence for demonstration
                    // In reality, this would reconstruct the full path
                    moves_out <= 512'd0;  // Clear for now
                    state <= OUTPUT_RESULT;
                end
                
                NO_SOLUTION: begin
                    result <= 1'b0;
                    moves_out <= 512'd0;
                    state <= OUTPUT_RESULT;
                end
                
                OUTPUT_RESULT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule