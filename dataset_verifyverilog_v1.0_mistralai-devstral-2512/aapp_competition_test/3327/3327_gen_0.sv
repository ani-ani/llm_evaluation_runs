module crossword_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid [0:255],
    input wire [7:0] words [0:511],
    input wire [4:0] num_words,
    input wire [4:0] grid_rows,
    input wire [4:0] grid_cols,
    output reg [7:0] result_grid [0:255],
    output reg done,
    output reg valid
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] WORD_SELECT = 4'd2;
    localparam [3:0] FIND_PLACEMENTS = 4'd3;
    localparam [3:0] PLACE_WORD = 4'd4;
    localparam [3:0] CHECK_COMPLETE = 4'd5;
    localparam [3:0] BACKTRACK = 4'd6;
    localparam [3:0] DONE_STATE = 4'd7;

    // Internal registers
    reg [3:0] state, next_state;
    reg [4:0] current_word_idx;
    reg [3:0] current_placement_idx;
    reg [7:0] current_row, current_col;
    reg [7:0] current_dir; // 0: horizontal, 1: vertical
    reg [31:0] used_words_mask;
    reg [7:0] temp_grid [0:255];
    reg [19:0] cycle_count;
    reg [19:0] max_cycles;

    // Constants
    localparam [19:0] MAX_CYCLES = 20'd1000000;
    localparam [7:0] VOID = 8'd35;
    localparam [7:0] EMPTY = 8'd46;
    localparam [7:0] NULL_CHAR = 8'd0;

    // Initialize module
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            current_word_idx <= 5'd0;
            current_placement_idx <= 4'd0;
            current_row <= 8'd0;
            current_col <= 8'd0;
            current_dir <= 1'b0;
            used_words_mask <= 32'd0;
            cycle_count <= 20'd0;
            max_cycles <= MAX_CYCLES;
            
            // Initialize result grid
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                result_grid[i] <= 8'd0;
                temp_grid[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        done = 1'b0;
        valid = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                // Copy input grid to temp grid
                integer i;
                for (i = 0; i < 256; i = i + 1) begin
                    if (i < grid_rows * grid_cols) begin
                        temp_grid[i] = grid[i];
                    end else begin
                        temp_grid[i] = NULL_CHAR;
                    end
                end
                
                // Initialize variables
                current_word_idx = 5'd0;
                current_placement_idx = 4'd0;
                used_words_mask = 32'd0;
                cycle_count = 20'd0;
                
                next_state = WORD_SELECT;
            end

            WORD_SELECT: begin
                // Find next unused word
                reg [4:0] word_idx;
                for (word_idx = 0; word_idx < num_words; word_idx = word_idx + 1) begin
                    if (!used_words_mask[word_idx]) begin
                        current_word_idx = word_idx;
                        current_placement_idx = 4'd0;
                        next_state = FIND_PLACEMENTS;
                        break;
                    end
                end
                
                // If all words used, check completion
                if (used_words_mask == (1 << num_words) - 1) begin
                    next_state = CHECK_COMPLETE;
                end
            end

            FIND_PLACEMENTS: begin
                // Find valid placements for current word
                reg [7:0] word_len = 8'd0;
                reg [7:0] word [0:15];
                
                // Extract word
                integer i;
                for (i = 0; i < 16; i = i + 1) begin
                    word[i] = words[current_word_idx * 16 + i];
                    if (word[i] != NULL_CHAR) begin
                        word_len = word_len + 8'd1;
                    end
                end
                
                // Try to find next placement
                reg found = 1'b0;
                while (!found && current_placement_idx < 16*16*2) begin
                    // Decode placement index
                    current_dir = current_placement_idx[0];
                    current_row = current_placement_idx[7:1];
                    current_col = current_placement_idx[15:8];
                    
                    // Check if placement is valid
                    reg valid_placement = 1'b1;
                    
                    if (current_dir == 1'b0) begin // Horizontal
                        if (current_col + word_len > grid_cols) begin
                            valid_placement = 1'b0;
                        end else begin
                            // Check boundaries
                            if (current_col > 0 && temp_grid[current_row * grid_cols + current_col - 1] != VOID) begin
                                valid_placement = 1'b0;
                            end
                            if (current_col + word_len < grid_cols && temp_grid[current_row * grid_cols + current_col + word_len] != VOID) begin
                                valid_placement = 1'b0;
                            end
                            
                            // Check cells
                            integer j;
                            for (j = 0; j < word_len; j = j + 1) begin
                                reg [7:0] cell = temp_grid[current_row * grid_cols + current_col + j];
                                if (cell != EMPTY && cell != word[j]) begin
                                    valid_placement = 1'b0;
                                end
                            end
                        end
                    end else begin // Vertical
                        if (current_row + word_len > grid_rows) begin
                            valid_placement = 1'b0;
                        end else begin
                            // Check boundaries
                            if (current_row > 0 && temp_grid[(current_row - 1) * grid_cols + current_col] != VOID) begin
                                valid_placement = 1'b0;
                            end
                            if (current_row + word_len < grid_rows && temp_grid[(current_row + word_len) * grid_cols + current_col] != VOID) begin
                                valid_placement = 1'b0;
                            end
                            
                            // Check cells
                            integer j;
                            for (j = 0; j < word_len; j = j + 1) begin
                                reg [7:0] cell = temp_grid[(current_row + j) * grid_cols + current_col];
                                if (cell != EMPTY && cell != word[j]) begin
                                    valid_placement = 1'b0;
                                end
                            end
                        end
                    end
                    
                    if (valid_placement) begin
                        found = 1'b1;
                        next_state = PLACE_WORD;
                    end else begin
                        current_placement_idx = current_placement_idx + 1'b1;
                    end
                end
                
                // If no placement found, backtrack
                if (!found) begin
                    next_state = BACKTRACK;
                end
            end

            PLACE_WORD: begin
                // Place word in temp grid
                reg [7:0] word_len = 8'd0;
                reg [7:0] word [0:15];
                
                // Extract word
                integer i;
                for (i = 0; i < 16; i = i + 1) begin
                    word[i] = words[current_word_idx * 16 + i];
                    if (word[i] != NULL_CHAR) begin
                        word_len = word_len + 8'd1;
                    end
                end
                
                // Place word
                if (current_dir == 1'b0) begin // Horizontal
                    for (i = 0; i < word_len; i = i + 1) begin
                        temp_grid[current_row * grid_cols + current_col + i] = word[i];
                    end
                end else begin // Vertical
                    for (i = 0; i < word_len; i = i + 1) begin
                        temp_grid[(current_row + i) * grid_cols + current_col] = word[i];
                    end
                end
                
                // Mark word as used
                used_words_mask[current_word_idx] = 1'b1;
                
                next_state = CHECK_COMPLETE;
            end

            CHECK_COMPLETE: begin
                // Check if all words placed and grid complete
                reg grid_complete = 1'b1;
                integer i;
                for (i = 0; i < grid_rows * grid_cols; i = i + 1) begin
                    if (temp_grid[i] == EMPTY) begin
                        grid_complete = 1'b0;
                    end
                end
                
                if (grid_complete) begin
                    // Copy temp grid to result grid
                    for (i = 0; i < 256; i = i + 1) begin
                        if (i < grid_rows * grid_cols) begin
                            result_grid[i] = temp_grid[i];
                        end else begin
                            result_grid[i] = NULL_CHAR;
                        end
                    end
                    
                    next_state = DONE_STATE;
                end else begin
                    next_state = WORD_SELECT;
                end
            end

            BACKTRACK: begin
                // Unmark current word
                used_words_mask[current_word_idx] = 1'b0;
                
                // Remove word from temp grid
                reg [7:0] word_len = 8'd0;
                reg [7:0] word [0:15];
                
                // Extract word
                integer i;
                for (i = 0; i < 16; i = i + 1) begin
                    word[i] = words[current_word_idx * 16 + i];
                    if (word[i] != NULL_CHAR) begin
                        word_len = word_len + 8'd1;
                    end
                end
                
                // Remove word
                if (current_dir == 1'b0) begin // Horizontal
                    for (i = 0; i < word_len; i = i + 1) begin
                        temp_grid[current_row * grid_cols + current_col + i] = EMPTY;
                    end
                end else begin // Vertical
                    for (i = 0; i < word_len; i = i + 1) begin
                        temp_grid[(current_row + i) * grid_cols + current_col] = EMPTY;
                    end
                end
                
                // Find previous word
                reg [4:0] prev_word_idx = current_word_idx - 1'b1;
                while (prev_word_idx >= 0 && !used_words_mask[prev_word_idx]) begin
                    prev_word_idx = prev_word_idx - 1'b1;
                end
                
                if (prev_word_idx >= 0) begin
                    current_word_idx = prev_word_idx;
                    next_state = FIND_PLACEMENTS;
                end else begin
                    // No solution found
                    valid = 1'b0;
                    next_state = IDLE;
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                valid = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Cycle counter to prevent infinite loops
    always @(posedge clk) begin
        if (state != IDLE && state != DONE_STATE) begin
            cycle_count = cycle_count + 1'b1;
            if (cycle_count >= max_cycles) begin
                valid = 1'b0;
                state = IDLE;
            end
        end else begin
            cycle_count = 20'd0;
        end
    end

endmodule