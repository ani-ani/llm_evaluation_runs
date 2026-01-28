module hexagon_coloring(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [68:0] grid_valid,
    input wire [206:0] grid_constraint,
    output reg [16:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CHECK_VALID = 3'd2;
    localparam [2:0] PROCESS_CELL = 3'd3;
    localparam [2:0] BACKTRACK = 3'd4;
    localparam [2:0] FINISHED = 3'd5;
    
    // Constants
    localparam [5:0] NUM_CELLS = 6'd69;
    localparam [6:0] MAX_EDGES = 7'd100;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [6:0] cell_idx;
    reg [6:0] edge_idx;
    reg [6:0] stack_idx;
    reg [6:0] max_stack_depth;
    reg [16:0] count;
    reg [6:0] cycle_counter;
    
    // Stack for DFS: stores cell_idx and parent_edge_idx
    reg [6:0] stack_cell [0:99];
    reg [6:0] stack_parent [0:99];
    
    // Edge connectivity (each cell has 6 possible edges)
    // Pre-computed connectivity: for cell i, edge_indices
    reg [6:0] edge_map [0:68][0:5];  // 69 cells, 6 edges each
    
    // Visited mask (69 bits)
    reg [68:0] visited;
    
    // Edge used mask (120 bits max)
    reg [119:0] edge_used;
    
    // Cell constraint array
    reg [2:0] constraint_val [0:68];
    
    // Temporary variables
    reg [5:0] edge_count;
    reg [5:0] i;
    reg constraint_match;
    reg found_path;
    reg [6:0] next_cell;
    reg [6:0] next_edge;
    
    // Helper: Get constraint for cell
    function automatic [2:0] get_constraint(input [6:0] idx);
        get_constraint = grid_constraint[idx*3 +: 3];
    endfunction
    
    // Initialize edge map (hardcoded connectivity for hex grid)
    task init_edge_map;
        integer c, e;
        begin
            // For simplicity, we'll compute edges on-the-fly
            // This is a placeholder - actual map would be extensive
            for (c = 0; c < 69; c = c + 1) begin
                for (e = 0; e < 6; e = e + 1) begin
                    edge_map[c][e] = c * 6 + e;  // Simple linear mapping
                end
            end
        end
    endtask
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 17'd0;
            done <= 1'b0;
            cell_idx <= 7'd0;
            edge_idx <= 7'd0;
            stack_idx <= 7'd0;
            max_stack_depth <= 7'd0;
            count <= 17'd0;
            cycle_counter <= 7'd0;
            visited <= 69'd0;
            edge_used <= 120'd0;
            // Initialize stack
            for (i = 0; i < 100; i = i + 1) begin
                stack_cell[i] <= 7'd0;
                stack_parent[i] <= 7'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 7'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    init_edge_map;
                    visited <= 69'd0;
                    edge_used <= 120'd0;
                    stack_idx <= 7'd0;
                    count <= 17'd0;
                    cell_idx <= 7'd0;
                    state <= CHECK_VALID;
                end
                
                CHECK_VALID: begin
                    // Find next valid unvisited cell
                    found_path <= 1'b0;
                    for (i = 0; i < 69; i = i + 1) begin
                        if (grid_valid[i] && !visited[i]) begin
                            cell_idx <= i;
                            found_path <= 1'b1;
                            i = 69;  // break equivalent
                        end
                    end
                    
                    if (found_path) begin
                        // Push to stack
                        stack_cell[stack_idx] <= cell_idx;
                        stack_parent[stack_idx] <= 7'd63;  // No parent (63 = sentinel)
                        stack_idx <= stack_idx + 7'd1;
                        visited[cell_idx] <= 1'b1;
                        state <= PROCESS_CELL;
                        cycle_counter <= 7'd0;
                    end else begin
                        // All cells processed
                        state <= FINISHED;
                    end
                end
                
                PROCESS_CELL: begin
                    cycle_counter <= cycle_counter + 7'd1;
                    
                    // Check constraint for current cell
                    if (grid_valid[cell_idx]) begin
                        edge_count <= 6'd0;
                        // Count used edges for this cell
                        for (i = 0; i < 6; i = i + 1) begin
                            if (edge_used[edge_map[cell_idx][i]]) begin
                                edge_count <= edge_count + 6'd1;
                            end
                        end
                    end
                    
                    // Look for next unvisited neighbor
                    found_path <= 1'b0;
                    next_cell <= 7'd0;
                    next_edge <= 7'd0;
                    
                    // Simple neighbor search (simplified for hex grid)
                    for (i = 0; i < 6; i = i + 1) begin
                        if (!found_path) begin
                            next_edge <= edge_map[cell_idx][i];
                            if (!edge_used[next_edge]) begin
                                // Try to find neighbor through this edge
                                // Simplified: assume cell_idx+1 is neighbor
                                next_cell <= cell_idx + 7'd1;
                                if (grid_valid[next_cell] && !visited[next_cell] && next_cell < 69) begin
                                    found_path <= 1'b1;
                                end
                            end
                        end
                    end
                    
                    if (found_path) begin
                        // Push neighbor to stack
                        stack_cell[stack_idx] <= next_cell;
                        stack_parent[stack_idx] <= cell_idx;
                        stack_idx <= stack_idx + 7'd1;
                        visited[next_cell] <= 1'b1;
                        edge_used[next_edge] <= 1'b1;
                        cell_idx <= next_cell;
                        cycle_counter <= 7'd0;
                    end else begin
                        // No more neighbors, check constraint
                        constraint_match = 1'b1;
                        if (grid_valid[cell_idx]) begin
                            if (get_constraint(cell_idx) != 3'd7 && get_constraint(cell_idx) != edge_count) begin
                                constraint_match = 1'b0;
                            end
                        end
                        
                        if (constraint_match && stack_idx > 0) begin
                            // Valid path so far
                            if (stack_idx > max_stack_depth) begin
                                max_stack_depth <= stack_idx;
                            end
                        end
                        
                        state <= BACKTRACK;
                    end
                    
                    // Timeout prevention
                    if (cycle_counter > MAX_EDGES) begin
                        state <= BACKTRACK;
                    end
                end
                
                BACKTRACK: begin
                    // Pop from stack
                    if (stack_idx > 0) begin
                        stack_idx <= stack_idx - 7'd1;
                        // Unvisit current cell
                        visited[cell_idx] <= 1'b0;
                        // Find parent edge and unuse it
                        for (i = 0; i < 6; i = i + 1) begin
                            if (edge_map[cell_idx][i] == edge_map[stack_cell[stack_idx-1]][i]) begin
                                edge_used[edge_map[cell_idx][i]] <= 1'b0;
                            end
                        end
                        cell_idx <= stack_cell[stack_idx - 7'd1];
                        state <= PROCESS_CELL;
                        cycle_counter <= 7'd0;
                    end else begin
                        // No more backtracking, check if complete
                        if (max_stack_depth > 2) begin  // Valid loop needs >2 cells
                            count <= count + 17'd1;
                        end
                        state <= CHECK_VALID;
                    end
                end
                
                FINISHED: begin
                    result <= count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule