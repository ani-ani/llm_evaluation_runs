module three_states (
    input clk,
    input rst_n,
    input start,
    input [191:0] grid_flat,
    output [5:0] min_roads,
    output valid,
    output done
);

    // Internal state encoding
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] BFS1 = 3'd2;
    localparam [2:0] BFS2 = 3'd3;
    localparam [2:0] BFS3 = 3'd4;
    localparam [2:0] COMPUTE = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;

    // Grid storage
    reg [2:0] grid [0:7][0:7];

    // Distance arrays for each state
    reg [5:0] dist1 [0:7][0:7];
    reg [5:0] dist2 [0:7][0:7];
    reg [5:0] dist3 [0:7][0:7];

    // BFS registers
    reg [5:0] queue [0:63];
    reg [5:0] head, tail;
    reg [5:0] current_cell;
    reg [2:0] neighbor_cnt;
    reg [7:0] bfs_timeout;

    // Compute registers
    reg [7:0] min_total;
    reg [5:0] cell_idx;
    reg [7:0] total_cost;

    // Output registers
    reg [5:0] min_roads_reg;
    reg valid_reg;
    reg done_reg;

    assign min_roads = min_roads_reg;
    assign valid = valid_reg;
    assign done = done_reg;

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done_reg <= 1'b0;
            valid_reg <= 1'b0;
            min_roads_reg <= 6'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case(state)
            IDLE: if (start) next_state = LOAD;
            LOAD: next_state = BFS1;
            BFS1: if (head == tail || bfs_timeout == 8'd255) next_state = BFS2;
            BFS2: if (head == tail || bfs_timeout == 8'd255) next_state = BFS3;
            BFS3: if (head == tail || bfs_timeout == 8'd255) next_state = COMPUTE;
            COMPUTE: if (cell_idx == 6'd63) next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State machine implementation
    always @(posedge clk) begin
        if (rst_n) begin
            case(state)
                LOAD: begin
                    // Unpack grid_flat into 8x8 array
                    integer i, j;
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            grid[i][j] <= grid_flat[(i*8+j)*3 +: 3];
                        end
                    end
                    // Initialize all distances to 63 (infinity)
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            dist1[i][j] <= 6'd63;
                            dist2[i][j] <= 6'd63;
                            dist3[i][j] <= 6'd63;
                        end
                    end
                end
                
                BFS1, BFS2, BFS3: begin
                    if (state == BFS1 && head == 5'd0 && tail == 5'd0 && bfs_timeout == 8'd0) begin
                        // Initialize BFS for state 1
                        integer i, j;
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                if (grid[i][j] == 3'd1) begin
                                    dist1[i][j] <= 6'd0;
                                    queue[tail] <= {i[2:0], j[2:0]};
                                    tail <= tail + 1;
                                end
                            end
                        end
                        bfs_timeout <= 8'd0;
                    end else if (state == BFS2 && head == 5'd0 && tail == 5'd0 && bfs_timeout == 8'd0) begin
                        // Initialize BFS for state 2
                        integer i, j;
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                if (grid[i][j] == 3'd2) begin
                                    dist2[i][j] <= 6'd0;
                                    queue[tail] <= {i[2:0], j[2:0]};
                                    tail <= tail + 1;
                                end
                            end
                        end
                        bfs_timeout <= 8'd0;
                    end else if (state == BFS3 && head == 5'd0 && tail == 5'd0 && bfs_timeout == 8'd0) begin
                        // Initialize BFS for state 3
                        integer i, j;
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                if (grid[i][j] == 3'd3) begin
                                    dist3[i][j] <= 6'd0;
                                    queue[tail] <= {i[2:0], j[2:0]};
                                    tail <= tail + 1;
                                end
                            end
                        end
                        bfs_timeout <= 8'd0;
                    end else if (head != tail && bfs_timeout != 8'd255) begin
                        // Process BFS step
                        if (neighbor_cnt == 3'd0) begin
                            current_cell <= queue[head];
                            head <= head + 1;
                            neighbor_cnt <= 3'd1;
                        end else begin
                            // Process neighbors
                            if (neighbor_cnt <= 3'd4) begin
                                reg [5:0] neighbor;
                                reg [2:0] curr_state;
                                reg [5:0] curr_dist;
                                reg [5:0] new_dist;
                                
                                // Get neighbor coordinates
                                reg [2:0] r, c;
                                r = current_cell[5:3];
                                c = current_cell[2:0];
                                
                                case(neighbor_cnt[1:0])
                                    2'd0: c = c + 1;  // right
                                    2'd1: c = c - 1;  // left
                                    2'd2: r = r + 1;  // down
                                    2'd3: r = r - 1;  // up
                                endcase
                                
                                if (r < 8 && c < 8) begin
                                    neighbor = {r, c};
                                    curr_state = grid[r][c];
                                    
                                    // Get current distance based on state
                                    case(state)
                                        BFS1: curr_dist = dist1[r][c];
                                        BFS2: curr_dist = dist2[r][c];
                                        BFS3: curr_dist = dist3[r][c];
                                        default: curr_dist = 6'd63;
                                    endcase
                                    
                                    // Calculate new distance
                                    if (curr_state != 3'd5 && curr_state != 3'd0) begin
                                        if (curr_state == 3'd4) begin  // Road
                                            new_dist = curr_dist + 1;
                                        end else if (curr_state == state - BFS1 + 1) begin  // Same state
                                            new_dist = curr_dist;
                                        end else if (curr_state >= 3'd1 && curr_state <= 3'd3 && curr_state != state - BFS1 + 1) begin  // Other state
                                            // Record distance but don't traverse
                                            if (curr_dist < curr_dist) begin
                                                case(state)
                                                    BFS1: dist1[r][c] <= curr_dist;
                                                    BFS2: dist2[r][c] <= curr_dist;
                                                    BFS3: dist3[r][c] <= curr_dist;
                                                endcase
                                            end
                                            new_dist = 6'd63;
                                        end else begin
                                            new_dist = 6'd63;
                                        end
                                        
                                        if (new_dist != 6'd63 && new_dist < curr_dist) begin
                                            case(state)
                                                BFS1: dist1[r][c] <= new_dist;
                                                BFS2: dist2[r][c] <= new_dist;
                                                BFS3: dist3[r][c] <= new_dist;
                                            endcase
                                            
                                            if (new_dist == curr_dist) begin
                                                // Push to front (0-cost)
                                                if (head != 0) begin
                                                    head <= head - 1;
                                                    queue[head] <= neighbor;
                                                end
                                            end else begin
                                                // Push to back (1-cost)
                                                queue[tail] <= neighbor;
                                                tail <= tail + 1;
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
                end
                
                COMPUTE: begin
                    if (cell_idx == 6'd0) begin
                        min_total <= 8'd255;
                    end else begin
                        // Check current cell
                        reg [2:0] r, c;
                        r = cell_idx[5:3];
                        c = cell_idx[2:0];
                        
                        if (dist1[r][c] != 6'd63 && dist2[r][c] != 6'd63 && dist3[r][c] != 6'd63) begin
                            total_cost = dist1[r][c] + dist2[r][c] + dist3[r][c];
                            if (grid[r][c] == 3'd4) total_cost = total_cost - 2;
                            if (total_cost < min_total) begin
                                min_total <= total_cost;
                            end
                        end
                        
                        cell_idx <= cell_idx + 1;
                    end
                end
                
                FINISH: begin
                    done_reg <= 1'b1;
                    if (min_total < 8'd255) begin
                        valid_reg <= 1'b1;
                        min_roads_reg <= min_total[5:0];
                    end else begin
                        valid_reg <= 1'b0;
                        min_roads_reg <= 6'd63;
                    end
                end
                
                IDLE: begin
                    done_reg <= 1'b0;
                    head <= 5'd0;
                    tail <= 5'd0;
                    neighbor_cnt <= 3'd0;
                    cell_idx <= 6'd0;
                    bfs_timeout <= 8'd0;
                end
            endcase
        end
    end

endmodule