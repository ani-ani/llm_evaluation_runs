module LatinSquareSolver (
    input clk,
    input rst_n,
    input start,
    input [1:0] k,
    input [3:0] in_row0_0, in_row0_1, in_row0_2, in_row0_3,
    input [3:0] in_row1_0, in_row1_1, in_row1_2, in_row1_3,
    input [3:0] in_row2_0, in_row2_1, in_row2_2, in_row2_3,
    input [3:0] in_row3_0, in_row3_1, in_row3_2, in_row3_3,
    output reg done,
    output reg yes,
    output reg [3:0] result_0_0, result_0_1, result_0_2, result_0_3,
    output reg [3:0] result_1_0, result_1_1, result_1_2, result_1_3,
    output reg [3:0] result_2_0, result_2_1, result_2_2, result_2_3,
    output reg [3:0] result_3_0, result_3_1, result_3_2, result_3_3
);

    // State definitions
    localparam [2:0] IDLE            = 3'd0;
    localparam [2:0] LOAD_INPUT      = 3'd1;
    localparam [2:0] VALIDATE        = 3'd2;
    localparam [2:0] FIND_EMPTY      = 3'd3;
    localparam [2:0] CHECK_VALID     = 3'd4;
    localparam [2:0] PLACE_VALUE     = 3'd5;
    localparam [2:0] BACKTRACK       = 3'd6;
    localparam [2:0] FINISH          = 3'd7;

    // Internal state variables
    reg [2:0] state;
    reg [2:0] next_state;
    reg [1:0] row, col;
    reg [1:0] check_row, check_col;
    reg [3:0] try_val;
    reg [3:0] grid [0:3][0:3];
    reg valid_flag;
    reg [2:0] cycle_count;
    localparam [2:0] MAX_CYCLES = 3'd6;

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            yes <= 1'b0;
            cycle_count <= 3'd0;
            // Initialize grid
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    grid[i][j] <= 4'd0;
                end
            end
            // Initialize outputs
            result_0_0 <= 4'd0; result_0_1 <= 4'd0; result_0_2 <= 4'd0; result_0_3 <= 4'd0;
            result_1_0 <= 4'd0; result_1_1 <= 4'd0; result_1_2 <= 4'd0; result_1_3 <= 4'd0;
            result_2_0 <= 4'd0; result_2_1 <= 4'd0; result_2_2 <= 4'd0; result_2_3 <= 4'd0;
            result_3_0 <= 4'd0; result_3_1 <= 4'd0; result_3_2 <= 4'd0; result_3_3 <= 4'd0;
            row <= 2'd0;
            col <= 2'd0;
            check_row <= 2'd0;
            check_col <= 2'd0;
            try_val <= 4'd0;
            valid_flag <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    yes <= 1'b0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        state <= LOAD_INPUT;
                    end
                end

                LOAD_INPUT: begin
                    // Load input into grid
                    grid[0][0] <= in_row0_0; grid[0][1] <= in_row0_1; grid[0][2] <= in_row0_2; grid[0][3] <= in_row0_3;
                    grid[1][0] <= in_row1_0; grid[1][1] <= in_row1_1; grid[1][2] <= in_row1_2; grid[1][3] <= in_row1_3;
                    grid[2][0] <= in_row2_0; grid[2][1] <= in_row2_1; grid[2][2] <= in_row2_2; grid[2][3] <= in_row2_3;
                    grid[3][0] <= in_row3_0; grid[3][1] <= in_row3_1; grid[3][2] <= in_row3_2; grid[3][3] <= in_row3_3;
                    // Check if k rows are pre-filled
                    if (k == 2'd0) begin
                        state <= FIND_EMPTY;
                        row <= 2'd0;
                        col <= 2'd0;
                    end else begin
                        state <= VALIDATE;
                        check_row <= 2'd0;
                    end
                end

                VALIDATE: begin
                    // Validate pre-filled rows
                    if (check_row < k) begin
                        // Check range 1-4
                        if ((grid[check_row][0] < 4'd1 || grid[check_row][0] > 4'd4) ||
                            (grid[check_row][1] < 4'd1 || grid[check_row][1] > 4'd4) ||
                            (grid[check_row][2] < 4'd1 || grid[check_row][2] > 4'd4) ||
                            (grid[check_row][3] < 4'd1 || grid[check_row][3] > 4'd4)) begin
                            yes <= 1'b0;
                            state <= FINISH;
                        end
                        // Check duplicates in row
                        else if ((grid[check_row][0] == grid[check_row][1]) || (grid[check_row][0] == grid[check_row][2]) || (grid[check_row][0] == grid[check_row][3]) ||
                                 (grid[check_row][1] == grid[check_row][2]) || (grid[check_row][1] == grid[check_row][3]) ||
                                 (grid[check_row][2] == grid[check_row][3])) begin
                            yes <= 1'b0;
                            state <= FINISH;
                        end else begin
                            check_row <= check_row + 2'd1;
                        end
                    end else begin
                        // Check columns for pre-filled rows
                        state <= VALIDATE;
                        if (check_col < 4'd4) begin
                            // Check column duplicate
                            reg dup_found;
                            dup_found = 1'b0;
                            // Manual unrolling for column check
                            if (k > 2'd0) begin
                                for (i = 0; i < 3; i = i + 1) begin
                                    for (j = i + 1; j < 4; j = j + 1) begin
                                        if ((j < k) && (grid[i][check_col] == grid[j][check_col])) begin
                                            dup_found = 1'b1;
                                        end
                                    end
                                end
                            end
                            if (dup_found) begin
                                yes <= 1'b0;
                                state <= FINISH;
                            end else begin
                                check_col <= check_col + 2'd1;
                            end
                        end else begin
                            state <= FIND_EMPTY;
                            row <= 2'd0;
                            col <= 2'd0;
                        end
                    end
                end

                FIND_EMPTY: begin
                    // Find next empty cell
                    if (row < 2'd4) begin
                        if (row < k) begin
                            // Skip pre-filled rows
                            row <= row + 2'd1;
                        end else if (grid[row][col] == 4'd0) begin
                            // Found empty cell
                            try_val <= 4'd1;
                            state <= CHECK_VALID;
                        end else begin
                            // Move to next cell
                            if (col < 2'd3) begin
                                col <= col + 2'd1;
                            end else begin
                                col <= 2'd0;
                                row <= row + 2'd1;
                            end
                        end
                    end else begin
                        // No empty cells found
                        yes <= 1'b1;
                        state <= FINISH;
                    end
                end

                CHECK_VALID: begin
                    // Check if try_val is valid for position (row, col)
                    // Check row
                    reg row_ok;
                    reg col_ok;
                    row_ok = 1'b1;
                    col_ok = 1'b1;

                    // Check row (unrolled)
                    if ((grid[row][0] == try_val && col != 2'd0) ||
                        (grid[row][1] == try_val && col != 2'd1) ||
                        (grid[row][2] == try_val && col != 2'd2) ||
                        (grid[row][3] == try_val && col != 2'd3)) begin
                        row_ok = 1'b0;
                    end

                    // Check column (unrolled)
                    if ((grid[0][col] == try_val && row != 2'd0) ||
                        (grid[1][col] == try_val && row != 2'd1) ||
                        (grid[2][col] == try_val && row != 2'd2) ||
                        (grid[3][col] == try_val && row != 2'd3)) begin
                        col_ok = 1'b0;
                    end

                    if (row_ok && col_ok) begin
                        // Valid value found
                        state <= PLACE_VALUE;
                    end else begin
                        // Try next value
                        try_val <= try_val + 4'd1;
                        if (try_val > 4'd4) begin
                            state <= BACKTRACK;
                        end else begin
                            state <= CHECK_VALID;
                        end
                    end
                end

                PLACE_VALUE: begin
                    // Place value and move to next cell
                    grid[row][col] <= try_val;
                    cycle_count <= cycle_count + 3'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        // Prevent infinite loops
                        yes <= 1'b0;
                        state <= FINISH;
                    end else begin
                        // Move to next cell
                        if (col < 2'd3) begin
                            col <= col + 2'd1;
                        end else begin
                            col <= 2'd0;
                            row <= row + 2'd1;
                        end
                        state <= FIND_EMPTY;
                    end
                end

                BACKTRACK: begin
                    // Backtrack to previous empty cell
                    if (col > 2'd0) begin
                        col <= col - 2'd1;
                    end else if (row > k) begin
                        col <= 2'd3;
                        row <= row - 2'd1;
                    end else begin
                        // Backtracked past first empty cell
                        yes <= 1'b0;
                        state <= FINISH;
                    end

                    // Find value to increment
                    if (grid[row][col] >= 4'd4) begin
                        grid[row][col] <= 4'd0;
                        state <= BACKTRACK;
                    end else begin
                        try_val <= grid[row][col] + 4'd1;
                        grid[row][col] <= 4'd0;
                        state <= CHECK_VALID;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    if (yes) begin
                        // Copy result to outputs
                        result_0_0 <= grid[0][0]; result_0_1 <= grid[0][1]; result_0_2 <= grid[0][2]; result_0_3 <= grid[0][3];
                        result_1_0 <= grid[1][0]; result_1_1 <= grid[1][1]; result_1_2 <= grid[1][2]; result_1_3 <= grid[1][3];
                        result_2_0 <= grid[2][0]; result_2_1 <= grid[2][1]; result_2_2 <= grid[2][2]; result_2_3 <= grid[2][3];
                        result_3_0 <= grid[3][0]; result_3_1 <= grid[3][1]; result_3_2 <= grid[3][2]; result_3_3 <= grid[3][3];
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule