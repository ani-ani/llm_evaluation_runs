module monopole_magnet_solver (
    input clk,
    input rst_n,
    input start,
    input [5:0] grid_flat [0:15],
    output reg [3:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        CHECK_ROWS,
        CHECK_COLS,
        CHECK_EMPTY,
        COUNT_COMPONENTS,
        DONE,
        ERROR
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [3:0] row_idx;
    reg [3:0] col_idx;
    reg [3:0] cell_idx;
    reg [3:0] component_count;
    reg [15:0] visited;
    reg [3:0] stack_ptr;
    reg [3:0] stack [0:15];
    reg has_empty_row;
    reg has_empty_col;
    reg row_valid;
    reg col_valid;
    reg error_flag;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            row_idx <= 0;
            col_idx <= 0;
            cell_idx <= 0;
            component_count <= 0;
            visited <= 0;
            stack_ptr <= 0;
            has_empty_row <= 0;
            has_empty_col <= 0;
            row_valid <= 1;
            col_valid <= 1;
            error_flag <= 0;
            result <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = CHECK_ROWS;
            end
            CHECK_ROWS: begin
                if (row_idx == 4) begin
                    if (!row_valid) next_state = ERROR;
                    else next_state = CHECK_COLS;
                end
            end
            CHECK_COLS: begin
                if (col_idx == 4) begin
                    if (!col_valid) next_state = ERROR;
                    else next_state = CHECK_EMPTY;
                end
            end
            CHECK_EMPTY: begin
                if (has_empty_row != has_empty_col) next_state = ERROR;
                else next_state = COUNT_COMPONENTS;
            end
            COUNT_COMPONENTS: begin
                if (cell_idx == 16) begin
                    if (error_flag) next_state = ERROR;
                    else next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            ERROR: begin
                next_state = IDLE;
            end
        endcase
    end

    // Row check logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_idx <= 0;
            row_valid <= 1;
        end else if (current_state == CHECK_ROWS) begin
            if (row_idx < 4) begin
                reg [3:0] row_start = row_idx * 4;
                reg [3:0] row_end = row_start + 4;
                reg [3:0] i;
                reg in_black = 0;
                reg has_black = 0;

                for (i = row_start; i < row_end; i = i + 1) begin
                    if (grid_flat[i][0]) begin
                        has_black = 1;
                        if (!in_black) in_black = 1;
                    end else begin
                        if (in_black) row_valid = 0;
                    end
                end

                if (has_black && !in_black) row_valid = 0;
                row_idx <= row_idx + 1;
            end
        end
    end

    // Column check logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_idx <= 0;
            col_valid <= 1;
        end else if (current_state == CHECK_COLS) begin
            if (col_idx < 4) begin
                reg [3:0] i;
                reg in_black = 0;
                reg has_black = 0;

                for (i = 0; i < 4; i = i + 1) begin
                    reg [3:0] cell = i * 4 + col_idx;
                    if (grid_flat[cell][0]) begin
                        has_black = 1;
                        if (!in_black) in_black = 1;
                    end else begin
                        if (in_black) col_valid = 0;
                    end
                end

                if (has_black && !in_black) col_valid = 0;
                col_idx <= col_idx + 1;
            end
        end
    end

    // Empty row/column check
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            has_empty_row <= 0;
            has_empty_col <= 0;
        end else if (current_state == CHECK_EMPTY) begin
            reg [3:0] i;
            reg row_empty = 1;
            reg col_empty = 1;

            for (i = 0; i < 4; i = i + 1) begin
                reg [3:0] row_start = i * 4;
                reg [3:0] row_end = row_start + 4;
                reg [3:0] j;

                for (j = row_start; j < row_end; j = j + 1) begin
                    if (grid_flat[j][0]) row_empty = 0;
                end

                if (row_empty) has_empty_row = 1;
            end

            for (i = 0; i < 4; i = i + 1) begin
                reg [3:0] j;

                for (j = 0; j < 4; j = j + 1) begin
                    reg [3:0] cell = j * 4 + i;
                    if (grid_flat[cell][0]) col_empty = 0;
                end

                if (col_empty) has_empty_col = 1;
            end
        end
    end

    // DFS logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cell_idx <= 0;
            component_count <= 0;
            visited <= 0;
            stack_ptr <= 0;
        end else if (current_state == COUNT_COMPONENTS) begin
            if (cell_idx < 16) begin
                if (!visited[cell_idx] && grid_flat[cell_idx][0]) begin
                    component_count <= component_count + 1;
                    stack[0] <= cell_idx;
                    stack_ptr <= 1;
                    visited[cell_idx] <= 1;

                    while (stack_ptr > 0) begin
                        reg [3:0] current = stack[stack_ptr - 1];
                        stack_ptr <= stack_ptr - 1;

                        reg [3:0] row = current / 4;
                        reg [3:0] col = current % 4;

                        // Check neighbors
                        reg [3:0] neighbor;
                        reg [3:0] dir;

                        for (dir = 0; dir < 4; dir = dir + 1) begin
                            case (dir)
                                0: neighbor = (row > 0) ? (row - 1) * 4 + col : 16;
                                1: neighbor = (row < 3) ? (row + 1) * 4 + col : 16;
                                2: neighbor = (col > 0) ? row * 4 + (col - 1) : 16;
                                3: neighbor = (col < 3) ? row * 4 + (col + 1) : 16;
                            endcase

                            if (neighbor < 16 && !visited[neighbor] && grid_flat[neighbor][0]) begin
                                visited[neighbor] <= 1;
                                stack[stack_ptr] <= neighbor;
                                stack_ptr <= stack_ptr + 1;
                            end
                        end
                    end
                end
                cell_idx <= cell_idx + 1;
            end
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
        end else begin
            case (current_state)
                DONE: begin
                    result <= component_count;
                    done <= 1;
                end
                ERROR: begin
                    result <= 4'b1111;
                    done <= 1;
                end
                default: begin
                    result <= 0;
                    done <= 0;
                end
            endcase
        end
    end

endmodule