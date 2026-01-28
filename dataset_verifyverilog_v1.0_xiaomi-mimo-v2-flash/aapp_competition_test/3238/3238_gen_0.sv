module FoldDetector (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input pixel_in,
    input pixel_valid,
    output reg [4:0] r1,
    output reg [4:0] c1,
    output reg [4:0] r2,
    output reg [4:0] c2,
    output reg done
);

    // Constants
    localparam [4:0] MAX_DIM = 5'd25;
    localparam [4:0] MAX_CYCLE = 5'd20;
    localparam [4:0] TOTAL_PIXELS = 5'd625;
    
    // Memory: 25x25 bit array (0-based indices)
    reg [24:0] sram [24:0];  // Each row is 25 bits packed
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT = 3'd1;
    localparam [2:0] FIND_FOLD = 3'd2;
    localparam [2:0] OUTPUT_STATE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Input counters
    reg [4:0] input_row, input_col;
    reg [4:0] pixel_count;
    
    // Search state
    reg [1:0] fold_type;  // 0=horiz, 1=vert, 2=diag45, 3=diag135
    reg [4:0] pos;        // position for each fold type
    reg [4:0] search_row, search_col;  // Pixel iteration counters
    
    // Best candidate storage
    reg [4:0] best_r1, best_c1, best_r2, best_c2;
    reg candidate_found;
    reg candidate_match;
    
    // Intermediate signals for checking
    wire [4:0] check_r;
    wire [4:0] check_c;
    wire [4:0] mapped_r;
    wire [4:0] mapped_c;
    wire check_result;
    wire is_edge_pixel;
    wire [4:0] fold_r, fold_c;
    
    // Helper signals for boundary checks
    reg in_bounds;
    reg out_of_bounds;
    
    // Cycle counter to prevent infinite loops
    reg [12:0] cycle_count;  // Max 8192 cycles
    localparam [12:0] MAX_TOTAL_CYCLES = 13'd10000;
    
    // Compute current pixel coordinates for checking
    assign check_r = search_row;
    assign check_c = search_col;
    
    // Helper: Check if pixel is on fold line (for diagonals)
    assign is_edge_pixel = (fold_type == 2'd2 || fold_type == 2'd3) && 
                           (check_r == fold_r || check_c == fold_c);
    
    // Compute mapped coordinates based on fold type
    always @(*) begin
        mapped_r = check_r;
        mapped_c = check_c;
        out_of_bounds = 1'b0;
        
        case (fold_type)
            2'd0: begin  // Horizontal
                mapped_r = (pos * 2) + 1 - check_r;  // Reflect across row pos
                if (check_r == pos || check_r == pos + 1) begin
                    // On fold line - maps to itself, always valid
                    mapped_r = check_r;
                    out_of_bounds = 1'b0;
                end else if (mapped_r >= n || mapped_r >= MAX_DIM) begin
                    out_of_bounds = 1'b1;
                end
            end
            2'd1: begin  // Vertical
                mapped_c = (pos * 2) + 1 - check_c;  // Reflect across col pos
                if (check_c == pos || check_c == pos + 1) begin
                    // On fold line - maps to itself, always valid
                    mapped_c = check_c;
                    out_of_bounds = 1'b0;
                end else if (mapped_c >= m || mapped_c >= MAX_DIM) begin
                    out_of_bounds = 1'b1;
                end
            end
            2'd2: begin  // Diagonal 45° (top-left to bottom-right)
                mapped_r = pos - (check_c - check_r);
                mapped_c = pos + (check_c - check_r);
                if (mapped_r >= n || mapped_c >= m || mapped_r >= MAX_DIM || mapped_c >= MAX_DIM) begin
                    out_of_bounds = 1'b1;
                end
            end
            2'd3: begin  // Diagonal 135° (top-right to bottom-left)
                mapped_r = pos - (check_c + check_r);
                mapped_c = check_c - (check_r - pos);
                if (mapped_r >= n || mapped_c >= m || mapped_r >= MAX_DIM || mapped_c >= MAX_DIM) begin
                    out_of_bounds = 1'b1;
                end
            end
        endcase
    end
    
    // Get fold line coordinates for output (edge points)
    always @(*) begin
        fold_r = 5'd0;
        fold_c = 5'd0;
        case (fold_type)
            2'd0: begin  // Horizontal: (r,1) (r,m)
                fold_r = pos;
                fold_c = 5'd0;
            end
            2'd1: begin  // Vertical: (1,c) (n,c)
                fold_r = 5'd0;
                fold_c = pos;
            end
            2'd2, 2'd3: begin  // Diagonal: find edge intersection
                // For simplicity, use bounding box approach
                if (fold_type == 2'd2) begin  // 45°: row = col - pos, col = row + pos
                    // Find first and last valid cell on diagonal
                    if (pos >= n || pos >= m) begin
                        fold_r = pos - n + 1;
                        fold_c = 0;
                    end else begin
                        fold_r = pos;
                        fold_c = pos;
                    end
                end else begin  // 135°: row = pos - col, col = pos - row
                    if (pos >= n + m - 1) begin
                        fold_r = pos - (m - 1);
                        fold_c = m - 1;
                    end else begin
                        fold_r = pos;
                        fold_c = pos;
                    end
                end
            end
        endcase
    end
    
    // Check if current pixel satisfies fold condition
    assign check_result = check_match(check_r, check_c, mapped_r, mapped_c, out_of_bounds);
    
    function automatic check_match;
        input [4:0] r, c, mr, mc;
        input oob;
        reg pixel_val, mapped_val;
        begin
            if (oob) begin
                // Out of bounds: original must be '#' (1)
                pixel_val = sram[r][c];
                check_match = pixel_val;
            end else begin
                // In bounds: check if match or original is '#'
                pixel_val = sram[r][c];
                mapped_val = sram[mr][mc];
                // Condition: pixel_val must be 1 OR both are equal
                check_match = pixel_val || (pixel_val == mapped_val);
            end
        end
    endfunction
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            r1 <= 5'd0;
            c1 <= 5'd0;
            r2 <= 5'd0;
            c2 <= 5'd0;
            done <= 1'b0;
            input_row <= 5'd0;
            input_col <= 5'd0;
            pixel_count <= 5'd0;
            fold_type <= 2'd0;
            pos <= 5'd0;
            search_row <= 5'd0;
            search_col <= 5'd0;
            best_r1 <= 5'd0;
            best_c1 <= 5'd0;
            best_r2 <= 5'd0;
            best_c2 <= 5'd0;
            candidate_found <= 1'b0;
            candidate_match <= 1'b0;
            cycle_count <= 13'd0;
            // Clear memory
            integer i;
            for (i = 0; i < 25; i = i + 1) begin
                sram[i] <= 25'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 13'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 13'd0;
                    if (start) begin
                        input_row <= 5'd0;
                        input_col <= 5'd0;
                        pixel_count <= 5'd0;
                    end
                end
                
                INPUT: begin
                    if (pixel_valid && pixel_count < n * m) begin
                        // Store pixel
                        if (pixel_in) begin
                            sram[input_row][input_col] <= 1'b1;
                        end else begin
                            sram[input_row][input_col] <= 1'b0;
                        end
                        
                        // Increment counters
                        pixel_count <= pixel_count + 5'd1;
                        input_col <= input_col + 5'd1;
                        if (input_col >= m - 1) begin
                            input_col <= 5'd0;
                            input_row <= input_row + 5'd1;
                        end
                    end
                end
                
                FIND_FOLD: begin
                    // Check current candidate, then increment counters
                    if (candidate_match) begin
                        // Check if better (lexicographically smaller)
                        if (!candidate_found || 
                            (fold_type < 2'd2 && (best_r1 > fold_r || (best_r1 == fold_r && best_c1 > pos)))) begin
                            best_r1 <= fold_r;
                            best_c1 <= pos;
                            best_r2 <= fold_r;
                            best_c2 <= (fold_type == 2'd0) ? m : pos;
                            candidate_found <= 1'b1;
                        end
                    end
                    
                    // Increment pixel counter for current candidate
                    search_col <= search_col + 5'd1;
                    if (search_col >= m - 1) begin
                        search_col <= 5'd0;
                        search_row <= search_row + 5'd1;
                        if (search_row >= n - 1) begin
                            search_row <= 5'd0;
                            search_col <= 5'd0;
                            // Move to next candidate
                            pos <= pos + 5'd1;
                            // Check if pos is valid for this fold type
                            case (fold_type)
                                2'd0: begin  // Horizontal: pos can be 0 to n-2
                                    if (pos >= n - 1) begin
                                        pos <= 5'd0;
                                        fold_type <= fold_type + 2'd1;
                                    end
                                end
                                2'd1: begin  // Vertical: pos can be 0 to m-2
                                    if (pos >= m - 1) begin
                                        pos <= 5'd0;
                                        fold_type <= fold_type + 2'd1;
                                    end
                                end
                                2'd2, 2'd3: begin  // Diagonal: pos can be 0 to n+m-3
                                    if (pos >= n + m - 2) begin
                                        pos <= 5'd0;
                                        if (fold_type == 2'd3) begin
                                            // Done with all searches
                                        end else begin
                                            fold_type <= fold_type + 2'd1;
                                        end
                                    end
                                end
                            endcase
                            // Reset match flag for new candidate
                            candidate_match <= 1'b1;
                        end
                    end
                    // Check if current pixel matches
                    if (!check_result) begin
                        candidate_match <= 1'b0;
                    end
                end
                
                OUTPUT_STATE: begin
                    r1 <= best_r1 + 5'd1;  // Convert to 1-based
                    c1 <= best_c1 + 5'd1;
                    r2 <= best_r2 + 5'd1;
                    c2 <= best_c2 + 5'd1;
                    done <= 1'b1;
                end
                
                DONE_STATE: begin
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INPUT;
                end
            end
            INPUT: begin
                if (pixel_count >= n * m && !pixel_valid) begin
                    next_state = FIND_FOLD;
                end
            end
            FIND_FOLD: begin
                // Check if all searches complete
                if (fold_type == 2'd3 && pos >= n + m - 2) begin
                    next_state = OUTPUT_STATE;
                end
                // Timeout safety
                if (cycle_count >= MAX_TOTAL_CYCLES) begin
                    next_state = OUTPUT_STATE;
                end
            end
            OUTPUT_STATE: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

endmodule