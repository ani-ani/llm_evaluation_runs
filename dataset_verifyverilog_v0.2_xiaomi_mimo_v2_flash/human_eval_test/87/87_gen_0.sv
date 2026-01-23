module get_row(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_rows,
    input [2:0] row_lengths [0:7],
    input [7:0] lst [0:7][0:7],
    input [7:0] x,
    output reg [2:0] result_count,
    output reg [2:0] result_rows [0:7],
    output reg [2:0] result_cols [0:7],
    output reg done
);

    // State encoding
    localparam IDLE        = 4'b0000;
    localparam SCAN_ROW    = 4'b0001;
    localparam SCAN_COL    = 4'b0010;
    localparam CHECK_MATCH = 4'b0011;
    localparam STORE_MATCH = 4'b0100;
    localparam SORT_INIT   = 4'b0101;
    localparam SORT_LOOP   = 4'b0110;
    localparam SORT_CHECK  = 4'b0111;
    localparam SORT_SWAP   = 4'b1000;
    localparam OUTPUT      = 4'b1001;
    localparam DONE        = 4'b1010;

    reg [3:0] state, next_state;

    // Temporary buffer for matches (max 8)
    reg [2:0] temp_rows [0:7];
    reg [2:0] temp_cols [0:7];
    reg [2:0] match_count;
    reg [2:0] temp_idx; // Index for buffer operations

    // Scan counters
    reg [2:0] scan_row;
    reg [2:0] scan_col;

    // Sorting counters
    reg [2:0] i, j;
    reg swap_needed;

    // Helper logic for sorting comparison
    // Condition: (r1 > r2) || (r1 == r2 && c1 < c2)
    // We want to swap if row_a > row_b OR (row_a == row_b && col_a < col_b)
    wire swap_condition;
    assign swap_condition = (temp_rows[i] > temp_rows[j]) || 
                            ((temp_rows[i] == temp_rows[j]) && (temp_cols[i] < temp_cols[j]));

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = SCAN_ROW;
                else next_state = IDLE;
            end
            SCAN_ROW: begin
                if (scan_row < num_rows) next_state = SCAN_COL;
                else next_state = SORT_INIT; // All rows scanned
            end
            SCAN_COL: begin
                if (scan_col < row_lengths[scan_row]) next_state = CHECK_MATCH;
                else next_state = SCAN_ROW_INCR; // Go to increment row logic (handled via separate state or inline)
                // Note: For cleaner FSM, let's just go to IDLE logic or handle increment in state logic.
                // Let's make SCAN_COL loop or transition to next row.
                // Better: SCAN_COL checks condition, if valid column -> CHECK_MATCH. 
                // If end of column -> increment scan_row and go to SCAN_ROW.
                if (scan_col >= row_lengths[scan_row]) next_state = SCAN_ROW;
                else next_state = CHECK_MATCH;
            end
            CHECK_MATCH: begin
                if (lst[scan_row][scan_col] == x) next_state = STORE_MATCH;
                else next_state = SCAN_COL_INC;
            end
            STORE_MATCH: next_state = SCAN_COL_INC;
            SCAN_COL_INC: next_state = SCAN_COL; // Increment column counter
            SORT_INIT: begin
                if (match_count > 1) next_state = SORT_LOOP;
                else next_state = OUTPUT;
            end
            SORT_LOOP: begin
                // Bubble sort outer loop logic: if i < match_count - 1
                if (i < match_count - 1) next_state = SORT_CHECK;
                else next_state = OUTPUT;
            end
            SORT_CHECK: begin
                // Inner loop logic: if j < match_count - 1 - i
                if (j < match_count - 1 - i) begin
                    if (swap_condition) next_state = SORT_SWAP;
                    else next_state = SORT_J_INC;
                end else begin
                    next_state = SORT_I_INC;
                end
            end
            SORT_SWAP: next_state = SORT_J_INC;
            SORT_J_INC: next_state = SORT_CHECK;
            SORT_I_INC: next_state = SORT_LOOP;
            OUTPUT: next_state = DONE;
            DONE: begin
                if (!start) next_state = IDLE;
                else next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
        // Fix for SCAN_COL state transition logic conflict in case statement:
        // Re-write SCAN_COL clearly:
        // If we are in SCAN_COL, we check if we are done with this row.
        // If done, go to IDLE (wait for next start) or just back to SCAN_ROW to check row index again.
        // Let's refine logic to: In SCAN_COL, if col is valid -> CHECK_MATCH. Else -> Back to SCAN_ROW to increment.
    end
    
    // Refined Next State Logic to handle flow correctly without intermediate states for increments
    always @(*) begin
        case (state)
            IDLE:           next_state = start ? SCAN_ROW : IDLE;
            
            // Scan Row State: Check if we are within bounds
            SCAN_ROW:       next_state = (scan_row < num_rows) ? SCAN_COL : SORT_INIT;
            
            // Scan Col State: Check if column index is valid for current row
            SCAN_COL:       next_state = (scan_col < row_lengths[scan_row]) ? CHECK_MATCH : SCAN_ROW;
            
            CHECK_MATCH:    next_state = (lst[scan_row][scan_col] == x) ? STORE_MATCH : SCAN_COL_INC;
            
            STORE_MATCH:    next_state = SCAN_COL_INC;
            
            SCAN_COL_INC:   next_state = SCAN_COL;
            
            SORT_INIT:      next_state = (match_count > 1) ? SORT_LOOP : OUTPUT;
            
            SORT_LOOP:      next_state = (i < match_count - 1) ? SORT_CHECK : OUTPUT;
            
            SORT_CHECK:     next_state = (j < match_count - 1 - i) ? (swap_condition ? SORT_SWAP : SORT_J_INC) : SORT_I_INC;
            
            SORT_SWAP:      next_state = SORT_J_INC;
            
            SORT_J_INC:     next_state = SORT_CHECK;
            
            SORT_I_INC:     next_state = SORT_LOOP;
            
            OUTPUT:         next_state = DONE;
            
            DONE:           next_state = start ? DONE : IDLE;
            
            default:        next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_count <= 0;
            match_count <= 0;
            done <= 0;
            scan_row <= 0;
            scan_col <= 0;
            i <= 0;
            j <= 0;
            // Reset output arrays to avoid 'x' propagation in some simulators, though strictly not required by spec
            for (int k=0; k<8; k++) begin
                result_rows[k] <= 0;
                result_cols[k] <= 0;
                temp_rows[k] <= 0;
                temp_cols[k] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    scan_row <= 0;
                    scan_col <= 0;
                    match_count <= 0;
                    i <= 0;
                    j <= 0;
                end

                SCAN_ROW: begin
                    // Reset column counter when entering a new row scan
                    scan_col <= 0;
                end

                SCAN_COL: begin
                    // Just waits for logic to decide next state based on bounds
                end

                CHECK_MATCH: begin
                    // Combinational check, waiting for state transition
                end

                STORE_MATCH: begin
                    if (match_count < 8) begin
                        temp_rows[match_count] <= scan_row;
                        temp_cols[match_count] <= scan_col;
                        match_count <= match_count + 1;
                    end
                end

                SCAN_COL_INC: begin
                    scan_col <= scan_col + 1;
                end

                SORT_INIT: begin
                    i <= 0;
                    j <= 0;
                end

                SORT_LOOP: begin
                    // Reset j for inner loop
                    j <= 0;
                end

                SORT_CHECK: begin
                    // Logic handled in next_state decision, waiting for transition
                end

                SORT_SWAP: begin
                    // Perform swap of elements i and j
                    temp_rows[i] <= temp_rows[j];
                    temp_cols[i] <= temp_cols[j];
                    temp_rows[j] <= temp_rows[i];
                    temp_cols[j] <= temp_cols[i];
                end

                SORT_J_INC: begin
                    j <= j + 1;
                end

                SORT_I_INC: begin
                    i <= i + 1;
                end

                OUTPUT: begin
                    result_count <= match_count;
                    for (int k=0; k<8; k++) begin
                        result_rows[k] <= temp_rows[k];
                        result_cols[k] <= temp_cols[k];
                    end
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule