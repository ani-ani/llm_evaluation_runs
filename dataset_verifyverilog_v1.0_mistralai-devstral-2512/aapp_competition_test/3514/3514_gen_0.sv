module BuildingDisarm(
    input clk,
    input rst_n,
    input start,
    input grid_valid,
    input [2:0] grid_row,
    input [2:0] grid_col,
    input is_bomb,
    output reg [3:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_GRID = 3'd1;
    localparam [2:0] COMPUTE_MATCHING = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Grid storage (8x8)
    reg [7:0] grid [0:7];
    reg [2:0] write_row;
    reg [2:0] write_col;
    reg [7:0] row_count;
    reg [7:0] col_count;
    
    // Bipartite matching variables
    reg [2:0] match_right [0:7]; // match_right[j] = row matched to column j
    reg [7:0] seen [0:7]; // seen array for DFS
    reg [2:0] current_row;
    reg [2:0] current_col;
    reg [7:0] match_count;
    reg found_augmenting;
    
    // Control signals
    reg grid_loaded;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            busy <= 1'b0;
            result <= 4'd0;
            grid_loaded <= 1'b0;
            cycle_counter <= 8'd0;
            
            // Initialize grid
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                grid[i] <= 8'd0;
            end
            
            // Initialize matching arrays
            for (j = 0; j < 8; j = j + 1) begin
                match_right[j] <= 3'd0;
            end
            
            write_row <= 3'd0;
            write_col <= 3'd0;
            row_count <= 8'd0;
            col_count <= 8'd0;
            current_row <= 3'd0;
            current_col <= 3'd0;
            match_count <= 8'd0;
            found_augmenting <= 1'b0;
            
            // Initialize seen array
            for (j = 0; j < 8; j = j + 1) begin
                seen[j] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    grid_loaded <= 1'b0;
                    cycle_counter <= 8'd0;
                    
                    if (start) begin
                        next_state <= LOAD_GRID;
                        busy <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD_GRID: begin
                    if (grid_valid) begin
                        // Store bomb information in grid
                        grid[grid_row][grid_col] <= is_bomb;
                        
                        // Track grid dimensions
                        if (grid_row > row_count) begin
                            row_count <= grid_row;
                        end
                        if (grid_col > col_count) begin
                            col_count <= grid_col;
                        end
                    end
                    
                    // Check if we've received all grid data
                    // For simplicity, assume we get all 8x8 data
                    // In real implementation, might need a counter
                    if (grid_valid && grid_row == 3'd7 && grid_col == 3'd7) begin
                        grid_loaded <= 1'b1;
                        next_state <= COMPUTE_MATCHING;
                        
                        // Initialize matching arrays
                        integer j;
                        for (j = 0; j < 8; j = j + 1) begin
                            match_right[j] <= 3'd0;
                        end
                        
                        current_row <= 3'd0;
                        match_count <= 8'd0;
                        cycle_counter <= 8'd0;
                    end else begin
                        next_state <= LOAD_GRID;
                    end
                end
                
                COMPUTE_MATCHING: begin
                    busy <= 1'b1;
                    done <= 1'b0;
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // DFS-based matching algorithm
                    if (current_row <= row_count) begin
                        // Try to find augmenting path for current_row
                        integer j;
                        for (j = 0; j < 8; j = j + 1) begin
                            seen[j] <= 8'd0;
                        end
                        
                        found_augmenting <= 1'b0;
                        current_col <= 3'd0;
                        
                        // Start DFS from current_row
                        next_state <= COMPUTE_MATCHING;
                        
                        // Check if we can find an augmenting path
                        // This is simplified - in real implementation would need
                        // a separate DFS state machine
                        if (bipartite_dfs(current_row)) begin
                            match_count <= match_count + 8'd1;
                        end
                        
                        current_row <= current_row + 3'd1;
                        
                        // Check if we've processed all rows
                        if (current_row > row_count) begin
                            next_state <= DONE_STATE;
                            result <= match_count[3:0];
                        end
                    end else begin
                        next_state <= DONE_STATE;
                        result <= match_count[3:0];
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_counter >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                        result <= match_count[3:0];
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // DFS function for bipartite matching
    // Returns 1 if augmenting path found
    function bipartite_dfs;
        input [2:0] u;
        reg [2:0] v;
        
        for (v = 3'd0; v <= col_count; v = v + 3'd1) begin
            // Check if there's an edge (u,v) and v is not visited
            if (!grid[u][v] && !seen[v]) begin
                seen[v] = 1'b1;
                
                // If column v is not matched, or if the row matched to v
                // can be rematched, then we can use this edge
                if (match_right[v] == 3'd0 || bipartite_dfs(match_right[v])) begin
                    match_right[v] = u;
                    bipartite_dfs = 1'b1;
                    return;
                end
            end
        end
        
        bipartite_dfs = 1'b0;
    endfunction

endmodule