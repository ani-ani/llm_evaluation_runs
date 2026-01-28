module hexagon_coloring(
    input clk,
    input rst_n,
    input start,
    input [68:0] grid_valid,
    input [68:0][2:0] grid_constraint,
    output reg [16:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] DFS = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Grid parameters
    localparam [6:0] GRID_SIZE = 7'd49; // 7x7 grid
    localparam [6:0] MAX_EDGES = 7'd120; // Upper bound for edges

    // State registers
    reg [2:0] state, next_state;
    reg [16:0] count;
    reg [68:0] visited;
    reg [119:0] edge_used;
    reg [6:0] current_cell;
    reg [6:0] stack_ptr;
    reg [6:0] stack [0:99]; // Stack for DFS
    reg [6:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Edge direction encoding (6 neighbors per cell)
    localparam [2:0] NORTH = 3'd0;
    localparam [2:0] NORTHEAST = 3'd1;
    localparam [2:0] SOUTHEAST = 3'd2;
    localparam [2:0] SOUTH = 3'd3;
    localparam [2:0] SOUTHWEST = 3'd4;
    localparam [2:0] NORTHWEST = 3'd5;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 17'd0;
            visited <= 69'd0;
            edge_used <= 120'd0;
            current_cell <= 7'd0;
            stack_ptr <= 7'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result <= 17'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                next_state = DFS;
            end

            DFS: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else if (stack_ptr == 0 && current_cell == GRID_SIZE) begin
                    next_state = CHECK;
                end
            end

            CHECK: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // DFS logic
    always @(posedge clk) begin
        if (state == DFS) begin
            cycle_count <= cycle_count + 8'd1;
            
            // Check if current cell is valid and not visited
            if (!visited[current_cell] && grid_valid[current_cell]) begin
                // Try all 6 directions
                for (integer i = 0; i < 6; i = i + 1) begin
                    reg [6:0] neighbor;
                    reg [6:0] edge_idx;
                    
                    // Calculate neighbor position
                    case (i)
                        NORTH: begin
                            if (current_cell >= 7) begin
                                neighbor = current_cell - 7'd7;
                                edge_idx = current_cell * 7'd6 + 7'd0;
                            end else begin
                                neighbor = 7'd0;
                            end
                        end
                        NORTHEAST: begin
                            if ((current_cell % 7'd7) < 6 && current_cell >= 7) begin
                                neighbor = current_cell - 7'd6;
                                edge_idx = current_cell * 7'd6 + 7'd1;
                            end else begin
                                neighbor = 7'd0;
                            end
                        end
                        SOUTHEAST: begin
                            if ((current_cell % 7'd7) < 6) begin
                                neighbor = current_cell + 7'd8;
                                edge_idx = current_cell * 7'd6 + 7'd2;
                            end else begin
                                neighbor = 7'd0;
                            end
                        end
                        SOUTH: begin
                            if (current_cell < 42) begin
                                neighbor = current_cell + 7'd7;
                                edge_idx = current_cell * 7'd6 + 7'd3;
                            end else begin
                                neighbor = 7'd0;
                            end
                        end
                        SOUTHWEST: begin
                            if ((current_cell % 7'd7) > 0) begin
                                neighbor = current_cell + 7'd6;
                                edge_idx = current_cell * 7'd6 + 7'd4;
                            end else begin
                                neighbor = 7'd0;
                            end
                        end
                        NORTHWEST: begin
                            if ((current_cell % 7'd7) > 0 && current_cell >= 7) begin
                                neighbor = current_cell - 7'd8;
                                edge_idx = current_cell * 7'd6 + 7'd5;
                            end else begin
                                neighbor = 7'd0;
                            end
                        end
                        default: begin
                            neighbor = 7'd0;
                            edge_idx = 7'd0;
                        end
                    endcase
                    
                    // Check if edge is available and neighbor is valid
                    if (neighbor != 0 && !edge_used[edge_idx] && grid_valid[neighbor]) begin
                        // Push current state to stack
                        stack[stack_ptr] = current_cell;
                        stack_ptr = stack_ptr + 7'd1;
                        
                        // Mark edge as used
                        edge_used[edge_idx] = 1'b1;
                        
                        // Move to neighbor
                        current_cell = neighbor;
                        visited[current_cell] = 1'b1;
                        
                        // Exit for loop (simulate break)
                        i = 6;
                    end
                end
                
                // If no valid moves, backtrack
                if (stack_ptr > 0) begin
                    stack_ptr = stack_ptr - 7'd1;
                    current_cell = stack[stack_ptr];
                end else begin
                    current_cell = current_cell + 7'd1;
                end
            end else begin
                current_cell = current_cell + 7'd1;
            end
        end
    end

    // Check constraints and count valid colorings
    always @(posedge clk) begin
        if (state == CHECK) begin
            reg [16:0] temp_count = 17'd0;
            reg [6:0] cell;
            
            // Check all cells
            for (cell = 0; cell < GRID_SIZE; cell = cell + 1) begin
                if (grid_valid[cell]) begin
                    reg [2:0] edge_count = 3'd0;
                    
                    // Count used edges for this cell
                    for (integer i = 0; i < 6; i = i + 1) begin
                        reg [6:0] edge_idx = cell * 7'd6 + i;
                        if (edge_used[edge_idx]) begin
                            edge_count = edge_count + 3'd1;
                        end
                    end
                    
                    // Check constraint
                    if (edge_count != grid_constraint[cell]) begin
                        temp_count = 17'd0;
                        cell = GRID_SIZE; // Exit loop
                    end
                end
            end
            
            // If all constraints satisfied, increment count
            if (temp_count != 0) begin
                count = count + 17'd1;
            end
            
            // Reset for next iteration
            visited = 69'd0;
            edge_used = 120'd0;
            current_cell = 7'd0;
            stack_ptr = 7'd0;
            
            next_state = DFS;
        end
    end

    // Output result when done
    always @(posedge clk) begin
        if (state == FINISH) begin
            result = count;
            done = 1'b1;
        end else begin
            done = 1'b0;
        end
    end

endmodule