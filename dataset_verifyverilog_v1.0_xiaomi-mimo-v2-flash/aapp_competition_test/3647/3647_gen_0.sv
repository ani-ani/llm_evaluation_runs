module slide_maze_bfs (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid [0:7][0:7],
    output reg signed [15:0] result [0:7][0:7],
    output reg done
);

    // State definitions
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] FIND_GOAL = 4'd1;
    localparam [3:0] GET_NEIGHBORS = 4'd2;
    localparam [3:0] CHECK_SLIDE = 4'd3;
    localparam [3:0] UPDATE_DIST = 4'd4;
    localparam [3:0] CHECK_QUEUE = 4'd5;
    localparam [3:0] FINISH    = 4'd6;

    // ASCII constants
    localparam [7:0] CHAR_GRAVEL = 8'h2E; // '.'
    localparam [7:0] CHAR_OBSTACLE = 8'h23; // '#'
    localparam [7:0] CHAR_ICE = 8'h5F; // '_'
    localparam [7:0] CHAR_GOAL = 8'h4D; // 'M'

    // Direction constants
    localparam [1:0] DIR_N = 2'd0;
    localparam [1:0] DIR_S = 2'd1;
    localparam [1:0] DIR_E = 2'd2;
    localparam [1:0] DIR_W = 2'd3;

    // Registers
    reg [3:0] state, next_state;
    reg signed [15:0] dist [0:7][0:7];
    reg [5:0] queue [0:63]; // Linear queue for 64 cells (r*8 + c)
    reg [5:0] queue_head, queue_tail, queue_count;
    reg [2:0] i, j, dir; // Iteration counters
    reg signed [15:0] cur_dist;
    reg [2:0] cur_r, cur_c, next_r, next_c;
    reg [2:0] slide_r, slide_c;
    reg [2:0] step_r, step_c;
    reg signed [15:0] temp_dist;
    reg found_goal;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Direction deltas
    wire signed [2:0] dr [0:3];
    wire signed [2:0] dc [0:3];
    assign dr[0] = -3'sd1; assign dc[0] = 3'sd0; // N
    assign dr[1] = 3'sd1;  assign dc[1] = 3'sd0; // S
    assign dr[2] = 3'sd0;  assign dc[2] = 3'sd1; // E
    assign dr[3] = 3'sd0;  assign dc[3] = -3'sd1; // W

    // Combinational logic for slide calculation
    always @(*) begin
        slide_r = cur_r;
        slide_c = cur_c;
        // Keep sliding while on ice
        while (slide_r < 8 && slide_c < 8) begin
            if (grid[slide_r][slide_c] == CHAR_ICE) begin
                slide_r = slide_r + dr[dir];
                slide_c = slide_c + dc[dir];
            end else begin
                break;
            end
        end
        // Check if we went out of bounds or hit obstacle
        if (slide_r >= 8 || slide_c >= 8 || slide_r < 0 || slide_c < 0) begin
            next_r = cur_r;
            next_c = cur_c;
        end else if (grid[slide_r][slide_c] == CHAR_OBSTACLE) begin
            next_r = cur_r;
            next_c = cur_c;
        end else begin
            next_r = slide_r;
            next_c = slide_c;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_counter <= 8'd0;
            queue_head <= 6'd0;
            queue_tail <= 6'd0;
            queue_count <= 6'd0;
            found_goal <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    result[i][j] <= 16'sd0;
                    dist[i][j] <= 16'sd0;
                end
            end
        end else begin
            // Clear done flag when new start comes
            if (start) begin
                done <= 1'b0;
            end else if (state == FINISH) begin
                done <= 1'b1;
            end else if (state == IDLE) begin
                done <= 1'b0;
            end

            case (state)
                IDLE: begin
                    cycle_counter <= 8'd0;
                    if (start) begin
                        state <= FIND_GOAL;
                    end
                end

                FIND_GOAL: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (cycle_counter < 8'd64) begin
                        i <= cycle_counter[5:3];
                        j <= cycle_counter[2:0];
                    end
                    if (cycle_counter > 0 && cycle_counter <= 8'd64) begin
                        if (grid[i][j] == CHAR_GOAL) begin
                            dist[i][j] <= 16'sd0;
                            queue[queue_tail] <= {i, j};
                            queue_tail <= queue_tail + 6'd1;
                            queue_count <= queue_count + 6'd1;
                            found_goal <= 1'b1;
                        end else begin
                            dist[i][j] <= 16'sd0; // Initialize
                        end
                    end
                    if (cycle_counter == 8'd64) begin
                        if (found_goal) begin
                            state <= CHECK_QUEUE;
                        end else begin
                            state <= FINISH; // No goal found
                        end
                        cycle_counter <= 8'd0;
                    end
                end

                CHECK_QUEUE: begin
                    if (queue_count == 6'd0) begin
                        state <= FINISH;
                    end else begin
                        cur_r <= queue[queue_head][5:3];
                        cur_c <= queue[queue_head][2:0];
                        cur_dist <= dist[queue[queue_head][5:3]][queue[queue_head][2:0]];
                        queue_head <= queue_head + 6'd1;
                        queue_count <= queue_count - 6'd1;
                        dir <= 4'd0; // Start with N
                        state <= GET_NEIGHBORS;
                    end
                end

                GET_NEIGHBORS: begin
                    if (dir < 4'd4) begin
                        state <= CHECK_SLIDE;
                    end else begin
                        state <= CHECK_QUEUE;
                    end
                end

                CHECK_SLIDE: begin
                    // Combinational logic already computed next_r, next_c
                    if (next_r < 8 && next_c < 8 && 
                        next_r >= 0 && next_c >= 0 &&
                        (next_r != cur_r || next_c != cur_c) &&
                        grid[next_r][next_c] != CHAR_OBSTACLE) begin
                        // Check if we need to update distance
                        if (dist[next_r][next_c] == 16'sd0 && 
                            grid[next_r][next_c] != CHAR_GOAL) begin
                            temp_dist <= cur_dist + 16'sd1;
                            state <= UPDATE_DIST;
                        end else begin
                            state <= GET_NEIGHBORS;
                            dir <= dir + 4'd1;
                        end
                    end else begin
                        state <= GET_NEIGHBORS;
                        dir <= dir + 4'd1;
                    end
                end

                UPDATE_DIST: begin
                    dist[next_r][next_c] <= temp_dist;
                    queue[queue_tail] <= {next_r, next_c};
                    queue_tail <= queue_tail + 6'd1;
                    queue_count <= queue_count + 6'd1;
                    dir <= dir + 4'd1;
                    state <= GET_NEIGHBORS;
                end

                FINISH: begin
                    // Copy dist to result
                    cycle_counter <= cycle_counter + 8'd1;
                    if (cycle_counter < 8'd64) begin
                        i <= cycle_counter[5:3];
                        j <= cycle_counter[2:0];
                    end
                    if (cycle_counter > 0 && cycle_counter <= 8'd64) begin
                        if (dist[i][j] == 16'sd0 && grid[i][j] != CHAR_GOAL && grid[i][j] != CHAR_OBSTACLE) begin
                            result[i][j] <= 16'sd0; // Not reached, keep 0 or handle as -1
                        end else if (grid[i][j] == CHAR_OBSTACLE) begin
                            result[i][j] <= -16'sd1;
                        end else begin
                            result[i][j] <= dist[i][j];
                        end
                    end
                    if (cycle_counter > 8'd64) begin
                        state <= IDLE;
                        found_goal <= 1'b0;
                        cycle_counter <= 8'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                dist[i][j] <= 16'sd0;
                            end
                        end
                        queue_head <= 6'd0;
                        queue_tail <= 6'd0;
                        queue_count <= 6'd0;
                    end
                end

                default: state <= IDLE;
            endcase

            // Check for cycles
            if (cycle_counter >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                state <= FINISH;
            end
        end
    end

endmodule