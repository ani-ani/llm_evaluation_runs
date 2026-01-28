module maze_escape (
    input clk,
    input rst_n,
    input start,
    input [127:0] grid_data,
    output reg [5:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE           = 4'd0;
    localparam [3:0] FIRE_BFS_INIT  = 4'd1;
    localparam [3:0] FIRE_BFS_PROC  = 4'd2;
    localparam [3:0] FIRE_BFS_CHECK = 4'd3;
    localparam [3:0] JOE_BFS_INIT   = 4'd4;
    localparam [3:0] JOE_BFS_PROC   = 4'd5;
    localparam [3:0] JOE_BFS_CHECK  = 4'd6;
    localparam [3:0] DONE           = 4'd7;

    reg [3:0] state;
    reg [3:0] next_state;

    // Grid storage (8x8, 2 bits per cell)
    reg [1:0] grid [0:7][0:7];
    reg [6:0] fire_time [0:7][0:7];
    reg visited [0:7][0:7];

    // Queue signals
    reg [5:0] fire_queue [0:63];
    reg [5:0] fire_q_wr, fire_q_rd;
    wire fire_q_empty;
    wire fire_q_full;

    reg [11:0] joe_queue [0:63];
    reg [5:0] joe_q_wr, joe_q_rd;
    wire joe_q_empty;
    wire joe_q_full;

    // Processing registers
    reg [2:0] cur_r, cur_c;
    reg [6:0] cur_time;
    reg [1:0] dir;
    reg [2:0] nr, nc;
    reg in_bounds;
    reg [1:0] cell;
    reg [2:0] i, j;
    reg [2:0] start_r, start_c;

    // Queue status logic
    assign fire_q_empty = (fire_q_wr == fire_q_rd);
    assign fire_q_full = (fire_q_wr == fire_q_rd + 6'd1);
    assign joe_q_empty = (joe_q_wr == joe_q_rd);
    assign joe_q_full = (joe_q_wr == joe_q_rd + 6'd1);

    // Neighbor calculation
    always @(*) begin
        nr = cur_r;
        nc = cur_c;
        case (dir)
            2'd0: nr = cur_r - 3'd1;
            2'd1: nr = cur_r + 3'd1;
            2'd2: nc = cur_c - 3'd1;
            2'd3: nc = cur_c + 3'd1;
        endcase
        in_bounds = (nr < 8) && (nc < 8);
        if (in_bounds) begin
            cell = grid[nr][nc];
        end else begin
            cell = 2'd0;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 6'd0;
            fire_q_wr <= 6'd0;
            fire_q_rd <= 6'd0;
            joe_q_wr <= 6'd0;
            joe_q_rd <= 6'd0;
            i <= 3'd0;
            j <= 3'd0;
            dir <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Load grid from input
                        for (i = 3'd0; i < 3'd8; i = i + 3'd1) begin
                            for (j = 3'd0; j < 3'd8; j = j + 3'd1) begin
                                grid[i][j] <= grid_data[ ((8*i + j) * 2) +: 2 ];
                                if (grid_data[ ((8*i + j) * 2) +: 2 ] == 2'b10) begin
                                    start_r <= i;
                                    start_c <= j;
                                end
                            end
                        end
                        fire_q_wr <= 6'd0;
                        fire_q_rd <= 6'd0;
                        joe_q_wr <= 6'd0;
                        joe_q_rd <= 6'd0;
                        state <= FIRE_BFS_INIT;
                    end
                    done <= 1'b0;
                end

                FIRE_BFS_INIT: begin
                    if (i < 3'd8) begin
                        if (j < 3'd8) begin
                            // Reset fire times
                            fire_time[i][j] <= 7'b1111111;
                            // Enqueue fire cells
                            if (grid[i][j] == 2'b11) begin
                                if (!fire_q_full) begin
                                    fire_queue[fire_q_wr] <= {i, j};
                                    fire_q_wr <= fire_q_wr + 6'd1;
                                    fire_time[i][j] <= 7'd0;
                                end
                            end
                            j <= j + 3'd1;
                        end else begin
                            j <= 3'd0;
                            i <= i + 3'd1;
                        end
                    end else begin
                        i <= 3'd0;
                        j <= 3'd0;
                        state <= FIRE_BFS_PROC;
                    end
                end

                FIRE_BFS_PROC: begin
                    if (!fire_q_empty) begin
                        {cur_r, cur_c} <= fire_queue[fire_q_rd];
                        fire_q_rd <= fire_q_rd + 6'd1;
                        cur_time <= fire_time[cur_r][cur_c];
                        dir <= 2'd0;
                        state <= FIRE_BFS_CHECK;
                    end else begin
                        state <= JOE_BFS_INIT;
                    end
                end

                FIRE_BFS_CHECK: begin
                    if (dir < 2'd3) begin
                        if (in_bounds && cell != 2'b00 && fire_time[nr][nc] == 7'b1111111) begin
                            fire_time[nr][nc] <= cur_time + 7'd1;
                            if (!fire_q_full) begin
                                fire_queue[fire_q_wr] <= {nr, nc};
                                fire_q_wr <= fire_q_wr + 6'd1;
                            end
                        end
                        dir <= dir + 2'd1;
                    end else begin
                        state <= FIRE_BFS_PROC;
                    end
                end

                JOE_BFS_INIT: begin
                    if (i < 3'd8) begin
                        if (j < 3'd8) begin
                            visited[i][j] <= 1'b0;
                            j <= j + 3'd1;
                        end else begin
                            j <= 3'd0;
                            i <= i + 3'd1;
                        end
                    end else begin
                        // Enqueue start position
                        if (!joe_q_full) begin
                            joe_queue[joe_q_wr] <= {start_r, start_c, 6'd0};
                            joe_q_wr <= joe_q_wr + 6'd1;
                            visited[start_r][start_c] <= 1'b1;
                        end
                        state <= JOE_BFS_PROC;
                    end
                end

                JOE_BFS_PROC: begin
                    if (!joe_q_empty) begin
                        {cur_r, cur_c, cur_time[5:0]} <= joe_queue[joe_q_rd];
                        joe_q_rd <= joe_q_rd + 6'd1;
                        cur_time[6] <= 1'b0;
                        dir <= 2'd0;
                        state <= JOE_BFS_CHECK;
                    end else begin
                        result <= 6'b111111;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end

                JOE_BFS_CHECK: begin
                    if (cur_r == 3'd0 || cur_r == 3'd7 || cur_c == 3'd0 || cur_c == 3'd7) begin
                        result <= cur_time[5:0];
                        done <= 1'b1;
                        state <= DONE;
                    end else if (dir < 2'd3) begin
                        if (in_bounds && cell != 2'b00 && !visited[nr][nc] && (fire_time[nr][nc] > {1'b0, cur_time[5:0]} + 7'd1)) begin
                            if (!joe_q_full) begin
                                joe_queue[joe_q_wr] <= {nr, nc, cur_time[5:0] + 6'd1};
                                joe_q_wr <= joe_q_wr + 6'd1;
                                visited[nr][nc] <= 1'b1;
                            end
                        end
                        dir <= dir + 2'd1;
                    end else begin
                        state <= JOE_BFS_PROC;
                    end
                end

                DONE: begin
                    // Stay in done state
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule