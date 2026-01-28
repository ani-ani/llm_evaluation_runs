module drain_baltic(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] source_row,
    input wire [3:0] source_col,
    input wire grid_valid,
    input wire signed [15:0] grid_data,
    output reg [31:0] drained_volume,
    output reg done
);

    // Constants
    localparam [7:0] MAX_ROWS = 8'd16;
    localparam [7:0] MAX_COLS = 8'd16;
    localparam [7:0] MAX_CELLS = 8'd255;
    localparam [7:0] MAX_ITERATIONS = 8'd256;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state, next_state;

    // Memory for grid altitudes
    reg signed [15:0] grid [0:MAX_ROWS-1][0:MAX_COLS-1];

    // Visited flags
    reg visited [0:MAX_ROWS-1][0:MAX_COLS-1];

    // Queue for BFS
    reg [7:0] queue_row [0:MAX_CELLS];
    reg [7:0] queue_col [0:MAX_CELLS];
    reg [7:0] queue_head, queue_tail;
    reg [7:0] queue_size;

    // Loading counter
    reg [7:0] load_counter;

    // Processing counter
    reg [7:0] iteration_counter;

    // Current cell being processed
    reg [7:0] current_row, current_col;

    // Neighbor offsets (8 directions)
    localparam signed [3:0] drow [0:7] = '{1, 1, 0, -1, -1, -1, 0, 1};
    localparam signed [3:0] dcol [0:7] = '{0, 1, 1, 1, 0, -1, -1, -1};

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            drained_volume <= 32'd0;
            done <= 1'b0;
            load_counter <= 8'd0;
            iteration_counter <= 8'd0;
            queue_head <= 8'd0;
            queue_tail <= 8'd0;
            queue_size <= 8'd0;
            current_row <= 8'd0;
            current_col <= 8'd0;

            // Initialize grid and visited arrays
            integer i, j;
            for (i = 0; i < MAX_ROWS; i = i + 1) begin
                for (j = 0; j < MAX_COLS; j = j + 1) begin
                    grid[i][j] <= 16'd0;
                    visited[i][j] <= 1'b0;
                end
            end
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
                    next_state = LOAD;
                end
            end

            LOAD: begin
                if (load_counter == MAX_CELLS && grid_valid) begin
                    next_state = PROCESS;
                end
            end

            PROCESS: begin
                if (queue_size == 0 || iteration_counter >= MAX_ITERATIONS) begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Loading logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_counter <= 8'd0;
        end else if (state == LOAD && grid_valid) begin
            if (load_counter < MAX_CELLS) begin
                grid[load_counter[7:4]][load_counter[3:0]] <= grid_data;
                load_counter <= load_counter + 8'd1;
            end
        end
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iteration_counter <= 8'd0;
            queue_head <= 8'd0;
            queue_tail <= 8'd0;
            queue_size <= 8'd0;
            current_row <= 8'd0;
            current_col <= 8'd0;
        end else if (state == PROCESS) begin
            // Initialize queue with source cell if not already done
            if (iteration_counter == 0 && queue_size == 0) begin
                queue_row[queue_tail] <= source_row;
                queue_col[queue_tail] <= source_col;
                queue_tail <= queue_tail + 8'd1;
                queue_size <= queue_size + 8'd1;
                visited[source_row][source_col] <= 1'b1;
                if (grid[source_row][source_col] < 16'd0) begin
                    drained_volume <= drained_volume + (-grid[source_row][source_col]);
                end
            end

            // Process current cell
            if (queue_size > 0) begin
                current_row <= queue_row[queue_head];
                current_col <= queue_col[queue_head];
                queue_head <= queue_head + 8'd1;
                queue_size <= queue_size - 8'd1;

                // Check 8 neighbors
                integer k;
                for (k = 0; k < 8; k = k + 1) begin
                    reg [7:0] nrow = current_row + drow[k];
                    reg [7:0] ncol = current_col + dcol[k];

                    // Boundary check
                    if (nrow >= 0 && nrow < MAX_ROWS && ncol >= 0 && ncol < MAX_COLS) begin
                        // Check if neighbor is lower and not visited
                        if (grid[nrow][ncol] < grid[current_row][current_col] && !visited[nrow][ncol]) begin
                            visited[nrow][ncol] <= 1'b1;
                            if (grid[nrow][ncol] < 16'd0) begin
                                drained_volume <= drained_volume + (-grid[nrow][ncol]);
                            end

                            // Add to queue
                            queue_row[queue_tail] <= nrow;
                            queue_col[queue_tail] <= ncol;
                            queue_tail <= queue_tail + 8'd1;
                            queue_size <= queue_size + 8'd1;
                        end
                    end
                end

                iteration_counter <= iteration_counter + 8'd1;
            end
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == FINISH) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule