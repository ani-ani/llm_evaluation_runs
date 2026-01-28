module MatrixSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid [0:5][0:5],
    input wire [3:0] m,
    input wire [3:0] n,
    output reg [15:0] result,
    output reg done,
    output reg found
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] INITIALIZE    = 3'd1;
    localparam [2:0] VALIDATE_ROW  = 3'd2;
    localparam [2:0] VALIDATE_L_RULE = 3'd3;
    localparam [2:0] NEXT_CELL      = 3'd4;
    localparam [2:0] COMPLETE       = 3'd5;
    localparam [2:0] DONE_STATE     = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Grid state (copy of input with modifications)
    reg [7:0] curr_grid [0:5][0:5];
    
    // Row usage bitmask (9 bits for digits 1-9)
    reg [8:0] row_used [0:5];
    
    // Position tracking
    reg [2:0] curr_row;
    reg [2:0] curr_col;
    
    // For trying digits
    reg [3:0] try_digit;  // 1-9
    reg digit_valid;
    
    // For constraint checking
    reg [7:0] check_u;
    reg [7:0] check_l;
    reg [7:0] check_r;
    reg constraint_passed;
    
    // Computation intermediates
    reg [15:0] sum_val;
    reg [15:0] prod_val;
    reg [7:0] diff_val;
    reg [7:0] quot_lu;
    reg [7:0] quot_ru;
    reg quot_lu_valid;
    reg quot_ru_valid;
    
    // Stack for backtracking (stores positions and tried digits)
    reg [2:0] stack_row [0:17];
    reg [2:0] stack_col [0:17];
    reg [3:0] stack_tried [0:17];
    reg [4:0] stack_depth;
    
    // Result counter
    reg [15:0] completion_count;
    reg found_any;
    
    // Timeout counter
    reg [19:0] cycle_counter;
    localparam [19:0] MAX_CYCLES = 20'd1000000;
    
    // Flag for initial unknown search
    reg found_unknown;
    integer i, j;
    
    // Reset and state update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            found <= 1'b0;
            completion_count <= 16'd0;
            found_any <= 1'b0;
            cycle_counter <= 20'd0;
            curr_row <= 3'd0;
            curr_col <= 3'd0;
            try_digit <= 4'd1;
            stack_depth <= 5'd0;
            // Initialize grid to zero
            for (i = 0; i < 6; i = i + 1) begin
                for (j = 0; j < 6; j = j + 1) begin
                    curr_grid[i][j] <= 8'd0;
                end
            end
            // Initialize row masks
            for (i = 0; i < 6; i = i + 1) begin
                row_used[i] <= 9'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    completion_count <= 16'd0;
                    found_any <= 1'b0;
                    cycle_counter <= 20'd0;
                    stack_depth <= 5'd0;
                    curr_row <= 3'd0;
                    curr_col <= 3'd0;
                    if (start) begin
                        state <= INITIALIZE;
                    end
                end
                
                INITIALIZE: begin
                    // Copy input grid to internal register
                    // Initialize row usage masks
                    for (i = 0; i < 6; i = i + 1) begin
                        for (j = 0; j < 6; j = j + 1) begin
                            curr_grid[i][j] <= grid[i][j];
                        end
                    end
                    // Initialize row masks based on known values
                    for (i = 0; i < m; i = i + 1) begin
                        row_used[i] <= 9'd0;
                        for (j = 0; j < n; j = j + 1) begin
                            if (grid[i][j] > 8'd0) begin
                                row_used[i][grid[i][j] - 1] <= 1'b1;
                            end
                        end
                    end
                    // Find first unknown
                    found_unknown <= 1'b0;
                    curr_row <= 3'd0;
                    curr_col <= 3'd0;
                    state <= NEXT_CELL;
                end
                
                NEXT_CELL: begin
                    cycle_counter <= cycle_counter + 20'd1;
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                        result <= completion_count;
                        found <= found_any;
                        done <= 1'b1;
                    end else if (stack_depth == 5'd0 && curr_grid[curr_row][curr_col] > 8'd0) begin
                        // No unknowns left in current cell, need to find next
                        if (curr_col < n - 1) begin
                            curr_col <= curr_col + 3'd1;
                        end else if (curr_row < m - 1) begin
                            curr_row <= curr_row + 3'd1;
                            curr_col <= 3'd0;
                        end else begin
                            // All cells filled
                            state <= COMPLETE;
                        end
                    end else if (stack_depth == 5'd0 && curr_grid[curr_row][curr_col] == 8'd0) begin
                        // Found unknown, start trying digits
                        try_digit <= 4'd1;
                        state <= VALIDATE_ROW;
                    end else begin
                        // Backtrack case - pop from stack
                        if (stack_depth > 5'd0) begin
                            curr_row <= stack_row[stack_depth - 5'd1];
                            curr_col <= stack_col[stack_depth - 5'd1];
                            try_digit <= stack_tried[stack_depth - 5'd1] + 4'd1;
                            stack_depth <= stack_depth - 5'd1;
                            // Restore row mask for the cell we're backtracking from
                            if (curr_grid[curr_row][curr_col] > 8'd0) begin
                                row_used[curr_row][curr_grid[curr_row][curr_col] - 1] <= 1'b0;
                            end
                            curr_grid[curr_row][curr_col] <= 8'd0;
                            state <= VALIDATE_ROW;
                        end else begin
                            state <= DONE_STATE;
                            result <= completion_count;
                            found <= found_any;
                            done <= 1'b1;
                        end
                    end
                end
                
                VALIDATE_ROW: begin
                    // Check if try_digit is already used in row
                    if (try_digit > 4'd9) begin
                        // All digits tried, backtrack
                        if (stack_depth > 5'd0) begin
                            curr_row <= stack_row[stack_depth - 5'd1];
                            curr_col <= stack_col[stack_depth - 5'd1];
                            try_digit <= stack_tried[stack_depth - 5'd1] + 4'd1;
                            stack_depth <= stack_depth - 5'd1;
                            if (curr_grid[curr_row][curr_col] > 8'd0) begin
                                row_used[curr_row][curr_grid[curr_row][curr_col] - 1] <= 1'b0;
                            end
                            curr_grid[curr_row][curr_col] <= 8'd0;
                            state <= VALIDATE_ROW;
                        end else begin
                            state <= DONE_STATE;
                            result <= completion_count;
                            found <= found_any;
                            done <= 1'b1;
                        end
                    end else if (!row_used[curr_row][try_digit - 1]) begin
                        // Digit is available in row
                        curr_grid[curr_row][curr_col] <= {4'd0, try_digit};
                        row_used[curr_row][try_digit - 1] <= 1'b1;
                        state <= VALIDATE_L_RULE;
                    end else begin
                        // Try next digit
                        try_digit <= try_digit + 4'd1;
                        state <= VALIDATE_ROW;
                    end
                end
                
                VALIDATE_L_RULE: begin
                    // Check L-rule constraint if applicable
                    // Constraint applies if i > 0 and j < n-1
                    if (curr_row > 3'd0 && curr_col < n - 3'd1) begin
                        check_u <= curr_grid[curr_row - 3'd1][curr_col];
                        check_l <= curr_grid[curr_row][curr_col];
                        check_r <= curr_grid[curr_row][curr_col + 3'd1];
                        
                        // Compute operations in parallel
                        sum_val <= {8'd0, curr_grid[curr_row][curr_col]} + {8'd0, curr_grid[curr_row][curr_col + 3'd1]};
                        prod_val <= {8'd0, curr_grid[curr_row][curr_col]} * {8'd0, curr_grid[curr_row][curr_col + 3'd1]};
                        if (curr_grid[curr_row][curr_col] > curr_grid[curr_row][curr_col + 3'd1]) begin
                            diff_val <= curr_grid[curr_row][curr_col] - curr_grid[curr_row][curr_col + 3'd1];
                        end else begin
                            diff_val <= curr_grid[curr_row][curr_col + 3'd1] - curr_grid[curr_row][curr_col];
                        end
                        
                        // Check divisibility
                        if (curr_grid[curr_row][curr_col + 3'd1] > 8'd0 && 
                            curr_grid[curr_row][curr_col] % curr_grid[curr_row][curr_col + 3'd1] == 8'd0) begin
                            quot_lu <= curr_grid[curr_row][curr_col] / curr_grid[curr_row][curr_col + 3'd1];
                            quot_lu_valid <= 1'b1;
                        end else begin
                            quot_lu_valid <= 1'b0;
                        end
                        
                        if (curr_grid[curr_row][curr_col] > 8'd0 && 
                            curr_grid[curr_row][curr_col + 3'd1] % curr_grid[curr_row][curr_col] == 8'd0) begin
                            quot_ru <= curr_grid[curr_row][curr_col + 3'd1] / curr_grid[curr_row][curr_col];
                            quot_ru_valid <= 1'b1;
                        end else begin
                            quot_ru_valid <= 1'b0;
                        end
                        
                        constraint_passed <= 1'b0;
                        state <= (constraint_passed ? COMPLETE : NEXT_CELL);
                        // Need an extra state for final check
                        state <= 3'd7; // Temporary state
                    end else begin
                        // L-rule doesn't apply, check complete or move to next
                        if (curr_row == m - 3'd1 && curr_col == n - 3'd1) begin
                            state <= COMPLETE;
                        end else begin
                            state <= NEXT_CELL;
                        end
                    end
                end
                
                3'd7: begin
                    // Check constraint results
                    if (check_u == sum_val[7:0] || check_u == prod_val[7:0] || 
                        check_u == diff_val || 
                        (quot_lu_valid && check_u == quot_lu) ||
                        (quot_ru_valid && check_u == quot_ru)) begin
                        constraint_passed <= 1'b1;
                    end else begin
                        constraint_passed <= 1'b0;
                    end
                    
                    if (constraint_passed) begin
                        if (curr_row == m - 3'd1 && curr_col == n - 3'd1) begin
                            state <= COMPLETE;
                        end else begin
                            state <= NEXT_CELL;
                        end
                    end else begin
                        // Constraint failed, try next digit
                        // Undo the assignment
                        curr_grid[curr_row][curr_col] <= 8'd0;
                        row_used[curr_row][try_digit - 1] <= 1'b0;
                        try_digit <= try_digit + 4'd1;
                        state <= VALIDATE_ROW;
                    end
                end
                
                COMPLETE: begin
                    // Found a valid completion
                    completion_count <= completion_count + 16'd1;
                    found_any <= 1'b1;
                    // Need to backtrack to find more solutions
                    if (stack_depth > 5'd0) begin
                        // Pop from stack and try next digit
                        curr_row <= stack_row[stack_depth - 5'd1];
                        curr_col <= stack_col[stack_depth - 5'd1];
                        try_digit <= stack_tried[stack_depth - 5'd1] + 4'd1;
                        stack_depth <= stack_depth - 5'd1;
                        if (curr_grid[curr_row][curr_col] > 8'd0) begin
                            row_used[curr_row][curr_grid[curr_row][curr_col] - 1] <= 1'b0;
                        end
                        curr_grid[curr_row][curr_col] <= 8'd0;
                        state <= VALIDATE_ROW;
                    end else begin
                        // No more solutions
                        state <= DONE_STATE;
                        result <= completion_count;
                        found <= found_any;
                        done <= 1'b1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule