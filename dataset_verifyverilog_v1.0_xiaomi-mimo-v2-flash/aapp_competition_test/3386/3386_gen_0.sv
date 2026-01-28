module HamiltonianCycleFinder(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [3:0] M,
    output reg [63:0] result_x,
    output reg [63:0] result_y,
    output reg valid,
    output reg no_solution
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] SEARCH = 3'd2;
    localparam [2:0] VALID_STATE = 3'd3;
    localparam [2:0] NO_SOLUTION_STATE = 3'd4;

    reg [2:0] state, next_state;
    
    // Control signals
    reg [5:0] cycle_count;      // Timeout counter (0-63)
    reg [5:0] depth;            // Current depth in DFS (0-63)
    reg [5:0] max_depth;        // Target: N*M
    reg [5:0] backtrack_depth;  // Depth to backtrack to
    reg search_active;
    
    // Visited array: 64 bits (1 per cell)
    reg [63:0] visited;
    
    // Path storage: 256 bits total
    // result_x[3:0] = row0, result_x[7:4] = row1, ...
    // result_y[3:0] = col0, result_y[7:4] = col1, ...
    reg [63:0] path_x;
    reg [63:0] path_y;
    
    // Current position (4-bit coordinates)
    reg [3:0] curr_row;
    reg [3:0] curr_col;
    reg [3:0] start_row;
    reg [3:0] start_col;
    
    // Move generation
    reg [2:0] move_idx;         // 0-7 for 8 possible moves
    reg [3:0] next_row;
    reg [3:0] next_col;
    reg move_valid;
    reg [1:0] manhattan_dist;
    
    // Depth counter for path indexing
    integer i;

    // Knight move offsets (8 possibilities)
    // Using signed offsets for calculation
    reg signed [3:0] dr [0:7];
    reg signed [3:0] dc [0:7];
    
    // Initialize move offsets
    initial begin
        dr[0] = 2;  dc[0] = 1;
        dr[1] = 2;  dc[1] = -1;
        dr[2] = -2; dc[2] = 1;
        dr[3] = -2; dc[3] = -1;
        dr[4] = 1;  dc[4] = 2;
        dr[5] = 1;  dc[5] = -2;
        dr[6] = -1; dc[6] = 2;
        dr[7] = -1; dc[7] = -2;
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            no_solution <= 1'b0;
            cycle_count <= 6'd0;
            depth <= 6'd0;
            max_depth <= 6'd0;
            search_active <= 1'b0;
            visited <= 64'd0;
            path_x <= 64'd0;
            path_y <= 64'd0;
            result_x <= 64'd0;
            result_y <= 64'd0;
            move_idx <= 3'd0;
            curr_row <= 4'd0;
            curr_col <= 4'd0;
            start_row <= 4'd0;
            start_col <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    no_solution <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Initialize for new search
                    cycle_count <= 6'd0;
                    depth <= 6'd0;
                    max_depth <= (N * M) - 6'd1;  // Last index to fill
                    visited <= 64'd0;
                    path_x <= 64'd0;
                    path_y <= 64'd0;
                    move_idx <= 3'd0;
                    
                    // Always start from (0,0)
                    start_row <= 4'd0;
                    start_col <= 4'd0;
                    curr_row <= 4'd0;
                    curr_col <= 4'd0;
                    
                    // Mark start as visited
                    visited[0] <= 1'b1;
                    path_x[3:0] <= 4'd0;
                    path_y[3:0] <= 4'd0;
                    
                    search_active <= 1'b1;
                    state <= SEARCH;
                end
                
                SEARCH: begin
                    cycle_count <= cycle_count + 6'd1;
                    
                    // Timeout check
                    if (cycle_count >= 6'd63) begin
                        search_active <= 1'b0;
                        state <= NO_SOLUTION_STATE;
                    end else if (search_active) begin
                        
                        // Move generation
                        if (move_idx < 3'd8) begin
                            // Calculate next position
                            next_row <= curr_row + dr[move_idx];
                            next_col <= curr_col + dc[move_idx];
                            
                            // Check bounds and move validity
                            move_valid <= 1'b0;
                            
                            // Boundary check and Manhattan distance check
                            if ((curr_row + dr[move_idx]) < N && 
                                (curr_col + dc[move_idx]) < M &&
                                (curr_row + dr[move_idx]) >= 0 &&
                                (curr_col + dc[move_idx]) >= 0) begin
                                
                                // Calculate Manhattan distance
                                manhattan_dist <= (dr[move_idx] > 0 ? dr[move_idx] : -dr[move_idx]) +
                                                 (dc[move_idx] > 0 ? dc[move_idx] : -dc[move_idx]);
                                
                                // Check if distance is 2 or 3
                                if (manhattan_dist == 2'd2 || manhattan_dist == 2'd3) begin
                                    // Check if not visited
                                    if (!visited[{curr_row + dr[move_idx], curr_col + dc[move_idx]}]) begin
                                        move_valid <= 1'b1;
                                    end
                                end
                            end
                            
                            move_idx <= move_idx + 3'd1;
                            
                        end else begin
                            // All moves tried for current position
                            move_idx <= 3'd0;
                            
                            if (move_valid) begin
                                // Take the valid move
                                curr_row <= next_row;
                                curr_col <= next_col;
                                
                                // Mark as visited and store in path
                                visited[{next_row, next_col}] <= 1'b1;
                                path_x[(depth + 1) * 4 +: 4] <= next_row;
                                path_y[(depth + 1) * 4 +: 4] <= next_col;
                                
                                depth <= depth + 6'd1;
                                
                                // Check if we've visited all cells
                                if (depth == max_depth) begin
                                    // Check cycle closure
                                    // Distance from last cell back to start (0,0)
                                    if ((next_row <= 3'd3 && next_col <= 3'd3) && 
                                        ((next_row == 3'd0 && next_col == 3'd0) ||
                                         (next_row == 3'd2 && next_col == 3'd1) ||
                                         (next_row == 3'd1 && next_col == 3'd2) ||
                                         (next_row == 3'd2 && next_col == 3'd3) ||
                                         (next_row == 3'd3 && next_col == 3'd2))) begin
                                        state <= VALID_STATE;
                                        search_active <= 1'b0;
                                        
                                        // Copy path to output
                                        result_x <= path_x;
                                        result_y <= path_y;
                                    end else begin
                                        // No valid cycle, backtrack
                                        state <= SEARCH;
                                    end
                                end else begin
                                    state <= SEARCH;
                                end
                            end else begin
                                // No valid move, backtrack
                                if (depth > 6'd0) begin
                                    // Mark current as unvisited
                                    visited[{curr_row, curr_col}] <= 1'b0;
                                    
                                    // Find previous position (backtrack)
                                    // Need to restore previous state
                                    depth <= depth - 6'd1;
                                    
                                    // Find the last valid position in path
                                    for (i = depth - 1; i >= 0; i = i - 1) begin
                                        if (i < depth) begin
                                            curr_row <= path_x[i * 4 +: 4];
                                            curr_col <= path_y[i * 4 +: 4];
                                            i = -1;  // Exit loop
                                        end
                                    end
                                    
                                    move_idx <= 3'd0;
                                    state <= SEARCH;
                                end else begin
                                    // Back at start with no solution
                                    search_active <= 1'b0;
                                    state <= NO_SOLUTION_STATE;
                                end
                            end
                        end
                    end
                end
                
                VALID_STATE: begin
                    valid <= 1'b1;
                    state <= IDLE;
                end
                
                NO_SOLUTION_STATE: begin
                    no_solution <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    valid <= 1'b0;
                    no_solution <= 1'b0;
                end
            endcase
        end
    end

endmodule