module maze_solver (
    input clk, rst_n, start,
    input [3:0] n, m,  // Grid dimensions (1-8)
    input [5:0] k,     // Walls to add (0-63)
    input [1:0] grid_in [0:7][0:7],  // 0=wall, 1=empty
    output reg [1:0] grid_out [0:7][0:7],  // 0=wall, 1=empty, 2=X
    output reg done
);

// State definitions
localparam [3:0] IDLE = 4'd0;
localparam [3:0] INIT_SCAN = 4'd1;
localparam [3:0] SCAN = 4'd2;
localparam [3:0] BFS_INIT = 4'd3;
localparam [3:0] BFS_LOOP = 4'd4;
localparam [3:0] BFS_DEQUEUE = 4'd5;
localparam [3:0] BFS_PROCESS = 4'd6;
localparam [3:0] BFS_ENQUEUE = 4'd7;
localparam [3:0] MARK = 4'd8;
localparam [3:0] MARK_LOOP = 4'd9;
localparam [3:0] DONE = 4'd10;

// Internal registers
reg [3:0] state;
reg [2:0] row_idx, col_idx;
reg [5:0] s, target, visited_count;
reg found_start;
reg [2:0] start_row, start_col;
reg [2:0] cur_row, cur_col;
reg [1:0] neighbor_count;

// Arrays (8x8)
reg [0:7] visited [0:7];
reg [0:7] in_queue [0:7];
reg [5:0] queue [0:63];  // {row[2:0], col[2:0]}
reg [6:0] head, tail;    // 0-64

// Next state logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        row_idx <= 3'd0;
        col_idx <= 3'd0;
        s <= 6'd0;
        target <= 6'd0;
        visited_count <= 6'd0;
        found_start <= 1'b0;
        start_row <= 3'd0;
        start_col <= 3'd0;
        cur_row <= 3'd0;
        cur_col <= 3'd0;
        neighbor_count <= 2'd0;
        head <= 7'd0;
        tail <= 7'd0;
        for (integer i = 0; i < 8; i = i + 1) begin
            for (integer j = 0; j < 8; j = j + 1) begin
                visited[i][j] <= 1'b0;
                in_queue[i][j] <= 1'b0;
                grid_out[i][j] <= 2'd0;
            end
        end
        for (integer i = 0; i < 64; i = i + 1) begin
            queue[i] <= 6'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= INIT_SCAN;
                end
            end

            INIT_SCAN: begin
                row_idx <= 3'd0;
                col_idx <= 3'd0;
                s <= 6'd0;
                found_start <= 1'b0;
                state <= SCAN;
            end

            SCAN: begin
                if (grid_in[row_idx][col_idx] == 2'd1) begin
                    s <= s + 6'd1;
                    if (!found_start) begin
                        start_row <= row_idx;
                        start_col <= col_idx;
                        found_start <= 1'b1;
                    end
                end
                if (row_idx == n - 3'd1 && col_idx == m - 3'd1) begin
                    state <= BFS_INIT;
                end else begin
                    if (col_idx == m - 3'd1) begin
                        col_idx <= 3'd0;
                        row_idx <= row_idx + 3'd1;
                    end else begin
                        col_idx <= col_idx + 3'd1;
                    end
                    state <= SCAN;
                end
            end

            BFS_INIT: begin
                for (integer i = 0; i < 8; i = i + 1) begin
                    for (integer j = 0; j < 8; j = j + 1) begin
                        visited[i][j] <= 1'b0;
                        in_queue[i][j] <= 1'b0;
                    end
                end
                head <= 7'd0;
                tail <= 7'd0;
                visited_count <= 6'd0;
                target <= (s > k) ? (s - k) : 6'd0;
                if (s > 6'd0) begin
                    queue[0] <= {start_row, start_col};
                    tail <= 7'd1;
                    in_queue[start_row][start_col] <= 1'b1;
                end
                state <= BFS_LOOP;
            end

            BFS_LOOP: begin
                if (visited_count == target) begin
                    state <= MARK;
                end else if (head == tail) begin
                    state <= MARK;
                end else begin
                    state <= BFS_DEQUEUE;
                end
            end

            BFS_DEQUEUE: begin
                cur_row <= queue[head][5:3];
                cur_col <= queue[head][2:0];
                head <= head + 7'd1;
                state <= BFS_PROCESS;
            end

            BFS_PROCESS: begin
                if (visited[cur_row][cur_col] == 1'b0) begin
                    visited[cur_row][cur_col] <= 1'b1;
                    visited_count <= visited_count + 6'd1;
                    if (visited_count == target) begin
                        state <= MARK;
                    end else begin
                        state <= BFS_ENQUEUE;
                        neighbor_count <= 2'd0;
                    end
                end else begin
                    state <= BFS_LOOP;
                end
            end

            BFS_ENQUEUE: begin
                case (neighbor_count)
                    2'd0: begin
                        if (cur_row < n - 3'd1 && grid_in[cur_row + 3'd1][cur_col] == 2'd1 &&
                            visited[cur_row + 3'd1][cur_col] == 1'b0 && in_queue[cur_row + 3'd1][cur_col] == 1'b0) begin
                            queue[tail] <= {cur_row + 3'd1, cur_col};
                            tail <= tail + 7'd1;
                            in_queue[cur_row + 3'd1][cur_col] <= 1'b1;
                        end
                    end
                    2'd1: begin
                        if (cur_row > 3'd0 && grid_in[cur_row - 3'd1][cur_col] == 2'd1 &&
                            visited[cur_row - 3'd1][cur_col] == 1'b0 && in_queue[cur_row - 3'd1][cur_col] == 1'b0) begin
                            queue[tail] <= {cur_row - 3'd1, cur_col};
                            tail <= tail + 7'd1;
                            in_queue[cur_row - 3'd1][cur_col] <= 1'b1;
                        end
                    end
                    2'd2: begin
                        if (cur_col < m - 3'd1 && grid_in[cur_row][cur_col + 3'd1] == 2'd1 &&
                            visited[cur_row][cur_col + 3'd1] == 1'b0 && in_queue[cur_row][cur_col + 3'd1] == 1'b0) begin
                            queue[tail] <= {cur_row, cur_col + 3'd1};
                            tail <= tail + 7'd1;
                            in_queue[cur_row][cur_col + 3'd1] <= 1'b1;
                        end
                    end
                    2'd3: begin
                        if (cur_col > 3'd0 && grid_in[cur_row][cur_col - 3'd1] == 2'd1 &&
                            visited[cur_row][cur_col - 3'd1] == 1'b0 && in_queue[cur_row][cur_col - 3'd1] == 1'b0) begin
                            queue[tail] <= {cur_row, cur_col - 3'd1};
                            tail <= tail + 7'd1;
                            in_queue[cur_row][cur_col - 3'd1] <= 1'b1;
                        end
                    end
                endcase
                if (neighbor_count == 2'd3) begin
                    state <= BFS_LOOP;
                end else begin
                    neighbor_count <= neighbor_count + 2'd1;
                    state <= BFS_ENQUEUE;
                end
            end

            MARK: begin
                row_idx <= 3'd0;
                col_idx <= 3'd0;
                state <= MARK_LOOP;
            end

            MARK_LOOP: begin
                if (grid_in[row_idx][col_idx] == 2'd1 && visited[row_idx][col_idx] == 1'b0) begin
                    grid_out[row_idx][col_idx] <= 2'd2;
                end else begin
                    grid_out[row_idx][col_idx] <= grid_in[row_idx][col_idx];
                end
                if (row_idx == n - 3'd1 && col_idx == m - 3'd1) begin
                    state <= DONE;
                end else begin
                    if (col_idx == m - 3'd1) begin
                        col_idx <= 3'd0;
                        row_idx <= row_idx + 3'd1;
                    end else begin
                        col_idx <= col_idx + 3'd1;
                    end
                    state <= MARK_LOOP;
                end
            end

            DONE: begin
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule