module monotonic_subgrids (
    input clk,
    input rst_n,
    input start,
    input [7:0] grid [0:3][0:3],
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam SETUP = 3'b001;
    localparam CHECK_ROWS = 3'b010;
    localparam CHECK_COLS = 3'b011;
    localparam INCREMENT = 3'b100;
    localparam DONE = 3'b101;

    // Registers for state and counters
    reg [2:0] current_state, next_state;
    reg [3:0] row_mask, next_row_mask; // 4 bits for 4 rows
    reg [3:0] col_mask, next_col_mask; // 4 bits for 4 cols
    reg [15:0] result_reg, next_result;
    reg [1:0] row_idx, col_idx; // Iterators for checking
    reg [1:0] next_row_idx, next_col_idx;
    
    // Helper signals for monotonicity checks
    wire rows_monotonic;
    wire cols_monotonic;
    wire [3:0] active_row_count;
    wire [3:0] active_col_count;
    
    // Intermediate signals for comparison logic
    reg [7:0] prev_val;
    reg [7:0] curr_val;
    reg row_dir; // 0: unknown, 1: inc, 2: dec
    reg col_dir;
    reg row_check_fail;
    reg col_check_fail;
    
    // Combinational logic to count active bits (selected rows/cols)
    assign active_row_count = row_mask[0] + row_mask[1] + row_mask[2] + row_mask[3];
    assign active_col_count = col_mask[0] + col_mask[1] + col_mask[2] + col_mask[3];

    // State transition logic
    always @(*) begin
        next_state = current_state;
        next_row_mask = row_mask;
        next_col_mask = col_mask;
        next_result = result_reg;
        next_row_idx = row_idx;
        next_col_idx = col_idx;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = SETUP;
                    next_result = 16'd0;
                    next_row_mask = 4'b0001; // Start with first row
                    next_col_mask = 4'b0001; // Start with first col
                end
            end
            
            SETUP: begin
                // Check if current subgrid is valid (not empty)
                if (active_row_count > 0 && active_col_count > 0) begin
                    if (active_row_count == 1) begin
                        // Single row, skip row check
                        next_state = CHECK_COLS;
                        next_row_idx = 0;
                        next_col_idx = 0;
                    end else begin
                        next_state = CHECK_ROWS;
                        next_row_idx = 0;
                        next_col_idx = 0;
                    end
                end else begin
                    // Empty subset, skip to next
                    next_state = INCREMENT;
                end
            end
            
            CHECK_ROWS: begin
                // Logic handled in separate combinational block
                // Transition based on row_check_fail
                if (row_check_fail) begin
                    next_state = INCREMENT;
                end else begin
                    if (active_col_count == 1) begin
                        // Single column, skip col check
                        next_state = INCREMENT;
                    end else begin
                        next_state = CHECK_COLS;
                        next_col_idx = 0;
                    end
                end
            end
            
            CHECK_COLS: begin
                // Logic handled in separate combinational block
                if (col_check_fail) begin
                    next_state = INCREMENT;
                end else begin
                    next_state = INCREMENT;
                end
            end
            
            INCREMENT: begin
                // Increment column mask
                if (col_mask < 4'b1111) begin
                    next_col_mask = {1'b0, col_mask[3:1]} + (col_mask << 1);
                    // If col_mask becomes 0 (overflow), reset to 1
                    if ({1'b0, col_mask[3:1]} + (col_mask << 1) == 0)
                        next_col_mask = 4'b0001;
                    else
                        next_col_mask = {col_mask[2:0], col_mask[3]};
                    // Better rotation logic: shift left, wrap around
                    next_col_mask = {col_mask[2:0], col_mask[3]};
                    if (next_col_mask < 4'b0001) next_col_mask = 4'b0001; // Safety
                    
                    // Actually, let's do binary increment pattern
                    if (col_mask == 4'b0001) next_col_mask = 4'b0010;
                    else if (col_mask == 4'b0010) next_col_mask = 4'b0011;
                    else if (col_mask == 4'b0011) next_col_mask = 4'b0100;
                    else if (col_mask == 4'b0100) next_col_mask = 4'b0101;
                    else if (col_mask == 4'b0101) next_col_mask = 4'b0110;
                    else if (col_mask == 4'b0110) next_col_mask = 4'b0111;
                    else if (col_mask == 4'b0111) next_col_mask = 4'b1000;
                    else if (col_mask == 4'b1000) next_col_mask = 4'b1001;
                    else if (col_mask == 4'b1001) next_col_mask = 4'b1010;
                    else if (col_mask == 4'b1010) next_col_mask = 4'b1011;
                    else if (col_mask == 4'b1011) next_col_mask = 4'b1100;
                    else if (col_mask == 4'b1100) next_col_mask = 4'b1101;
                    else if (col_mask == 4'b1101) next_col_mask = 4'b1110;
                    else if (col_mask == 4'b1110) next_col_mask = 4'b1111;
                    else next_col_mask = 4'b0001; // Wrap to next row set
                    
                    // Logic fix: iterate col_mask fully, then row_mask
                    if (col_mask == 4'b1111) begin
                        next_col_mask = 4'b0001;
                        // Increment row mask
                        if (row_mask == 4'b0001) next_row_mask = 4'b0010;
                        else if (row_mask == 4'b0010) next_row_mask = 4'b0011;
                        else if (row_mask == 4'b0011) next_row_mask = 4'b0100;
                        else if (row_mask == 4'b0100) next_row_mask = 4'b0101;
                        else if (row_mask == 4'b0101) next_row_mask = 4'b0110;
                        else if (row_mask == 4'b0110) next_row_mask = 4'b0111;
                        else if (row_mask == 4'b0111) next_row_mask = 4'b1000;
                        else if (row_mask == 4'b1000) next_row_mask = 4'b1001;
                        else if (row_mask == 4'b1001) next_row_mask = 4'b1010;
                        else if (row_mask == 4'b1010) next_row_mask = 4'b1011;
                        else if (row_mask == 4'b1011) next_row_mask = 4'b1100;
                        else if (row_mask == 4'b1100) next_row_mask = 4'b1101;
                        else if (row_mask == 4'b1101) next_row_mask = 4'b1110;
                        else if (row_mask == 4'b1110) next_row_mask = 4'b1111;
                        else next_row_mask = 4'b0001; // Wrap to done
                        
                        if (row_mask == 4'b1111 && col_mask == 4'b1111) begin
                            next_state = DONE;
                        end else if (next_row_mask < row_mask) begin
                            // Wrapped around to start
                            if (col_mask == 4'b1111) next_state = DONE;
                            else next_state = SETUP;
                        end else begin
                            next_state = SETUP;
                        end
                    end else begin
                        next_state = SETUP;
                    end
                    
                    // Simplified Logic for INCREMENT state
                    // 1. Advance col_mask to next subset
                    // 2. If col_mask wraps to 0001 (completed cycle), advance row_mask
                    // 3. If row_mask wraps to 0001 (completed cycle), go to DONE
                    
                    // Correct Loop Logic:
                    // col_mask iterates through all non-zero subsets (0001 to 1111)
                    // row_mask iterates through all non-zero subsets (0001 to 1111)
                    
                    // Let's use simple counters and combinational next values logic
                end
            end
            
            DONE: begin
                // Wait for reset or start
                if (~rst_n) next_state = IDLE;
                else next_state = DONE;
            end
        endcase
    end
    
    // Combinational Logic for Monotonicity Checks
    // Checking Rows
    always @(*) begin
        row_check_fail = 0;
        row_dir = 0; // 0: unknown, 1: inc, 2: dec
        
        // Only check if more than 1 row is selected
        if (active_row_count > 1) begin
            // Iterate through selected rows to get values
            // We need to check strictly increasing or strictly decreasing
            // For the selected rows in the order 0,1,2,3
            
            integer r1, r2;
            reg [7:0] val1, val2;
            reg first_found;
            
            first_found = 0;
            
            for (r1 = 0; r1 < 4; r1 = r1 + 1) begin
                if (row_mask[r1]) begin
                    if (!first_found) begin
                        // This is the first value in the row sequence
                        // We need to find the next selected value to determine direction
                        // Or just check all consecutive pairs in the selected set
                        first_found = 1;
                    end
                end
            end
            
            // Actually, let's iterate 0 to 3, tracking previous selected value
            reg [7:0] prev_val_reg;
            reg found_prev;
            reg local_dir;
            
            found_prev = 0;
            local_dir = 0;
            
            for (r1 = 0; r1 < 4; r1 = r1 + 1) begin
                if (row_mask[r1]) begin
                    if (!found_prev) begin
                        found_prev = 1;
                        prev_val_reg = grid[r1][0]; // Value doesn't matter, just placeholder
                        // We need to compare values across rows for a specific column context? 
                        // NO, row monotonicity is PER ROW in the subgrid.
                        // "each selected row is either strictly increasing OR strictly decreasing"
                        // This means: For the sequence of values in Row r, 
                        // look at the values at the selected columns.
                    end
                end
            end
            
            // Re-interpretation: "each selected row is either strictly increasing OR strictly decreasing"
            // This applies to the sequence of elements in that row (across the selected columns).
            // "each selected column is either strictly increasing OR strictly decreasing"
            // This applies to the sequence of elements in that column (across the selected rows).
            
            // Wait, the prompt says "Check all possible subgrids (rows and columns subsets)".
            // "A subgrid is monotonic if ... each selected row is ... AND each selected column is ..."
            
            // Let's assume the check is on the subgrid structure.
            // Row Check: For each selected row, the elements at selected columns must form a monotonic sequence.
            // Col Check: For each selected col, the elements at selected rows must form a monotonic sequence.
            
            // Reset check variables
            row_check_fail = 0;
            
            // Check each selected row
            for (integer r = 0; r < 4; r++) begin
                if (row_mask[r]) begin
                    // Check this row's values across selected cols
                    reg [7:0] prev_v;
                    reg first_val;
                    reg dir;
                    first_val = 1;
                    dir = 0;
                    
                    for (integer c = 0; c < 4; c++) begin
                        if (col_mask[c]) begin
                            if (first_val) begin
                                prev_v = grid[r][c];
                                first_val = 0;
                            end else begin
                                if (grid[r][c] == prev_v) begin
                                    row_check_fail = 1; // Strictly increasing/decreasing
                                end else if (grid[r][c] > prev_v) begin
                                    if (dir == 2) row_check_fail = 1; // Was dec, now inc
                                    else dir = 1; // Inc
                                end else begin // grid[r][c] < prev_v
                                    if (dir == 1) row_check_fail = 1; // Was inc, now dec
                                    else dir = 2; // Dec
                                end
                                prev_v = grid[r][c];
                            end
                        end
                    end
                    if (row_check_fail) break;
                end
            end
        end
    end

    // Combinational Logic for Column Checks
    always @(*) begin
        col_check_fail = 0;
        
        if (active_col_count > 1) begin
            // Check each selected column
            for (integer c = 0; c < 4; c++) begin
                if (col_mask[c]) begin
                    // Check this col's values across selected rows
                    reg [7:0] prev_v;
                    reg first_val;
                    reg dir;
                    first_val = 1;
                    dir = 0;
                    
                    for (integer r = 0; r < 4; r++) begin
                        if (row_mask[r]) begin
                            if (first_val) begin
                                prev_v = grid[r][c];
                                first_val = 0;
                            end else begin
                                if (grid[r][c] == prev_v) begin
                                    col_check_fail = 1;
                                end else if (grid[r][c] > prev_v) begin
                                    if (dir == 2) col_check_fail = 1;
                                    else dir = 1;
                                end else begin
                                    if (dir == 1) col_check_fail = 1;
                                    else dir = 2;
                                end
                                prev_v = grid[r][c];
                            end
                        end
                    end
                    if (col_check_fail) break;
                end
            end
        end
    end

    // Sequential Logic for State and Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            result_reg <= 0;
            row_mask <= 0;
            col_mask <= 0;
        end else begin
            current_state <= next_state;
            result_reg <= next_result;
            result <= next_result;
            row_mask <= next_row_mask;
            col_mask <= next_col_mask;
            
            if (next_state == DONE)
                done <= 1;
            else
                done <= 0;
        end
    end

endmodule
