module crossword_solver(
    input clk,
    input rst_n,
    input start,
    input [7:0] grid [0:255],
    input [7:0] words [0:511],
    input [4:0] num_words,
    input [4:0] grid_rows,
    input [4:0] grid_cols,
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
    localparam [3:0] ERROR_STATE = 4'd8;

    // Internal registers
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Word and grid tracking
    reg [31:0] used_words_mask;
    reg [7:0] current_grid [0:255];
    reg [4:0] current_word_idx;
    reg [4:0] word_iter;
    reg [7:0] search_row;
    reg [7:0] search_col;
    reg search_dir; // 0=horizontal, 1=vertical
    reg [7:0] placement_row;
    reg [7:0] placement_col;
    reg [7:0] placement_length;
    
    // Stack for backtracking
    reg [4:0] stack_word_idx [0:31];
    reg [7:0] stack_row [0:31];
    reg [7:0] stack_col [0:31];
    reg stack_dir [0:31];
    reg [4:0] stack_depth;
    reg [31:0] stack_used_words [0:31];
    reg [7:0] stack_grid [0:31][0:255];
    
    // Control
    reg [19:0] cycle_count;
    localparam [19:0] MAX_CYCLES = 20'd1048575;
    
    // Temporary storage
    reg [7:0] temp_char;
    reg [7:0] temp_word [0:15];
    reg [3:0] word_len;
    reg valid_placement;
    reg [7:0] i, j, k, l;
    
    // Helper: get word length
    function [3:0] get_word_len;
        input [4:0] w_idx;
        input [7:0] w_data [0:511];
        reg [3:0] len;
        begin
            len = 4'd0;
            for (l = 0; l < 16; l = l + 1) begin
                if (w_data[w_idx * 16 + l] != 8'd0) begin
                    len = l + 1;
                end
            end
            get_word_len = len;
        end
    endfunction

    // Helper: check word constraints
    function check_word_boundaries;
        input [7:0] r;
        input [7:0] c;
        input [7:0] len;
        input dir;
        input [7:0] g_rows;
        input [7:0] g_cols;
        begin
            if (dir == 1'd0) begin // horizontal
                if (c + len > g_cols) begin
                    check_word_boundaries = 1'b0;
                end else if (c > 0 && current_grid[r * 16 + c - 1] != 8'd35) begin
                    check_word_boundaries = 1'b0;
                end else if (c + len < g_cols && current_grid[r * 16 + c + len] != 8'd35) begin
                    check_word_boundaries = 1'b0;
                end else begin
                    check_word_boundaries = 1'b1;
                end
            end else begin // vertical
                if (r + len > g_rows) begin
                    check_word_boundaries = 1'b0;
                end else if (r > 0 && current_grid[(r - 1) * 16 + c] != 8'd35) begin
                    check_word_boundaries = 1'b0;
                end else if (r + len < g_rows && current_grid[(r + len) * 16 + c] != 8'd35) begin
                    check_word_boundaries = 1'b0;
                end else begin
                    check_word_boundaries = 1'b1;
                end
            end
        end
    endfunction

    // Helper: check if placement fits
    function check_placement_fit;
        input [7:0] r;
        input [7:0] c;
        input [7:0] len;
        input dir;
        input [4:0] w_idx;
        begin
            reg fit;
            reg [7:0] pos;
            reg [7:0] grid_char;
            reg [7:0] word_char;
            fit = 1'b1;
            for (pos = 0; pos < len && fit; pos = pos + 1) begin
                if (dir == 1'd0) begin
                    grid_char = current_grid[r * 16 + c + pos];
                end else begin
                    grid_char = current_grid[(r + pos) * 16 + c];
                end
                word_char = words[w_idx * 16 + pos];
                if (grid_char != 8'd46 && grid_char != word_char) begin
                    fit = 1'b0;
                end
            end
            check_placement_fit = fit;
        end
    endfunction

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 20'd0;
            for (i = 0; i < 256; i = i + 1) begin
                result_grid[i] <= 8'd0;
                current_grid[i] <= 8'd0;
            end
            used_words_mask <= 32'd0;
            stack_depth <= 5'd0;
            current_word_idx <= 5'd0;
            search_row <= 8'd0;
            search_col <= 8'd0;
            search_dir <= 1'd0;
            placement_row <= 8'd0;
            placement_col <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 20'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 20'd0;
                    if (start) begin
                        if (num_words > 5'd31 || grid_rows > 5'd16 || grid_cols > 5'd16 || grid_rows == 5'd0 || grid_cols == 5'd0) begin
                            state <= ERROR_STATE;
                        end else begin
                            state <= INIT;
                        end
                    end
                end
                
                INIT: begin
                    // Copy initial grid to current
                    for (i = 0; i < 256; i = i + 1) begin
                        current_grid[i] <= grid[i];
                    end
                    used_words_mask <= 32'd0;
                    stack_depth <= 5'd0;
                    current_word_idx <= 5'd0;
                    state <= WORD_SELECT;
                end
                
                WORD_SELECT: begin
                    if (used_words_mask == ((1 << num_words) - 1)) begin
                        state <= CHECK_COMPLETE;
                    end else if (current_word_idx < num_words) begin
                        if (!used_words_mask[current_word_idx]) begin
                            state <= FIND_PLACEMENTS;
                            search_row <= 8'd0;
                            search_col <= 8'd0;
                            search_dir <= 1'd0;
                        end else begin
                            current_word_idx <= current_word_idx + 5'd1;
                        end
                    end else begin
                        state <= CHECK_COMPLETE;
                    end
                end
                
                FIND_PLACEMENTS: begin
                    // Find next valid placement for current_word_idx
                    valid_placement <= 1'b0;
                    if (search_row < grid_rows && search_col < grid_cols) begin
                        // Check horizontal
                        if (search_dir == 1'd0 && search_col <= grid_cols - 2) begin
                            word_len <= get_word_len(current_word_idx, words);
                            if (check_word_boundaries(search_row, search_col, get_word_len(current_word_idx, words), 1'd0, grid_rows, grid_cols)) begin
                                if (check_placement_fit(search_row, search_col, get_word_len(current_word_idx, words), 1'd0, current_word_idx)) begin
                                    valid_placement <= 1'b1;
                                    placement_row <= search_row;
                                    placement_col <= search_col;
                                    placement_length <= get_word_len(current_word_idx, words);
                                    state <= PLACE_WORD;
                                end else begin
                                    search_col <= search_col + 8'd1;
                                end
                            end else begin
                                search_col <= search_col + 8'd1;
                            end
                        end else if (search_dir == 1'd0 && search_col == grid_cols - 1) begin
                            search_dir <= 1'd1;
                            search_col <= 8'd0;
                        end else if (search_dir == 1'd1 && search_row <= grid_rows - 2) begin
                            word_len <= get_word_len(current_word_idx, words);
                            if (check_word_boundaries(search_row, search_col, get_word_len(current_word_idx, words), 1'd1, grid_rows, grid_cols)) begin
                                if (check_placement_fit(search_row, search_col, get_word_len(current_word_idx, words), 1'd1, current_word_idx)) begin
                                    valid_placement <= 1'b1;
                                    placement_row <= search_row;
                                    placement_col <= search_col;
                                    placement_length <= get_word_len(current_word_idx, words);
                                    state <= PLACE_WORD;
                                end else begin
                                    search_col <= search_col + 8'd1;
                                end
                            end else begin
                                search_col <= search_col + 8'd1;
                            end
                        end else if (search_dir == 1'd1 && search_col == grid_cols - 1) begin
                            search_row <= search_row + 8'd1;
                            search_col <= 8'd0;
                        end else begin
                            search_col <= search_col + 8'd1;
                        end
                    end else begin
                        // No placement found, backtrack
                        state <= BACKTRACK;
                    end
                end
                
                PLACE_WORD: begin
                    // Save state to stack
                    if (stack_depth < 5'd32) begin
                        stack_word_idx[stack_depth] <= current_word_idx;
                        stack_row[stack_depth] <= placement_row;
                        stack_col[stack_depth] <= placement_col;
                        stack_dir[stack_depth] <= search_dir;
                        stack_used_words[stack_depth] <= used_words_mask;
                        // Copy current grid to stack
                        for (k = 0; k < 256; k = k + 1) begin
                            stack_grid[stack_depth][k] <= current_grid[k];
                        end
                        stack_depth <= stack_depth + 5'd1;
                        
                        // Place the word
                        used_words_mask[current_word_idx] <= 1'b1;
                        for (l = 0; l < 16; l = l + 1) begin
                            if (l < placement_length) begin
                                if (search_dir == 1'd0) begin
                                    current_grid[placement_row * 16 + placement_col + l] <= words[current_word_idx * 16 + l];
                                end else begin
                                    current_grid[(placement_row + l) * 16 + placement_col] <= words[current_word_idx * 16 + l];
                                end
                            end
                        end
                        state <= WORD_SELECT;
                        current_word_idx <= 5'd0;
                    end else begin
                        state <= ERROR_STATE;
                    end
                end
                
                CHECK_COMPLETE: begin
                    // Check if all '.' slots are filled
                    reg all_filled;
                    all_filled = 1'b1;
                    // This needs to be done in a sequential way
                    // We'll check in multiple cycles
                    if (search_row < grid_rows) begin
                        if (current_grid[search_row * 16 + search_col] == 8'd46) begin
                            all_filled = 1'b0;
                        end
                        if (search_col < grid_cols - 1) begin
                            search_col <= search_col + 8'd1;
                        end else begin
                            search_col <= 8'd0;
                            search_row <= search_row + 8'd1;
                        end
                        if (!all_filled) begin
                            state <= BACKTRACK;
                        end else if (search_row == grid_rows && search_col == 8'd0) begin
                            state <= DONE_STATE;
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                BACKTRACK: begin
                    if (stack_depth > 5'd0) begin
                        stack_depth <= stack_depth - 5'd1;
                        current_word_idx <= stack_word_idx[stack_depth - 5'd1] + 5'd1;
                        used_words_mask <= stack_used_words[stack_depth - 5'd1];
                        // Restore grid
                        for (k = 0; k < 256; k = k + 1) begin
                            current_grid[k] <= stack_grid[stack_depth - 5'd1][k];
                        end
                        // Continue searching from next position
                        search_col <= stack_col[stack_depth - 5'd1] + 8'd1;
                        search_row <= stack_row[stack_depth - 5'd1];
                        search_dir <= stack_dir[stack_depth - 5'd1];
                        state <= FIND_PLACEMENTS;
                    end else begin
                        state <= ERROR_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    // Copy result to output
                    for (i = 0; i < 256; i = i + 1) begin
                        result_grid[i] <= current_grid[i];
                    end
                    // Stay in DONE state (or could go back to IDLE)
                    if (start) begin
                        state <= IDLE;
                    end
                end
                
                ERROR_STATE: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    if (start) begin
                        state <= IDLE;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Timeout check
            if (cycle_count >= MAX_CYCLES && state != DONE_STATE && state != ERROR_STATE) begin
                state <= ERROR_STATE;
            end
        end
    end

endmodule