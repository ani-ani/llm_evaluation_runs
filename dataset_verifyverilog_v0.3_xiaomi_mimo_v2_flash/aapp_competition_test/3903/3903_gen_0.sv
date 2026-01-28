module three_states (
    input clk,
    input rst_n,
    input start,
    input [191:0] grid_flat,
    output reg [5:0] min_roads,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE   = 3'd0;
    localparam [2:0] LOAD   = 3'd1;
    localparam [2:0] BFS1   = 3'd2;
    localparam [2:0] BFS2   = 3'd3;
    localparam [2:0] BFS3   = 3'd4;
    localparam [2:0] COMPUTE = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    // Grid storage (8x8 array)
    reg [2:0] grid [0:7][0:7];
    // Distance arrays for each state
    reg [5:0] dist1 [0:7][0:7];
    reg [5:0] dist2 [0:7][0:7];
    reg [5:0] dist3 [0:7][0:7];

    // Control registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [5:0] cell_idx;
    reg [7:0] min_total;
    reg [7:0] bfs_timeout;
    reg [5:0] head;
    reg [5:0] tail;
    reg [5:0] queue [0:63];
    reg [5:0] current_cell;
    reg [2:0] neighbor_cnt;
    reg [2:0] current_state_idx;

    // Neighbor direction offsets
    reg [2:0] dr [0:3];
    reg [2:0] dc [0:3];

    // Helper: get neighbor cell
    function [5:0] get_neighbor;
        input [5:0] cell;
        input [1:0] dir;
        reg [2:0] r, c;
        begin
            r = cell[5:3];
            c = cell[2:0];
            case (dir)
                2'd0: c = c + 1;
                2'd1: c = c - 1;
                2'd2: r = r + 1;
                2'd3: r = r - 1;
            endcase
            get_neighbor = {r, c};
        end
    endfunction

    // Helper: check if cell is valid
    function valid_cell;
        input [5:0] cell;
        reg [2:0] r, c;
        begin
            r = cell[5:3];
            c = cell[2:0];
            valid_cell = (r < 8) && (c < 8);
        end
    endfunction

    // Get distance value
    function [5:0] get_dist;
        input [5:0] cell;
        input [1:0] state_idx;
        reg [2:0] r, c;
        begin
            r = cell[5:3];
            c = cell[2:0];
            case (state_idx)
                2'd0: get_dist = dist1[r][c];
                2'd1: get_dist = dist2[r][c];
                2'd2: get_dist = dist3[r][c];
                default: get_dist = 6'd63;
            endcase
        end
    endfunction

    // Set distance value
    task set_dist;
        input [5:0] cell;
        input [1:0] state_idx;
        input [5:0] value;
        reg [2:0] r, c;
        begin
            r = cell[5:3];
            c = cell[2:0];
            case (state_idx)
                2'd0: dist1[r][c] <= value;
                2'd1: dist2[r][c] <= value;
                2'd2: dist3[r][c] <= value;
            endcase
        end
    endtask

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
            min_roads <= 6'd0;
            cell_idx <= 6'd0;
            min_total <= 8'd255;
            bfs_timeout <= 8'd0;
            head <= 6'd0;
            tail <= 6'd0;
            neighbor_cnt <= 3'd0;
            current_cell <= 6'd0;
            current_state_idx <= 2'd0;
            // Initialize arrays to avoid X values
            for (integer i = 0; i < 8; i = i + 1) begin
                for (integer j = 0; j < 8; j = j + 1) begin
                    grid[i][j] <= 3'd0;
                    dist1[i][j] <= 6'd63;
                    dist2[i][j] <= 6'd63;
                    dist3[i][j] <= 6'd63;
                end
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 0;
                    cell_idx <= 6'd0;
                    min_total <= 8'd255;
                    bfs_timeout <= 8'd0;
                    head <= 6'd0;
                    tail <= 6'd0;
                    neighbor_cnt <= 3'd0;
                end
                LOAD: begin
                    // Unpack grid_flat into 8x8 array
                    for (integer i = 0; i < 8; i = i + 1) begin
                        for (integer j = 0; j < 8; j = j + 1) begin
                            grid[i][j] <= grid_flat[(i*8+j)*3 +: 3];
                        end
                    end
                    // Initialize distances
                    for (integer i = 0; i < 8; i = i + 1) begin
                        for (integer j = 0; j < 8; j = j + 1) begin
                            dist1[i][j] <= 6'd63;
                            dist2[i][j] <= 6'd63;
                            dist3[i][j] <= 6'd63;
                        end
                    end
                end
                BFS1, BFS2, BFS3: begin
                    current_state_idx <= state - 2;
                    if (head == 6'd0 && tail == 6'd0 && bfs_timeout == 8'd0) begin
                        // Initialize BFS
                        for (integer i = 0; i < 8; i = i + 1) begin
                            for (integer j = 0; j < 8; j = j + 1) begin
                                if (grid[i][j] == (state - 2'd0)) begin
                                    case (state)
                                        BFS1: dist1[i][j] <= 6'd0;
                                        BFS2: dist2[i][j] <= 6'd0;
                                        BFS3: dist3[i][j] <= 6'd0;
                                    endcase
                                    queue[tail] <= {i[2:0], j[2:0]};
                                    tail <= tail + 1;
                                end
                            end
                        end
                        bfs_timeout <= 8'd1;
                    end else if (head != tail && bfs_timeout < 8'd255) begin
                        // Process BFS
                        if (neighbor_cnt == 3'd0) begin
                            current_cell <= queue[head];
                            head <= head + 1;
                            neighbor_cnt <= 3'd1;
                        end else if (neighbor_cnt <= 3'd4) begin
                            reg [5:0] neighbor;
                            reg [2:0] cell_state;
                            reg [5:0] curr_dist;
                            reg [5:0] new_dist;
                            
                            neighbor = get_neighbor(current_cell, neighbor_cnt[1:0]);
                            if (valid_cell(neighbor)) begin
                                cell_state = grid[neighbor[5:3]][neighbor[2:0]];
                                curr_dist = get_dist(current_cell, state - 2);
                                
                                if (cell_state != 3'd5 && cell_state != 3'd0) begin
                                    new_dist = 6'd63;
                                    if (cell_state == 3'd4) begin
                                        new_dist = curr_dist + 1;
                                    end else if (cell_state == (state - 2'd0)) begin
                                        new_dist = curr_dist;
                                    end else if (cell_state >= 3'd1 && cell_state <= 3'd3 && cell_state != (state - 2'd0)) begin
                                        // Other state - record but don't push
                                        if (curr_dist < get_dist(neighbor, state - 2)) begin
                                            set_dist(neighbor, state - 2, curr_dist);
                                        end
                                        new_dist = 6'd63;
                                    end
                                    
                                    if (new_dist != 6'd63 && new_dist < get_dist(neighbor, state - 2)) begin
                                        set_dist(neighbor, state - 2, new_dist);
                                        if (new_dist == curr_dist) begin
                                            // 0-cost edge to front
                                            if (head != 6'd0) begin
                                                head <= head - 1;
                                                queue[head - 1] <= neighbor;
                                            end
                                        end else begin
                                            // 1-cost edge to back
                                            if (tail < 6'd63) begin
                                                queue[tail] <= neighbor;
                                                tail <= tail + 1;
                                            end
                                        end
                                    end
                                end
                            end
                            neighbor_cnt <= neighbor_cnt + 1;
                        end else begin
                            neighbor_cnt <= 3'd0;
                            bfs_timeout <= bfs_timeout + 1;
                        end
                    end
                end
                COMPUTE: begin
                    if (cell_idx == 6'd0) begin
                        min_total <= 8'd255;
                    end else begin
                        reg [2:0] r, c;
                        reg [5:0] d1, d2, d3;
                        reg [7:0] total;
                        
                        r = cell_idx[5:3];
                        c = cell_idx[2:0];
                        d1 = dist1[r][c];
                        d2 = dist2[r][c];
                        d3 = dist3[r][c];
                        
                        if (d1 != 6'd63 && d2 != 6'd63 && d3 != 6'd63) begin
                            total = {2'd0, d1} + {2'd0, d2} + {2'd0, d3};
                            if (grid[r][c] == 3'd4) begin
                                total = total - 2;
                            end
                            if (total < min_total) begin
                                min_total <= total;
                            end
                        end
                    end
                    cell_idx <= cell_idx + 1;
                end
                FINISH: begin
                    done <= 1;
                    if (min_total < 8'd255) begin
                        valid <= 1;
                        min_roads <= min_total[5:0];
                    end else begin
                        valid <= 0;
                        min_roads <= 6'd63;
                    end
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                next_state = BFS1;
            end
            BFS1: begin
                if (head == tail || bfs_timeout >= 8'd255) next_state = BFS2;
            end
            BFS2: begin
                if (head == tail || bfs_timeout >= 8'd255) next_state = BFS3;
            end
            BFS3: begin
                if (head == tail || bfs_timeout >= 8'd255) next_state = COMPUTE;
            end
            COMPUTE: begin
                if (cell_idx == 6'd63) next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Direction offsets initialization (combinational)
    always @(*) begin
        dr[0] = 3'd0;
        dc[0] = 3'd1;  // right
        dr[1] = 3'd0;
        dc[1] = 3'd7;  // left (-1)
        dr[2] = 3'd1;
        dc[2] = 3'd0;  // down
        dr[3] = 3'd7;
        dc[3] = 3'd0;  // up (-1)
    end

endmodule