module maze_transformer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid_in [0:15][0:15],
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [7:0] k,
    output reg [7:0] grid_out [0:15][0:15],
    output reg done,
    output reg result_valid
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] FIND_START = 3'd1;
    localparam [2:0] TRAVERSE    = 3'd2;
    localparam [2:0] MARK        = 3'd3;
    localparam [2:0] OUTPUT      = 3'd4;
    localparam [2:0] DONE_STATE  = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal registers
    reg [7:0] grid_buf [0:15][0:15];
    reg visited [0:15][0:15];
    reg [7:0] queue [0:255];  // Queue for BFS: packed {row[3:0], col[3:0]}
    reg [7:0] queue_head, queue_tail;
    reg [7:0] queue_size;
    
    // Coordinates
    reg [3:0] start_row, start_col;
    reg [3:0] cur_row, cur_col;
    reg [3:0] scan_row, scan_col;
    reg [3:0] mark_row, mark_col;
    
    // Counters
    reg [8:0] total_empty;
    reg [8:0] visited_count;
    reg [8:0] mark_count;
    reg [8:0] keep_count;
    reg [8:0] x_count;
    
    // Neighbor indices
    reg [3:0] nbr_row, nbr_col;
    reg [2:0] nbr_idx;
    
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_valid <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize all arrays
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    grid_out[i][j] <= 8'd0;
                    grid_buf[i][j] <= 8'd0;
                    visited[i][j] <= 1'b0;
                end
            end
            for (i = 0; i < 256; i = i + 1) begin
                queue[i] <= 8'd0;
            end
            start_row <= 4'd0;
            start_col <= 4'd0;
            cur_row <= 4'd0;
            cur_col <= 4'd0;
            scan_row <= 4'd0;
            scan_col <= 4'd0;
            mark_row <= 4'd0;
            mark_col <= 4'd0;
            total_empty <= 9'd0;
            visited_count <= 9'd0;
            mark_count <= 9'd0;
            keep_count <= 9'd0;
            x_count <= 9'd0;
            queue_head <= 8'd0;
            queue_tail <= 8'd0;
            queue_size <= 8'd0;
            nbr_row <= 4'd0;
            nbr_col <= 4'd0;
            nbr_idx <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    // Initialize arrays to avoid X values
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            visited[i][j] <= 1'b0;
                        end
                    end
                    queue_head <= 8'd0;
                    queue_tail <= 8'd0;
                    queue_size <= 8'd0;
                    total_empty <= 9'd0;
                    visited_count <= 9'd0;
                    mark_count <= 9'd0;
                    keep_count <= 9'd0;
                    x_count <= 9'd0;
                    start_row <= 4'd0;
                    start_col <= 4'd0;
                    scan_row <= 4'd0;
                    scan_col <= 4'd0;
                    mark_row <= 4'd0;
                    mark_col <= 4'd0;
                    cur_row <= 4'd0;
                    cur_col <= 4'd0;
                    nbr_row <= 4'd0;
                    nbr_col <= 4'd0;
                    nbr_idx <= 3'd0;
                    if (start) begin
                        // Load input grid into buffer
                        for (i = 0; i < 16; i = i + 1) begin
                            for (j = 0; j < 16; j = j + 1) begin
                                if ((i < n) && (j < m)) begin
                                    grid_buf[i][j] <= grid_in[i][j];
                                end else begin
                                    grid_buf[i][j] <= 8'h23; // Wall outside
                                end
                            end
                        end
                        // Copy initial to output
                        for (i = 0; i < 16; i = i + 1) begin
                            for (j = 0; j < 16; j = j + 1) begin
                                grid_out[i][j] <= grid_in[i][j];
                            end
                        end
                        state <= FIND_START;
                    end
                end

                FIND_START: begin
                    // Scan for first '.' empty cell
                    if (scan_row < n) begin
                        if (scan_col < m) begin
                            if (grid_buf[scan_row][scan_col] == 8'h2E) begin
                                start_row <= scan_row;
                                start_col <= scan_col;
                                // Reset scan for next use
                                scan_row <= 4'd0;
                                scan_col <= 4'd0;
                                state <= TRAVERSE;
                            end else begin
                                // Next column
                                if (scan_col == 4'd15) begin
                                    scan_col <= 4'd0;
                                    scan_row <= scan_row + 4'd1;
                                end else begin
                                    scan_col <= scan_col + 4'd1;
                                end
                            end
                        end else begin
                            // Next row
                            scan_col <= 4'd0;
                            scan_row <= scan_row + 4'd1;
                        end
                    end
                end

                TRAVERSE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (queue_size == 8'd0) begin
                        // First cell or queue empty
                        if (visited_count == 9'd0) begin
                            // Add start to queue
                            queue[queue_tail] <= {start_row, start_col};
                            queue_tail <= queue_tail + 8'd1;
                            queue_size <= 8'd1;
                            visited[start_row][start_col] <= 1'b1;
                            visited_count <= 9'd1;
                            cur_row <= start_row;
                            cur_col <= start_col;
                        end else begin
                            // Traversal complete
                            total_empty <= visited_count;
                            // Calculate keep count
                            if (k <= visited_count) begin
                                keep_count <= visited_count - k;
                                x_count <= k;
                            end else begin
                                // Should not happen per spec
                                keep_count <= 9'd0;
                                x_count <= visited_count;
                            end
                            state <= MARK;
                            mark_row <= 4'd0;
                            mark_col <= 4'd0;
                            mark_count <= 9'd0;
                        end
                    end else begin
                        // Process queue head
                        cur_row <= queue[queue_head][7:4];
                        cur_col <= queue[queue_head][3:0];
                        queue_head <= queue_head + 8'd1;
                        queue_size <= queue_size - 8'd1;
                        nbr_idx <= 3'd0;
                        state <= TRAVERSE + 3'd1; // Go to neighbor processing
                    end
                end

                TRAVERSE + 3'd1: begin // Neighbor processing
                    case (nbr_idx)
                        3'd0: begin // Up
                            nbr_row <= (cur_row > 4'd0) ? (cur_row - 4'd1) : cur_row;
                            nbr_col <= cur_col;
                        end
                        3'd1: begin // Down
                            nbr_row <= (cur_row < n - 4'd1) ? (cur_row + 4'd1) : cur_row;
                            nbr_col <= cur_col;
                        end
                        3'd2: begin // Left
                            nbr_row <= cur_row;
                            nbr_col <= (cur_col > 4'd0) ? (cur_col - 4'd1) : cur_col;
                        end
                        3'd3: begin // Right
                            nbr_row <= cur_row;
                            nbr_col <= (cur_col < m - 4'd1) ? (cur_col + 4'd1) : cur_col;
                        end
                        default: begin
                            nbr_row <= cur_row;
                            nbr_col <= cur_col;
                        end
                    endcase
                    
                    if (nbr_idx < 3'd4) begin
                        // Check if neighbor is valid and not visited
                        if ((nbr_row < n) && (nbr_col < m) && 
                            !visited[nbr_row][nbr_col] &&
                            (grid_buf[nbr_row][nbr_col] == 8'h2E)) begin
                            visited[nbr_row][nbr_col] <= 1'b1;
                            visited_count <= visited_count + 9'd1;
                            queue[queue_tail] <= {nbr_row, nbr_col};
                            queue_tail <= queue_tail + 8'd1;
                            queue_size <= queue_size + 8'd1;
                        end
                        nbr_idx <= nbr_idx + 3'd1;
                        state <= TRAVERSE + 3'd1; // Stay in neighbor processing
                    end else begin
                        state <= TRAVERSE; // Go back to main traverse
                    end
                end

                MARK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (mark_row < n) begin
                        if (mark_col < m) begin
                            if (grid_buf[mark_row][mark_col] == 8'h2E) begin
                                // This is an empty cell, need to decide mark or keep
                                if (mark_count < keep_count) begin
                                    // Keep as '.'
                                    grid_out[mark_row][mark_col] <= 8'h2E;
                                    mark_count <= mark_count + 9'd1;
                                end else begin
                                    // Mark as 'X'
                                    grid_out[mark_row][mark_col] <= 8'h58;
                                end
                            end
                            // Next column
                            if (mark_col == 4'd15) begin
                                mark_col <= 4'd0;
                                mark_row <= mark_row + 4'd1;
                            end else begin
                                mark_col <= mark_col + 4'd1;
                            end
                        end else begin
                            // Next row
                            mark_col <= 4'd0;
                            mark_row <= mark_row + 4'd1;
                        end
                    end else begin
                        // Marking complete
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    // Finalize output (already set in MARK)
                    result_valid <= 1'b1;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule