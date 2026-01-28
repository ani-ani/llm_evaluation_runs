module MagnetGridSolver(
    input clk,
    input rst_n,
    input start,
    input [255:0] grid_flat,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] ROW_CHECK = 3'd1;
    localparam [2:0] COL_CHECK = 3'd2;
    localparam [2:0] FLOOD_FILL = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Grid and visited arrays
    reg [15:0] grid [0:15];
    reg [15:0] visited [0:15];

    // Control signals
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2048;

    // Check flags
    reg row_valid;
    reg col_valid;
    reg has_empty_row;
    reg has_empty_col;

    // Row/col check counters
    reg [3:0] row_idx;
    reg [3:0] col_idx;

    // Flood fill counters
    reg [3:0] ff_row;
    reg [3:0] ff_col;
    reg [3:0] component_count;

    // Temporary signals
    reg [3:0] temp_row;
    reg [3:0] temp_col;
    reg [3:0] queue_row [0:255];
    reg [3:0] queue_col [0:255];
    reg [7:0] queue_head, queue_tail;

    // Initialize grid from flat input
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            next_state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            row_valid <= 1'b1;
            col_valid <= 1'b1;
            has_empty_row <= 1'b0;
            has_empty_col <= 1'b0;
            row_idx <= 4'd0;
            col_idx <= 4'd0;
            ff_row <= 4'd0;
            ff_col <= 4'd0;
            component_count <= 4'd0;
            temp_row <= 4'd0;
            temp_col <= 4'd0;
            queue_head <= 8'd0;
            queue_tail <= 8'd0;

            // Initialize grid and visited arrays
            for (i = 0; i < 16; i = i + 1) begin
                grid[i] <= 16'd0;
                visited[i] <= 16'd0;
            end

            // Initialize queue
            for (i = 0; i < 256; i = i + 1) begin
                queue_row[i] <= 4'd0;
                queue_col[i] <= 4'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Load grid from flat input
                        for (i = 0; i < 16; i = i + 1) begin
                            grid[i] <= grid_flat[(i+1)*16-1 : i*16];
                        end
                        // Initialize visited array
                        for (i = 0; i < 16; i = i + 1) begin
                            visited[i] <= 16'd0;
                        end
                        row_idx <= 4'd0;
                        col_idx <= 4'd0;
                        row_valid <= 1'b1;
                        col_valid <= 1'b1;
                        has_empty_row <= 1'b0;
                        has_empty_col <= 1'b0;
                        next_state <= ROW_CHECK;
                    end
                end

                ROW_CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (row_idx < 4'd16) begin
                        // Check if row is all zeros
                        if (grid[row_idx] == 16'd0) begin
                            has_empty_row <= 1'b1;
                        end
                        // Check contiguity
                        reg [15:0] row = grid[row_idx];
                        reg start_found = 1'b0;
                        reg end_found = 1'b0;
                        reg [3:0] col;
                        for (col = 0; col < 16; col = col + 1) begin
                            if (row[col] && !start_found) begin
                                start_found <= 1'b1;
                            end else if (!row[col] && start_found && !end_found) begin
                                end_found <= 1'b1;
                            end else if (row[col] && end_found) begin
                                row_valid <= 1'b0;
                            end
                        end
                        row_idx <= row_idx + 4'd1;
                    end else begin
                        row_idx <= 4'd0;
                        next_state <= COL_CHECK;
                    end
                end

                COL_CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (col_idx < 4'd16) begin
                        // Check if column is all zeros
                        reg col_empty = 1'b1;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (grid[i][col_idx]) begin
                                col_empty <= 1'b0;
                            end
                        end
                        if (col_empty) begin
                            has_empty_col <= 1'b1;
                        end
                        // Check contiguity
                        reg start_found = 1'b0;
                        reg end_found = 1'b0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (grid[i][col_idx] && !start_found) begin
                                start_found <= 1'b1;
                            end else if (!grid[i][col_idx] && start_found && !end_found) begin
                                end_found <= 1'b1;
                            end else if (grid[i][col_idx] && end_found) begin
                                col_valid <= 1'b0;
                            end
                        end
                        col_idx <= col_idx + 4'd1;
                    end else begin
                        col_idx <= 4'd0;
                        // Check validity
                        if (!row_valid || !col_valid || (has_empty_row ^ has_empty_col)) begin
                            result <= 8'd255;
                            next_state <= DONE_STATE;
                        end else begin
                            // Initialize for flood fill
                            component_count <= 4'd0;
                            queue_head <= 8'd0;
                            queue_tail <= 8'd0;
                            next_state <= FLOOD_FILL;
                        end
                    end
                end

                FLOOD_FILL: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Find next unvisited '1'
                    reg found = 1'b0;
                    for (i = 0; i < 16 && !found; i = i + 1) begin
                        for (j = 0; j < 16 && !found; j = j + 1) begin
                            if (grid[i][j] && !visited[i][j]) begin
                                ff_row <= i;
                                ff_col <= j;
                                found <= 1'b1;
                            end
                        end
                    end

                    if (found) begin
                        // Start BFS
                        component_count <= component_count + 4'd1;
                        queue_row[queue_tail] <= ff_row;
                        queue_col[queue_tail] <= ff_col;
                        queue_tail <= queue_tail + 8'd1;
                        visited[ff_row][ff_col] <= 1'b1;
                        next_state <= FLOOD_FILL;
                    end else begin
                        // All components found
                        result <= component_count;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase

            // BFS processing (separate always block for queue processing)
            if (state == FLOOD_FILL && queue_head < queue_tail) begin
                temp_row <= queue_row[queue_head];
                temp_col <= queue_col[queue_head];
                queue_head <= queue_head + 8'd1;

                // Check neighbors (4-directional)
                reg [3:0] new_row, new_col;

                // North
                new_row = temp_row - 4'd1;
                new_col = temp_col;
                if (new_row >= 4'd0 && new_row < 4'd16 && grid[new_row][new_col] && !visited[new_row][new_col]) begin
                    visited[new_row][new_col] <= 1'b1;
                    queue_row[queue_tail] <= new_row;
                    queue_col[queue_tail] <= new_col;
                    queue_tail <= queue_tail + 8'd1;
                end

                // South
                new_row = temp_row + 4'd1;
                new_col = temp_col;
                if (new_row >= 4'd0 && new_row < 4'd16 && grid[new_row][new_col] && !visited[new_row][new_col]) begin
                    visited[new_row][new_col] <= 1'b1;
                    queue_row[queue_tail] <= new_row;
                    queue_col[queue_tail] <= new_col;
                    queue_tail <= queue_tail + 8'd1;
                end

                // West
                new_row = temp_row;
                new_col = temp_col - 4'd1;
                if (new_col >= 4'd0 && new_col < 4'd16 && grid[new_row][new_col] && !visited[new_row][new_col]) begin
                    visited[new_row][new_col] <= 1'b1;
                    queue_row[queue_tail] <= new_row;
                    queue_col[queue_tail] <= new_col;
                    queue_tail <= queue_tail + 8'd1;
                end

                // East
                new_row = temp_row;
                new_col = temp_col + 4'd1;
                if (new_col >= 4'd0 && new_col < 4'd16 && grid[new_row][new_col] && !visited[new_row][new_col]) begin
                    visited[new_row][new_col] <= 1'b1;
                    queue_row[queue_tail] <= new_row;
                    queue_col[queue_tail] <= new_col;
                    queue_tail <= queue_tail + 8'd1;
                end
            end

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                result <= 8'd255;
                next_state <= DONE_STATE;
            end
        end
    end

endmodule