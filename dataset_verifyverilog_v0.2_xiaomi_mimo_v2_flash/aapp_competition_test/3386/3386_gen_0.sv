module tour_finder(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [3:0] M,
    output reg [5:0] tour_addr,
    output reg [7:0] tour_row,
    output reg [7:0] tour_col,
    output reg tour_write,
    output reg done,
    output reg found
);

    // Parameters for states
    parameter IDLE = 3'b000;
    parameter INIT = 3'b001;
    parameter SEARCH = 3'b010;
    parameter CHECK_CYCLE = 3'b011;
    parameter OUTPUT = 3'b100;
    parameter DONE = 3'b101;
    parameter NO_SOLUTION = 3'b110;

    // State registers
    reg [2:0] state;
    reg [2:0] next_state;

    // Grid dimensions
    reg [3:0] grid_N;
    reg [3:0] grid_M;
    reg [5:0] total_cells;

    // DFS stack - stores path
    // We can store up to 64 cells
    reg [5:0] stack_path [0:63]; // cell index
    reg [5:0] stack_ptr;

    // Visited array - 64 bits
    reg [63:0] visited;

    // Current node being processed
    reg [5:0] current_node;
    reg [5:0] next_node;

    // Neighbor generation counter
    reg [3:0] neighbor_iter;
    reg [2:0] search_state; // internal state for SEARCH

    // Output buffer for tour
    reg [5:0] tour_buffer [0:63];
    reg [5:0] output_idx;
    reg [5:0] max_depth;

    // Helper: check if distance is 2 or 3
    function valid_distance;
        input [7:0] r1, c1, r2, c2;
        integer dr, dc, dist;
        begin
            dr = (r1 > r2) ? (r1 - r2) : (r2 - r1);
            dc = (c1 > c2) ? (c1 - c2) : (c2 - c1);
            dist = dr + dc;
            valid_distance = (dist == 2 || dist == 3);
        end
    endfunction

    // Helper: get row from index
    function [7:0] get_row;
        input [5:0] idx;
        begin
            get_row = idx / grid_M;
        end
    endfunction

    // Helper: get col from index
    function [7:0] get_col;
        input [5:0] idx;
        begin
            get_col = idx % grid_M;
        end
    endfunction

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            found <= 0;
            tour_write <= 0;
            stack_ptr <= 0;
            visited <= 0;
            neighbor_iter <= 0;
            search_state <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                    end
                    done <= 0;
                    found <= 0;
                    tour_write <= 0;
                end

                INIT: begin
                    grid_N <= N;
                    grid_M <= M;
                    total_cells <= N * M;
                    // Start at cell 0
                    stack_path[0] <= 0;
                    stack_ptr <= 1;
                    visited <= 64'h1; // Mark cell 0 visited (bit 0)
                    search_state <= 0;
                    state <= SEARCH;
                end

                SEARCH: begin
                    case (search_state)
                        0: begin // Setup for checking unvisited neighbors
                            if (stack_ptr == total_cells) begin
                                // All cells visited, check cycle
                                state <= CHECK_CYCLE;
                                search_state <= 0;
                            end else begin
                                current_node <= stack_path[stack_ptr - 1];
                                neighbor_iter <= 0;
                                search_state <= 1;
                            end
                        end

                        1: begin // Iterate neighbors
                            if (neighbor_iter < 16) begin // Check all 16 possible neighbors in 8x8 range
                                // Calculate neighbor coordinates
                                // Try offsets (-3 to +3)
                                // We will use a simple counter to generate offsets
                                // This is a simplified neighbor generation for efficiency
                                // We'll generate a specific set of offsets for distance 2 and 3
                                
                                // To keep it synthesizable and within logic limits, we use a hardcoded lookup
                                // 0: (+0,+2), 1: (+0,-2), 2: (+2,+0), 3: (-2,+0), 4: (+1,+1), 5: (+1,-1), 6: (-1,+1), 7: (-1,-1)
                                // 8: (+1,+2), 9: (+1,-2), 10: (+2,+1), 11: (+2,-1), 12: (-1,+2), 13: (-1,-2), 14: (-2,+1), 15: (-2,-1)
                                // 16: (+3,+0), 17: (-3,+0), 18: (+0,+3), 19: (+0,-3), 20: (+2,+2), 21: (+2,-2), 22: (-2,+2), 23: (-2,-2)
                                // 24: (+1,+3), 25: (+1,-3), 26: (+3,+1), 27: (+3,-1), 28: (-1,+3), 29: (-1,-3), 30: (+3,-1), 31: (-3,+1)
                                
                                // Let's implement a smarter iteration. 
                                // We can simply iterate through ALL cells in the grid and check distance.
                                // Since grid is max 64, this is 64 checks per node. Total search is bounded.
                                // Actually, let's iterate next_node candidate from 0 to total_cells-1
                                
                                if (next_node < total_cells) begin
                                    if (!visited[next_node]) begin
                                        // Check distance validity
                                        if (valid_distance(get_row(current_node), get_col(current_node), 
                                                           get_row(next_node), get_col(next_node))) begin
                                            // Push to stack
                                            stack_path[stack_ptr] <= next_node;
                                            stack_ptr <= stack_ptr + 1;
                                            visited[next_node] <= 1'b1;
                                            search_state <= 0; // Go back to check top of stack
                                            next_node <= 0; // Reset for next level
                                        end else begin
                                            next_node <= next_node + 1;
                                        end
                                    end else begin
                                        next_node <= next_node + 1;
                                    end
                                end else begin
                                    // No valid neighbor found, backtrack
                                    if (stack_ptr > 0) begin
                                        stack_ptr <= stack_ptr - 1;
                                        visited[stack_path[stack_ptr - 1]] <= 1'b0;
                                        next_node <= stack_path[stack_ptr - 1] + 1; // Start search after previous node
                                        search_state <= 0;
                                    end else begin
                                        // Stack empty, no solution
                                        state <= NO_SOLUTION;
                                    end
                                end
                            end else begin
                                // All neighbors tried, backtrack
                                if (stack_ptr > 0) begin
                                    stack_ptr <= stack_ptr - 1;
                                    visited[stack_path[stack_ptr - 1]] <= 1'b0;
                                    next_node <= stack_path[stack_ptr - 1] + 1;
                                    search_state <= 0;
                                end else begin
                                    state <= NO_SOLUTION;
                                end
                            end
                        end
                    endcase
                end

                CHECK_CYCLE: begin
                    // Check if last node connects to first node (0)
                    if (stack_ptr == total_cells) begin
                        if (valid_distance(get_row(stack_path[total_cells-1]), get_col(stack_path[total_cells-1]), 0, 0)) begin
                            found <= 1;
                            output_idx <= 0;
                            state <= OUTPUT;
                        end else begin
                            // Cycle invalid, backtrack
                            if (stack_ptr > 0) begin
                                stack_ptr <= stack_ptr - 1;
                                visited[stack_path[stack_ptr - 1]] <= 1'b0;
                                next_node <= stack_path[stack_ptr - 1] + 1;
                                search_state <= 0;
                                state <= SEARCH;
                            end else begin
                                state <= NO_SOLUTION;
                            end
                        end
                    end else begin
                        state <= NO_SOLUTION;
                    end
                end

                OUTPUT: begin
                    if (output_idx < total_cells) begin
                        tour_addr <= output_idx;
                        tour_row <= get_row(stack_path[output_idx]);
                        tour_col <= get_col(stack_path[output_idx]);
                        tour_write <= 1;
                        output_idx <= output_idx + 1;
                    end else begin
                        tour_write <= 0;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1;
                    // Wait for reset or new start handled in IDLE transition
                end

                NO_SOLUTION: begin
                    found <= 0;
                    state <= DONE;
                end
            endcase
        end
    end

    // Logic to increment next_node for SEARCH state 1 initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_node <= 0;
        end else if (state == SEARCH && search_state == 0 && stack_ptr < total_cells && stack_ptr > 0) begin
            // When transitioning from check top to search neighbors, we use the previously found node index + 1
            // But here we just start from 0 because we need to find the first valid neighbor from the CURRENT node
            next_node <= 0;
        end
    end

endmodule
