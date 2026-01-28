module superdoku_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] input_row,
    input wire [2:0] input_col,
    input wire [3:0] input_val,
    input wire valid_input,
    output reg [255:0] result_grid,
    output reg done,
    output reg solvable
);

    // State definitions
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] LOAD_INPUT     = 3'd1;
    localparam [2:0] FIND_SOLUTION  = 3'd2;
    localparam [2:0] FOUND          = 3'd3;
    localparam [2:0] IMPOSSIBLE     = 3'd4;

    // Fixed parameters
    localparam [7:0] MAX_CYCLES     = 8'd10000;
    localparam [3:0] GRID_SIZE      = 4'd8;
    localparam [3:0] MAX_VAL        = 4'd8;

    // Internal registers
    reg [2:0] state;
    reg [7:0] cycle_count;
    
    // Grid storage: 8 rows, 8 cols, 4 bits each (1-8)
    reg [3:0] grid_reg [0:7][0:7];
    
    // Column constraints: 8 columns, 8-bit masks (bit 0 unused, bits 1-8 used)
    reg [7:0] col_masks [0:7];
    
    // Row constraints: 8-bit mask for current row being filled
    reg [7:0] row_mask;
    
    // Solver state
    reg [2:0] curr_row;
    reg [2:0] curr_col;
    reg [3:0] try_val;
    reg [2:0] k_rows;  // Number of initial rows
    reg input_phase_done;
    
    // Backtracking stack (simplified: stores decision points)
    reg [2:0] stack_row [0:63];
    reg [2:0] stack_col [0:63];
    reg [3:0] stack_val [0:63];
    reg [6:0] stack_ptr;
    reg [2:0] backtracking_row;
    reg [2:0] backtracking_col;
    reg [3:0] last_attempted_val;
    reg backtracking_mode;

    // Helper wires for constraint checking
    wire col_valid;
    wire row_valid;
    wire val_bit;

    assign val_bit = (try_val >= 4'd1 && try_val <= 4'd8) ? (1 << (try_val - 4'd1)) : 8'd0;
    assign col_valid = (try_val >= 4'd1 && try_val <= 4'd8) ? ((col_masks[curr_col] & val_bit) == 8'd0) : 1'b0;
    assign row_valid = (try_val >= 4'd1 && try_val <= 4'd8) ? ((row_mask & val_bit) == 8'd0) : 1'b0;

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            solvable <= 1'b0;
            result_grid <= 256'd0;
            
            // Reset grid
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    grid_reg[i][j] <= 4'd0;
                end
            end
            
            // Reset constraints
            for (i = 0; i < 8; i = i + 1) begin
                col_masks[i] <= 8'd0;
            end
            
            row_mask <= 8'd0;
            curr_row <= 3'd0;
            curr_col <= 3'd0;
            try_val <= 4'd0;
            k_rows <= 3'd0;
            input_phase_done <= 1'b0;
            stack_ptr <= 7'd0;
            backtracking_mode <= 1'b0;
            backtracking_row <= 3'd0;
            backtracking_col <= 3'd0;
            last_attempted_val <= 4'd0;
            
            // Reset stack
            for (i = 0; i < 64; i = i + 1) begin
                stack_row[i] <= 3'd0;
                stack_col[i] <= 3'd0;
                stack_val[i] <= 4'd0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    solvable <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    // Initialize empty grid
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            grid_reg[i][j] <= 4'd0;
                        end
                    end
                    
                    for (i = 0; i < 8; i = i + 1) begin
                        col_masks[i] <= 8'd0;
                    end
                    
                    row_mask <= 8'd0;
                    curr_row <= 3'd0;
                    curr_col <= 3'd0;
                    try_val <= 4'd0;
                    k_rows <= 3'd0;
                    input_phase_done <= 1'b0;
                    stack_ptr <= 7'd0;
                    backtracking_mode <= 1'b0;
                    backtracking_row <= 3'd0;
                    backtracking_col <= 3'd0;
                    last_attempted_val <= 4'd0;
                    
                    for (i = 0; i < 64; i = i + 1) begin
                        stack_row[i] <= 3'd0;
                        stack_col[i] <= 3'd0;
                        stack_val[i] <= 4'd0;
                    end
                    
                    if (start) begin
                        state <= LOAD_INPUT;
                    end
                end
                
                LOAD_INPUT: begin
                    if (valid_input) begin
                        // Store input value
                        grid_reg[input_row][input_col] <= input_val;
                        
                        // Update column mask
                        if (input_val >= 4'd1 && input_val <= 4'd8) begin
                            col_masks[input_col] <= col_masks[input_col] | (1 << (input_val - 4'd1));
                        end
                        
                        // Track max row index
                        if (input_row > k_rows) begin
                            k_rows <= input_row;
                        end
                    end
                    
                    // Transition to solving when input phase ends
                    // Assume input is stream, so we transition after processing
                    if (!valid_input && !input_phase_done) begin
                        input_phase_done <= 1'b1;
                        state <= FIND_SOLUTION;
                        curr_row <= k_rows + 3'd1;  // Start from row after initial rows
                        curr_col <= 3'd0;
                        try_val <= 4'd1;
                        backtracking_mode <= 1'b0;
                    end
                end
                
                FIND_SOLUTION: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IMPOSSIBLE;
                    end else if (curr_row >= 8) begin
                        // All rows filled, solution found
                        state <= FOUND;
                    end else begin
                        if (backtracking_mode) begin
                            // We are backtracking - check next value for current cell
                            if (last_attempted_val < MAX_VAL) begin
                                try_val <= last_attempted_val + 4'd1;
                                backtracking_mode <= 1'b0;  // Try next value
                            end else begin
                                // All values tried, need to backtrack further
                                if (stack_ptr > 7'd0) begin
                                    stack_ptr <= stack_ptr - 7'd1;
                                    backtracking_row <= stack_row[stack_ptr - 7'd1];
                                    backtracking_col <= stack_col[stack_ptr - 7'd1];
                                    last_attempted_val <= stack_val[stack_ptr - 7'd1];
                                    // Rebuild constraints up to this point
                                    // This is simplified - in real backtracking we'd restore state
                                    // For this impl, we'll recalculate from scratch
                                    backtracking_mode <= 1'b1;
                                end else begin
                                    state <= IMPOSSIBLE;
                                end
                            end
                        end else begin
                            // Forward mode - try to place try_val at (curr_row, curr_col)
                            // Check validity
                            if (try_val >= 4'd1 && try_val <= 4'd8) begin
                                // Check column constraint
                                if (col_masks[curr_col][try_val - 4'd1] == 1'b0) begin
                                    // Check row constraint (need to compute current row mask)
                                    // Build row mask for current row
                                    row_mask <= 8'd0;
                                    for (i = 0; i < 8; i = i + 1) begin
                                        if (grid_reg[curr_row][i] >= 4'd1 && grid_reg[curr_row][i] <= 4'd8) begin
                                            row_mask <= row_mask | (1 << (grid_reg[curr_row][i] - 4'd1));
                                        end
                                    end
                                    
                                    // Check if val is already in row (in columns before curr_col)
                                    // Also check if we're overwriting a pre-filled cell
                                    if (grid_reg[curr_row][curr_col] == 4'd0) begin
                                        // Empty cell, check if val conflicts with earlier in row
                                        if ((row_mask & (1 << (try_val - 4'd1))) == 8'd0) begin
                                            // Valid placement
                                            grid_reg[curr_row][curr_col] <= try_val;
                                            col_masks[curr_col] <= col_masks[curr_col] | (1 << (try_val - 4'd1));
                                            
                                            // Push to stack
                                            stack_row[stack_ptr] <= curr_row;
                                            stack_col[stack_ptr] <= curr_col;
                                            stack_val[stack_ptr] <= try_val;
                                            stack_ptr <= stack_ptr + 7'd1;
                                            
                                            // Move to next cell
                                            if (curr_col < 3'd7) begin
                                                curr_col <= curr_col + 3'd1;
                                                try_val <= 4'd1;
                                            end else begin
                                                curr_col <= 3'd0;
                                                curr_row <= curr_row + 3'd1;
                                                try_val <= 4'd1;
                                            end
                                        end else begin
                                            // Conflict in row, try next value
                                            try_val <= try_val + 4'd1;
                                        end
                                    end else begin
                                        // Cell already filled (from initial input), skip it
                                        if (curr_col < 3'd7) begin
                                            curr_col <= curr_col + 3'd1;
                                            try_val <= 4'd1;
                                        end else begin
                                            curr_col <= 3'd0;
                                            curr_row <= curr_row + 3'd1;
                                            try_val <= 4'd1;
                                        end
                                    end
                                end else begin
                                    // Column constraint violated, try next value
                                    try_val <= try_val + 4'd1;
                                end
                            end else begin
                                // No valid values left, backtrack
                                if (stack_ptr > 7'd0) begin
                                    // Pop last decision
                                    stack_ptr <= stack_ptr - 7'd1;
                                    backtracking_row <= stack_row[stack_ptr - 7'd1];
                                    backtracking_col <= stack_col[stack_ptr - 7'd1];
                                    last_attempted_val <= stack_val[stack_ptr - 7'd1];
                                    
                                    // Clear current cell
                                    if (grid_reg[curr_row][curr_col] >= 4'd1 && grid_reg[curr_row][curr_col] <= 4'd8) begin
                                        col_masks[curr_col] <= col_masks[curr_col] & ~(1 << (grid_reg[curr_row][curr_col] - 4'd1));
                                        grid_reg[curr_row][curr_col] <= 4'd0;
                                    end
                                    
                                    backtracking_mode <= 1'b1;
                                end else begin
                                    state <= IMPOSSIBLE;
                                end
                            end
                        end
                    end
                end
                
                FOUND: begin
                    done <= 1'b1;
                    solvable <= 1'b1;
                    
                    // Pack grid into result_grid (row-major order)
                    // Each value is 4 bits, so 256 bits total
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            result_grid[(i*8 + j)*4 +: 4] <= grid_reg[i][j];
                        end
                    end
                    
                    state <= IDLE;
                end
                
                IMPOSSIBLE: begin
                    done <= 1'b1;
                    solvable <= 1'b0;
                    
                    // Clear result grid
                    result_grid <= 256'd0;
                    
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule