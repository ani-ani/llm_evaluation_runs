module MazeTransformer(
    input clk,
    input rst_n,
    input start,
    input [7:0] grid_in [0:15][0:15],
    input [3:0] n,
    input [3:0] m,
    input [7:0] k,
    output reg [7:0] grid_out [0:15][0:15],
    output reg done,
    output reg result_valid
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] FIND_START = 4'd1;
    localparam [3:0] TRAVERSE  = 4'd2;
    localparam [3:0] MARK      = 4'd3;
    localparam [3:0] OUTPUT    = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    reg [3:0] state, next_state;

    // Internal grid buffer
    reg [7:0] grid_buffer [0:15][0:15];

    // Visited array
    reg visited [0:15][0:15];

    // BFS queue
    reg [7:0] queue [0:255];
    reg [7:0] queue_head, queue_tail;

    // Counters
    reg [7:0] empty_count;
    reg [7:0] marked_count;
    reg [7:0] cycle_count;

    // Coordinates
    reg [3:0] current_row, current_col;
    reg [3:0] start_row, start_col;

    // Constants
    localparam [7:0] EMPTY = 8'h2E;
    localparam [7:0] WALL  = 8'h23;
    localparam [7:0] MARKED = 8'h58;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            result_valid <= 1'b0;
            empty_count <= 8'd0;
            marked_count <= 8'd0;
            cycle_count <= 8'd0;
            queue_head <= 8'd0;
            queue_tail <= 8'd0;
            current_row <= 4'd0;
            current_col <= 4'd0;
            start_row <= 4'd0;
            start_col <= 4'd0;

            // Initialize grid buffer and visited array
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    grid_buffer[i][j] <= grid_in[i][j];
                    visited[i][j] <= 1'b0;
                end
            end

            // Initialize queue
            for (i = 0; i < 256; i = i + 1) begin
                queue[i] <= 8'd0;
            end

            // Initialize grid_out
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    grid_out[i][j] <= grid_in[i][j];
                end
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk) begin
        if (rst_n) begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    if (start) begin
                        next_state <= FIND_START;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FIND_START: begin
                    // Find first empty cell using row-major scan
                    if (current_row < n && current_col < m) begin
                        if (grid_buffer[current_row][current_col] == EMPTY) begin
                            start_row <= current_row;
                            start_col <= current_col;
                            next_state <= TRAVERSE;
                        end else begin
                            if (current_col == m - 1) begin
                                current_col <= 4'd0;
                                current_row <= current_row + 4'd1;
                            end else begin
                                current_col <= current_col + 4'd1;
                            end
                        end
                    end else begin
                        // No empty cells found (shouldn't happen per spec)
                        next_state <= IDLE;
                    end
                end

                TRAVERSE: begin
                    // BFS traversal
                    if (queue_head != queue_tail) begin
                        // Dequeue
                        current_row <= queue[queue_head][7:4];
                        current_col <= queue[queue_head][3:0];
                        queue_head <= queue_head + 8'd1;
                        cycle_count <= cycle_count + 8'd1;

                        // Mark as visited
                        visited[current_row][current_col] <= 1'b1;
                        empty_count <= empty_count + 8'd1;

                        // Check neighbors (up, down, left, right)
                        integer i;
                        reg [3:0] new_row, new_col;
                        for (i = 0; i < 4; i = i + 1) begin
                            case (i)
                                0: begin new_row = current_row - 4'd1; new_col = current_col; end
                                1: begin new_row = current_row + 4'd1; new_col = current_col; end
                                2: begin new_row = current_row; new_col = current_col - 4'd1; end
                                3: begin new_row = current_row; new_col = current_col + 4'd1; end
                            endcase

                            // Check bounds and if empty and not visited
                            if (new_row >= 0 && new_row < n && new_col >= 0 && new_col < m &&
                                grid_buffer[new_row][new_col] == EMPTY &&
                                !visited[new_row][new_col]) begin
                                // Enqueue
                                queue[queue_tail] <= {new_row, new_col};
                                queue_tail <= queue_tail + 8'd1;
                                visited[new_row][new_col] <= 1'b1;
                            end
                        end

                        // Check if we've processed all empty cells
                        if (empty_count >= (empty_count + 8'd1) || cycle_count >= MAX_CYCLES) begin
                            next_state <= MARK;
                        end
                    end else begin
                        next_state <= MARK;
                    end
                end

                MARK: begin
                    // Mark (total_empty - k) cells as '.' and rest as 'X'
                    if (marked_count < (empty_count - k)) begin
                        if (queue_head != queue_tail) begin
                            current_row <= queue[queue_head][7:4];
                            current_col <= queue[queue_head][3:0];
                            queue_head <= queue_head + 8'd1;
                            grid_buffer[current_row][current_col] <= EMPTY;
                            marked_count <= marked_count + 8'd1;
                        end
                    end else begin
                        // Mark remaining as 'X'
                        if (marked_count < empty_count) begin
                            if (queue_head != queue_tail) begin
                                current_row <= queue[queue_head][7:4];
                                current_col <= queue[queue_head][3:0];
                                queue_head <= queue_head + 8'd1;
                                grid_buffer[current_row][current_col] <= MARKED;
                                marked_count <= marked_count + 8'd1;
                            end
                        end else begin
                            next_state <= OUTPUT;
                        end
                    end
                end

                OUTPUT: begin
                    // Copy grid_buffer to grid_out
                    integer i, j;
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            grid_out[i][j] <= grid_buffer[i][j];
                        end
                    end
                    result_valid <= 1'b1;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Load input grid when start is asserted
    always @(posedge clk) begin
        if (rst_n && start) begin
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    grid_buffer[i][j] <= grid_in[i][j];
                end
            end
        end
    end

endmodule