module maze_escape (
    input clk,
    input rst_n,
    input start,
    input [127:0] grid_data,
    output reg [5:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FIRE_BFS_INIT = 3'd1;
    localparam [2:0] FIRE_BFS_PROCESS = 3'd2;
    localparam [2:0] FIRE_BFS_CHECK = 3'd3;
    localparam [2:0] JOE_BFS_INIT = 3'd4;
    localparam [2:0] JOE_BFS_PROCESS = 3'd5;
    localparam [2:0] JOE_BFS_CHECK = 3'd6;
    localparam [2:0] DONE_STATE = 3'd7;

    // State register
    reg [2:0] state, next_state;

    // Grid storage (8x8, 2 bits per cell)
    reg [1:0] grid [0:7][0:7];

    // Fire arrival times (0-63, 63=inf)
    reg [5:0] fire_time [0:7][0:7];

    // Joe visited flags
    reg visited [0:7][0:7];

    // Fire queue: {row[2:0], col[2:0]}
    reg [5:0] fire_queue [0:63];
    reg [5:0] fire_q_wr, fire_q_rd;
    wire fire_q_empty = (fire_q_wr == fire_q_rd);
    wire fire_q_full = (fire_q_wr == (fire_q_rd + 1));

    // Joe queue: {row[2:0], col[2:0], time[5:0]}
    reg [11:0] joe_queue [0:63];
    reg [5:0] joe_q_wr, joe_q_rd;
    wire joe_q_empty = (joe_q_wr == joe_q_rd);
    wire joe_q_full = (joe_q_wr == (joe_q_rd + 1));

    // Current processing registers
    reg [2:0] cur_r, cur_c;
    reg [5:0] cur_time;
    reg [1:0] dir;

    // Neighbor calculation
    wire [2:0] nr = (dir == 2'd0) ? cur_r - 1 : (dir == 2'd1) ? cur_r + 1 : cur_r;
    wire [2:0] nc = (dir == 2'd2) ? cur_c - 1 : (dir == 2'd3) ? cur_c + 1 : cur_c;
    wire in_bounds = (nr < 8) && (nc < 8);
    wire [1:0] cell = grid[nr][nc];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 6'd63;
            fire_q_wr <= 6'd0;
            fire_q_rd <= 6'd0;
            joe_q_wr <= 6'd0;
            joe_q_rd <= 6'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FIRE_BFS_INIT;
                end else begin
                    next_state = IDLE;
                end
            end

            FIRE_BFS_INIT: begin
                next_state = FIRE_BFS_PROCESS;
            end

            FIRE_BFS_PROCESS: begin
                if (!fire_q_empty) begin
                    next_state = FIRE_BFS_CHECK;
                end else begin
                    next_state = JOE_BFS_INIT;
                end
            end

            FIRE_BFS_CHECK: begin
                if (dir < 2'd3) begin
                    next_state = FIRE_BFS_CHECK;
                end else begin
                    next_state = FIRE_BFS_PROCESS;
                end
            end

            JOE_BFS_INIT: begin
                next_state = JOE_BFS_PROCESS;
            end

            JOE_BFS_PROCESS: begin
                if (!joe_q_empty) begin
                    next_state = JOE_BFS_CHECK;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            JOE_BFS_CHECK: begin
                if (cur_r == 3'd0 || cur_r == 3'd7 || cur_c == 3'd0 || cur_c == 3'd7) begin
                    next_state = DONE_STATE;
                end else if (dir < 2'd3) begin
                    next_state = JOE_BFS_CHECK;
                end else begin
                    next_state = JOE_BFS_PROCESS;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Fire BFS initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset fire times
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    fire_time[i][j] <= 6'd63;
                end
            end
        end else if (state == FIRE_BFS_INIT) begin
            // Load grid from input
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    grid[i][j] <= grid_data[(i * 16) + (j * 2) +: 2];
                end
            end
            // Enqueue all fire cells
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    if (grid[i][j] == 2'b11 && !fire_q_full) begin
                        fire_queue[fire_q_wr] <= {i[2:0], j[2:0]};
                        fire_q_wr <= fire_q_wr + 6'd1;
                        fire_time[i][j] <= 6'd0;
                    end
                end
            end
        end
    end

    // Fire BFS processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize registers
            cur_r <= 3'd0;
            cur_c <= 3'd0;
            cur_time <= 6'd0;
            dir <= 2'd0;
        end else if (state == FIRE_BFS_PROCESS) begin
            if (!fire_q_empty) begin
                {cur_r, cur_c} <= fire_queue[fire_q_rd];
                fire_q_rd <= fire_q_rd + 6'd1;
                cur_time <= fire_time[cur_r][cur_c];
                dir <= 2'd0;
            end
        end else if (state == FIRE_BFS_CHECK) begin
            if (in_bounds && cell != 2'b00 && fire_time[nr][nc] == 6'd63) begin
                fire_time[nr][nc] <= cur_time + 6'd1;
                if (!fire_q_full) begin
                    fire_queue[fire_q_wr] <= {nr, nc};
                    fire_q_wr <= fire_q_wr + 6'd1;
                end
            end
            if (dir < 2'd3) begin
                dir <= dir + 2'd1;
            end
        end
    end

    // Joe BFS initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset visited
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    visited[i][j] <= 1'b0;
                end
            end
        end else if (state == JOE_BFS_INIT) begin
            // Find and enqueue Joe
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    if (grid[i][j] == 2'b10 && !joe_q_full) begin
                        joe_queue[joe_q_wr] <= {i[2:0], j[2:0], 6'd0};
                        joe_q_wr <= joe_q_wr + 6'd1;
                        visited[i][j] <= 1'b1;
                    end
                end
            end
        end
    end

    // Joe BFS processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize registers
            cur_r <= 3'd0;
            cur_c <= 3'd0;
            cur_time <= 6'd0;
            dir <= 2'd0;
        end else if (state == JOE_BFS_PROCESS) begin
            if (!joe_q_empty) begin
                {cur_r, cur_c, cur_time[5:0]} <= joe_queue[joe_q_rd];
                joe_q_rd <= joe_q_rd + 6'd1;
                dir <= 2'd0;
            end
        end else if (state == JOE_BFS_CHECK) begin
            // Check boundary exit
            if (cur_r == 3'd0 || cur_r == 3'd7 || cur_c == 3'd0 || cur_c == 3'd7) begin
                result <= cur_time[5:0];
                done <= 1'b1;
            end else if (dir < 2'd3) begin
                // Check neighbor for movement
                if (in_bounds && cell != 2'b00 && !visited[nr][nc] && (fire_time[nr][nc] > cur_time + 6'd1)) begin
                    if (!joe_q_full) begin
                        joe_queue[joe_q_wr] <= {nr, nc, cur_time[5:0] + 6'd1};
                        joe_q_wr <= joe_q_wr + 6'd1;
                        visited[nr][nc] <= 1'b1;
                    end
                end
                dir <= dir + 2'd1;
            end
        end else if (state == DONE_STATE) begin
            if (result == 6'd63) begin
                result <= 6'd63;
                done <= 1'b1;
            end
        end
    end

endmodule