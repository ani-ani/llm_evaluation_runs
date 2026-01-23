module crossword_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] grid_in [0:7][0:7],
    input [7:0] word_list [0:15][0:7],
    input [3:0] num_words,
    input [2:0] grid_width,
    input [2:0] grid_height,
    output reg [7:0] grid_out [0:7][0:7],
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        PLACE_WORD,
        CHECK_SOLUTION,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [3:0] word_index;
    reg [2:0] row, col;
    reg [2:0] word_length;
    reg [2:0] char_index;
    reg [7:0] current_word [0:7];
    reg [7:0] temp_grid [0:7][0:7];
    reg [3:0] placed_words;
    reg [2:0] backtrack_row, backtrack_col;
    reg backtrack_orientation; // 0: horizontal, 1: vertical

    // Initialize grid
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    grid_out[i][j] <= grid_in[i][j];
                    temp_grid[i][j] <= grid_in[i][j];
                end
            end
            word_index <= 0;
            row <= 0;
            col <= 0;
            char_index <= 0;
            placed_words <= 0;
            backtrack_row <= 0;
            backtrack_col <= 0;
            backtrack_orientation <= 0;
        end else begin
            current_state <= next_state;
            case (current_state)
                IDLE: begin
                    if (start) begin
                        next_state <= PLACE_WORD;
                        // Initialize temp grid
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                temp_grid[i][j] <= grid_in[i][j];
                            end
                        end
                        word_index <= 0;
                        row <= 0;
                        col <= 0;
                        placed_words <= 0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                PLACE_WORD: begin
                    // Load current word
                    for (i = 0; i < 8; i = i + 1) begin
                        current_word[i] <= word_list[word_index][i];
                    end
                    // Calculate word length
                    word_length <= 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (current_word[i] != 0) begin
                            word_length <= i + 1;
                        end
                    end
                    // Try to place word horizontally
                    if (can_place_horizontal(row, col, word_length, current_word, temp_grid, grid_width, grid_height)) begin
                        place_word_horizontal(row, col, word_length, current_word, temp_grid);
                        placed_words <= placed_words + 1;
                        if (placed_words == num_words) begin
                            next_state <= CHECK_SOLUTION;
                        end else begin
                            word_index <= word_index + 1;
                            row <= 0;
                            col <= 0;
                        end
                    end else begin
                        // Try to place word vertically
                        if (can_place_vertical(row, col, word_length, current_word, temp_grid, grid_width, grid_height)) begin
                            place_word_vertical(row, col, word_length, current_word, temp_grid);
                            placed_words <= placed_words + 1;
                            if (placed_words == num_words) begin
                                next_state <= CHECK_SOLUTION;
                            end else begin
                                word_index <= word_index + 1;
                                row <= 0;
                                col <= 0;
                            end
                        end else begin
                            // Move to next position
                            if (col == 7) begin
                                if (row == 7) begin
                                    // Backtrack
                                    if (word_index == 0) begin
                                        next_state <= DONE;
                                        done <= 0;
                                    end else begin
                                        word_index <= word_index - 1;
                                        row <= backtrack_row;
                                        col <= backtrack_col;
                                        // Restore grid
                                        restore_grid(temp_grid, grid_in);
                                        // Re-place words up to word_index
                                        for (i = 0; i < word_index; i = i + 1) begin
                                            // Re-place logic would go here
                                        end
                                    end
                                end else begin
                                    row <= row + 1;
                                    col <= 0;
                                end
                            end else begin
                                col <= col + 1;
                            end
                        end
                    end
                end
                CHECK_SOLUTION: begin
                    // Copy temp grid to output
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            grid_out[i][j] <= temp_grid[i][j];
                        end
                    end
                    done <= 1;
                    next_state <= DONE;
                end
                DONE: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Function to check if word can be placed horizontally
    function automatic can_place_horizontal;
        input [2:0] r, c;
        input [2:0] len;
        input [7:0] word [0:7];
        input [7:0] grid [0:7][0:7];
        input [2:0] width, height;
        begin
            if (c + len > width) begin
                can_place_horizontal = 0;
            end else begin
                for (integer i = 0; i < len; i = i + 1) begin
                    if (grid[r][c + i] != 0 && grid[r][c + i] != word[i]) begin
                        can_place_horizontal = 0;
                        return;
                    end
                end
                can_place_horizontal = 1;
            end
        end
    endfunction

    // Function to place word horizontally
    function automatic place_word_horizontal;
        input [2:0] r, c;
        input [2:0] len;
        input [7:0] word [0:7];
        output [7:0] grid [0:7][0:7];
        integer i;
        begin
            for (i = 0; i < len; i = i + 1) begin
                grid[r][c + i] = word[i];
            end
        end
    endfunction

    // Function to check if word can be placed vertically
    function automatic can_place_vertical;
        input [2:0] r, c;
        input [2:0] len;
        input [7:0] word [0:7];
        input [7:0] grid [0:7][0:7];
        input [2:0] width, height;
        begin
            if (r + len > height) begin
                can_place_vertical = 0;
            end else begin
                for (integer i = 0; i < len; i = i + 1) begin
                    if (grid[r + i][c] != 0 && grid[r + i][c] != word[i]) begin
                        can_place_vertical = 0;
                        return;
                    end
                end
                can_place_vertical = 1;
            end
        end
    endfunction

    // Function to place word vertically
    function automatic place_word_vertical;
        input [2:0] r, c;
        input [2:0] len;
        input [7:0] word [0:7];
        output [7:0] grid [0:7][0:7];
        integer i;
        begin
            for (i = 0; i < len; i = i + 1) begin
                grid[r + i][c] = word[i];
            end
        end
    endfunction

    // Function to restore grid
    function automatic restore_grid;
        output [7:0] grid [0:7][0:7];
        input [7:0] initial_grid [0:7][0:7];
        integer i, j;
        begin
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    grid[i][j] = initial_grid[i][j];
                end
            end
        end
    endfunction

endmodule