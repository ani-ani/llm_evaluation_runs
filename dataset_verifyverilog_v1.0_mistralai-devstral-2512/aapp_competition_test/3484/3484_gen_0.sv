module superdoku_solver(
    input clk,
    input rst_n,
    input start,
    input [2:0] input_row,
    input [2:0] input_col,
    input [3:0] input_val,
    input valid_input,
    output reg [3:0] result_grid [0:63],
    output reg done,
    output reg solvable
);

    // State declarations
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] LOAD_INPUT    = 3'd1;
    localparam [2:0] FIND_SOLUTION = 3'd2;
    localparam [2:0] FOUND         = 3'd3;
    localparam [2:0] IMPOSSIBLE    = 3'd4;

    reg [2:0] state, next_state;

    // Internal registers
    reg [3:0] grid [0:7][0:7];
    reg [3:0] current_row, current_col, current_val;
    reg [3:0] row_count;
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd10000;

    // Column usage bitmask (1 bit per value 1-8)
    reg [7:0] col_used [0:7];

    // Row completion tracking
    reg [7:0] row_complete;

    // Input phase tracking
    reg [2:0] expected_row, expected_col;
    reg input_phase_done;

    // Solution found flag
    reg solution_found;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_INPUT;
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD_INPUT: begin
                if (input_phase_done) begin
                    next_state = FIND_SOLUTION;
                end else begin
                    next_state = LOAD_INPUT;
                end
            end

            FIND_SOLUTION: begin
                if (solution_found) begin
                    next_state = FOUND;
                end else if (cycle_count >= MAX_CYCLES) begin
                    next_state = IMPOSSIBLE;
                end else begin
                    next_state = FIND_SOLUTION;
                end
            end

            FOUND: begin
                next_state = IDLE;
            end

            IMPOSSIBLE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            solvable <= 1'b0;
            input_phase_done <= 1'b0;
            expected_row <= 3'd0;
            expected_col <= 3'd0;
            solution_found <= 1'b0;
            cycle_count <= 32'd0;
            row_count <= 4'd0;
            current_row <= 3'd0;
            current_col <= 3'd0;
            current_val <= 4'd1;
            row_complete <= 8'd0;

            // Initialize grid and column usage
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    grid[i][j] <= 4'd0;
                end
                col_used[i] <= 8'd0;
            end

            // Initialize result_grid
            for (i = 0; i < 64; i = i + 1) begin
                result_grid[i] <= 4'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    solvable <= 1'b0;
                    input_phase_done <= 1'b0;
                    expected_row <= 3'd0;
                    expected_col <= 3'd0;
                    solution_found <= 1'b0;
                    cycle_count <= 32'd0;
                    row_count <= 4'd0;
                    current_row <= 3'd0;
                    current_col <= 3'd0;
                    current_val <= 4'd1;
                    row_complete <= 8'd0;

                    // Clear grid and column usage
                    integer i, j;
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            grid[i][j] <= 4'd0;
                        end
                        col_used[i] <= 8'd0;
                    end

                    // Clear result_grid
                    for (i = 0; i < 64; i = i + 1) begin
                        result_grid[i] <= 4'd0;
                    end
                end

                LOAD_INPUT: begin
                    // Store input when valid
                    if (valid_input && input_row == expected_row && input_col == expected_col) begin
                        grid[input_row][input_col] <= input_val;
                        col_used[input_col][input_val - 1] <= 1'b1;

                        // Update expected position
                        if (expected_col == 3'd7) begin
                            if (expected_row == 3'd4) begin
                                input_phase_done <= 1'b1;
                            end else begin
                                expected_row <= expected_row + 3'd1;
                                expected_col <= 3'd0;
                            end
                        end else begin
                            expected_col <= expected_col + 3'd1;
                        end
                    end

                    // Check if input phase is complete
                    if (input_phase_done) begin
                        // Initialize for solving
                        current_row <= 3'd0;
                        current_col <= 3'd0;
                        current_val <= 4'd1;
                        row_count <= 4'd0;
                        cycle_count <= 32'd0;
                        solution_found <= 1'b0;

                        // Mark initial rows as complete
                        row_complete <= {5'b11111, 3'b000};

                        // Update column usage for initial rows
                        integer i, j;
                        for (j = 0; j < 8; j = j + 1) begin
                            col_used[j] <= 8'd0;
                        end
                        for (i = 0; i < 5; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                if (grid[i][j] != 4'd0) begin
                                    col_used[j][grid[i][j] - 1] <= 1'b1;
                                end
                            end
                        end
                    end
                end

                FIND_SOLUTION: begin
                    cycle_count <= cycle_count + 32'd1;

                    // Check if we've completed all rows
                    if (row_complete == 8'd255) begin
                        solution_found <= 1'b1;
                    end else begin
                        // Find next incomplete row
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (!row_complete[i]) begin
                                current_row <= i;
                                break;
                            end
                        end

                        // Try to place a value in current column
                        if (current_col == 3'd7) begin
                            // Row complete, mark it
                            row_complete[current_row] <= 1'b1;
                            current_col <= 3'd0;
                            current_val <= 4'd1;
                        end else begin
                            // Check if current_val is valid
                            reg valid;
                            reg [7:0] row_vals;
                            integer k;

                            // Check row for duplicates
                            valid = 1'b1;
                            row_vals = 8'd0;
                            for (k = 0; k < 8; k = k + 1) begin
                                if (grid[current_row][k] != 4'd0) begin
                                    row_vals[grid[current_row][k] - 1] = 1'b1;
                                end
                            end

                            if (row_vals[current_val - 1]) begin
                                valid = 1'b0;
                            end

                            // Check column for duplicates
                            if (col_used[current_col][current_val - 1]) begin
                                valid = 1'b0;
                            end

                            if (valid) begin
                                // Place the value
                                grid[current_row][current_col] <= current_val;
                                col_used[current_col][current_val - 1] <= 1'b1;
                                current_col <= current_col + 3'd1;
                                current_val <= 4'd1;
                            end else begin
                                // Try next value
                                if (current_val == 4'd8) begin
                                    // Backtrack
                                    if (current_col == 3'd0) begin
                                        // No solution possible from this row
                                        row_complete[current_row] <= 1'b1;
                                        current_col <= 3'd0;
                                        current_val <= 4'd1;
                                    end else begin
                                        // Remove previous value and try next
                                        current_col <= current_col - 3'd1;
                                        col_used[current_col][grid[current_row][current_col] - 1] <= 1'b0;
                                        grid[current_row][current_col] <= 4'd0;
                                        current_val <= grid[current_row][current_col] + 4'd1;
                                    end
                                end else begin
                                    current_val <= current_val + 4'd1;
                                end
                            end
                        end
                    end
                end

                FOUND: begin
                    done <= 1'b1;
                    solvable <= 1'b1;

                    // Copy grid to result_grid
                    integer i, j, idx;
                    idx = 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            result_grid[idx] <= grid[i][j];
                            idx = idx + 1;
                        end
                    end
                end

                IMPOSSIBLE: begin
                    done <= 1'b1;
                    solvable <= 1'b0;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule