module tour_finder (
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

    // Parameters
    localparam MAX_SIZE = 64;
    localparam MAX_DEPTH = 64;
    localparam STATE_IDLE = 4'b0001;
    localparam STATE_INIT = 4'b0010;
    localparam STATE_SEARCH = 4'b0100;
    localparam STATE_CHECK_CYCLE = 4'b1000;
    localparam STATE_OUTPUT = 4'b0101;
    localparam STATE_DONE = 4'b0110;
    localparam STATE_NO_SOLUTION = 4'b1001;

    // State registers
    reg [3:0] state = STATE_IDLE;
    reg [5:0] stack_ptr = 0;
    reg [5:0] current_depth = 0;
    reg [5:0] current_index = 0;
    reg [5:0] next_index = 0;
    reg [5:0] neighbor_ptr = 0;
    reg [5:0] output_ptr = 0;

    // Stack memory (depth, index)
    reg [5:0] stack_depth [0:MAX_DEPTH-1];
    reg [5:0] stack_index [0:MAX_DEPTH-1];

    // Visited array
    reg visited [0:MAX_SIZE-1];

    // Tour output array
    reg [5:0] tour [0:MAX_SIZE-1];

    // Current position
    reg [7:0] current_row = 0;
    reg [7:0] current_col = 0;

    // Neighbor coordinates
    reg [7:0] neighbor_row;
    reg [7:0] neighbor_col;

    // Solution found flag
    reg solution_found = 0;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            stack_ptr <= 0;
            current_depth <= 0;
            current_index <= 0;
            next_index <= 0;
            neighbor_ptr <= 0;
            output_ptr <= 0;
            current_row <= 0;
            current_col <= 0;
            solution_found <= 0;
            done <= 0;
            found <= 0;
            tour_write <= 0;
            tour_addr <= 0;
            tour_row <= 0;
            tour_col <= 0;

            // Reset stack and visited
            integer i;
            for (i = 0; i < MAX_DEPTH; i = i + 1) begin
                stack_depth[i] <= 0;
                stack_index[i] <= 0;
            end
            for (i = 0; i < MAX_SIZE; i = i + 1) begin
                visited[i] <= 0;
                tour[i] <= 0;
            end
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (start) begin
                        state <= STATE_INIT;
                        done <= 0;
                        found <= 0;
                    end
                end

                STATE_INIT: begin
                    // Initialize for new search
                    stack_ptr <= 0;
                    current_depth <= 0;
                    current_index <= 0;
                    current_row <= 0;
                    current_col <= 0;
                    solution_found <= 0;

                    // Reset visited array
                    integer i;
                    for (i = 0; i < MAX_SIZE; i = i + 1) begin
                        visited[i] <= 0;
                    end

                    // Mark starting position as visited
                    visited[0] <= 1;
                    stack_depth[0] <= 1;
                    stack_index[0] <= 0;
                    stack_ptr <= 1;
                    state <= STATE_SEARCH;
                end

                STATE_SEARCH: begin
                    // Check if we've visited all cells
                    if (current_depth == N * M) begin
                        state <= STATE_CHECK_CYCLE;
                    end else begin
                        // Find next unvisited neighbor with distance 2 or 3
                        neighbor_ptr = neighbor_ptr + 1;
                        if (neighbor_ptr < MAX_SIZE) begin
                            // Calculate neighbor coordinates
                            neighbor_row = neighbor_ptr / M;
                            neighbor_col = neighbor_ptr % M;

                            // Calculate Manhattan distance
                            reg [7:0] dist = (current_row > neighbor_row) ? (current_row - neighbor_row) : (neighbor_row - current_row);
                            dist = dist + ((current_col > neighbor_col) ? (current_col - neighbor_col) : (neighbor_col - current_col));

                            // Check if valid neighbor
                            if (!visited[neighbor_ptr] && (dist == 2 || dist == 3)) begin
                                // Push current state to stack
                                stack_depth[stack_ptr] = current_depth + 1;
                                stack_index[stack_ptr] = neighbor_ptr;
                                stack_ptr = stack_ptr + 1;

                                // Update current state
                                current_depth = current_depth + 1;
                                current_index = neighbor_ptr;
                                current_row = neighbor_row;
                                current_col = neighbor_col;
                                visited[neighbor_ptr] = 1;
                                neighbor_ptr = 0;
                            end
                        end else begin
                            // No more neighbors, backtrack
                            if (stack_ptr > 1) begin
                                stack_ptr = stack_ptr - 1;
                                current_depth = stack_depth[stack_ptr-1];
                                current_index = stack_index[stack_ptr-1];
                                current_row = current_index / M;
                                current_col = current_index % M;
                                neighbor_ptr = current_index + 1;
                            end else begin
                                // No solution found
                                state <= STATE_NO_SOLUTION;
                            end
                        end
                    end
                end

                STATE_CHECK_CYCLE: begin
                    // Check if last cell connects back to first with distance 2 or 3
                    reg [7:0] last_row = current_row;
                    reg [7:0] last_col = current_col;
                    reg [7:0] dist = (last_row > 0) ? last_row : (0 - last_row);
                    dist = dist + ((last_col > 0) ? last_col : (0 - last_col));

                    if (dist == 2 || dist == 3) begin
                        solution_found <= 1;
                        state <= STATE_OUTPUT;
                    end else begin
                        state <= STATE_NO_SOLUTION;
                    end
                end

                STATE_OUTPUT: begin
                    // Output the tour sequence
                    if (output_ptr < N * M) begin
                        tour_addr <= output_ptr;
                        tour_row <= tour[output_ptr] / M;
                        tour_col <= tour[output_ptr] % M;
                        tour_write <= 1;
                        output_ptr <= output_ptr + 1;
                    end else begin
                        tour_write <= 0;
                        state <= STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    done <= 1;
                    found <= solution_found;
                    state <= STATE_IDLE;
                end

                STATE_NO_SOLUTION: begin
                    done <= 1;
                    found <= 0;
                    state <= STATE_IDLE;
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

    // Store tour in memory during search
    always @(posedge clk) begin
        if (state == STATE_SEARCH && current_depth > 0 && current_depth <= N * M) begin
            tour[current_depth-1] <= current_index;
        end
    end

endmodule