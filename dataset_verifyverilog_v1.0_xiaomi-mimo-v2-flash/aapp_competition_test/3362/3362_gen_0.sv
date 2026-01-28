module LavaPathfinding(
    input clk,
    input rst_n,
    input start,
    input [7:0] step_elsa,
    input [7:0] step_father,
    input [7:0] map_in,
    input [7:0] map_addr,
    input map_write,
    output reg [1:0] result,
    output reg done
);

    // Grid data encoding
    localparam [1:0] CELL_S = 2'd0;
    localparam [1:0] CELL_W = 2'd1;
    localparam [1:0] CELL_G = 2'd2;
    localparam [1:0] CELL_B = 2'd3;

    // Result encoding
    localparam [1:0] RES_NO_WAY = 2'd0;
    localparam [1:0] RES_SUCCESS = 2'd1;
    localparam [1:0] RES_GO_FOR_IT = 2'd2;
    localparam [1:0] RES_NO_CHANCE = 2'd3;

    // FSM States
    localparam [2:0] STATE_IDLE = 3'd0;
    localparam [2:0] STATE_LOAD = 3'd1;
    localparam [2:0] STATE_COMPUTE = 3'd2;
    localparam [2:0] STATE_DONE = 3'd3;

    reg [2:0] state, next_state;

    // Map Storage (256x2 BRAM)
    reg [1:0] map_storage [0:255];
    reg [7:0] load_addr;
    reg loading_done;

    // BFS Signals
    reg bfs_start;
    wire bfs_done;
    wire bfs_found;
    wire [3:0] bfs_depth;
    wire [1:0] bfs_who; // 0: Elsa, 1: Father
    reg [1:0] bfs_instance;
    reg bfs_instance_next;
    reg [3:0] depth_elsa_reg;
    reg [3:0] depth_father_reg;
    reg found_elsa_reg;
    reg found_father_reg;

    // Neighbor Check Signals
    reg [3:0] curr_x;
    reg [3:0] curr_y;
    reg [3:0] check_x;
    reg [3:0] check_y;
    reg [3:0] dx;
    reg [3:0] dy;
    reg signed [7:0] dist_sq; // Max 450, fits in 9 bits
    reg [1:0] neighbor_state;
    reg neighbor_valid;
    reg [2:0] iter_x;
    reg [2:0] iter_y;
    reg [2:0] check_step;

    // BFS Internal Logic
    reg [7:0] visited [0:255];
    reg [7:0] queue [0:255];
    reg [7:0] q_head;
    reg [7:0] q_tail;
    reg [7:0] q_count;
    reg [7:0] cells_processed;
    reg [3:0] current_depth;
    reg [7:0] depth_count;
    reg [7:0] next_depth_count;
    reg bfs_busy;

    // Cycle counter for timeout
    reg [15:0] cycle_counter;

    // Initialize map storage with 'B' (invalid)
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            map_storage[i] = CELL_B;
        end
    end

    // State Machine Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            done <= 1'b0;
            result <= 2'd0;
            load_addr <= 8'd0;
            loading_done <= 1'b0;
            bfs_start <= 1'b0;
            bfs_instance <= 2'd0;
            depth_elsa_reg <= 4'd0;
            depth_father_reg <= 4'd0;
            found_elsa_reg <= 1'b0;
            found_father_reg <= 1'b0;
            cycle_counter <= 16'd0;
        end else begin
            state <= next_state;
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 16'd0;
                    if (start) begin
                        load_addr <= 8'd0;
                        loading_done <= 1'b0;
                        // Reset BFS results
                        found_elsa_reg <= 1'b0;
                        found_father_reg <= 1'b0;
                        depth_elsa_reg <= 4'd15;
                        depth_father_reg <= 4'd15;
                        bfs_start <= 1'b0;
                    end
                end
                STATE_LOAD: begin
                    if (map_write) begin
                        map_storage[map_addr] <= map_in[1:0];
                        // If map_addr is 255, loading might be complete
                    end
                    // Assuming external controller sends all data or we rely on map_write pulses
                    // Here we assume if map_write is 0 for a cycle, we proceed if loading was triggered
                    if (map_write == 1'b0 && !loading_done) begin
                        loading_done <= 1'b1;
                    end
                end
                STATE_COMPUTE: begin
                    cycle_counter <= cycle_counter + 1'b1;
                    // Start BFS if not busy
                    if (!bfs_busy && !bfs_start) begin
                        if (bfs_instance == 2'd0 && !found_elsa_reg) begin
                            bfs_start <= 1'b1;
                        end else if (bfs_instance == 2'd1 && !found_father_reg) begin
                            bfs_start <= 1'b1;
                        end else begin
                            // Move to next instance or finish
                            if (bfs_instance == 2'd1 && found_father_reg) begin
                                // Done with Father
                            end
                        end
                    end else begin
                        bfs_start <= 1'b0;
                    end
                    
                    // Capture BFS results
                    if (bfs_done && bfs_found) begin
                        if (bfs_instance == 2'd0) begin
                            found_elsa_reg <= 1'b1;
                            depth_elsa_reg <= bfs_depth;
                        end else begin
                            found_father_reg <= 1'b1;
                            depth_father_reg <= bfs_depth;
                        end
                    end
                end
                STATE_DONE: begin
                    done <= 1'b1;
                    // Calculate result
                    if (found_elsa_reg && found_father_reg) begin
                        if (depth_elsa_reg == depth_father_reg) begin
                            result <= RES_SUCCESS;
                        end else if (depth_elsa_reg < depth_father_reg) begin
                            result <= RES_GO_FOR_IT;
                        end else begin
                            result <= RES_NO_CHANCE;
                        end
                    end else if (found_elsa_reg) begin
                        result <= RES_GO_FOR_IT;
                    end else if (found_father_reg) begin
                        result <= RES_NO_CHANCE;
                    end else begin
                        result <= RES_NO_WAY;
                    end
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            STATE_IDLE: begin
                if (start) next_state = STATE_LOAD;
            end
            STATE_LOAD: begin
                // Transition to compute when loading is done
                // For simplicity, assume start goes low, then we move on
                if (loading_done || !map_write) next_state = STATE_COMPUTE;
            end
            STATE_COMPUTE: begin
                // Check termination conditions
                // 1. Both found or unreachable
                // 2. Timeout
                if (cycle_counter > 16'd50000) next_state = STATE_DONE;
                else if (found_elsa_reg && found_father_reg) next_state = STATE_DONE;
                else if (found_elsa_reg && bfs_instance == 2'd1 && bfs_done && !bfs_found) next_state = STATE_DONE; // Father done, not found
                else if (found_father_reg && bfs_instance == 2'd0 && bfs_done && !bfs_found) next_state = STATE_DONE; // Elsa done, not found
                else if (bfs_instance == 2'd1 && bfs_done && !found_elsa_reg) next_state = STATE_DONE; // Elsa failed
                else if (bfs_instance == 2'd0 && bfs_done && !found_father_reg) next_state = STATE_DONE; // Father failed
            end
            STATE_DONE: begin
                if (done) next_state = STATE_IDLE;
            end
            default: next_state = STATE_IDLE;
        endcase
    end

    // BFS Control Logic (Simplified for Verilog)
    // This logic drives the BFS state machine below
    reg bfs_rst;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bfs_busy <= 1'b0;
            bfs_instance <= 2'd0;
        end else begin
            if (state == STATE_IDLE) begin
                bfs_busy <= 1'b0;
                bfs_instance <= 2'd0;
            end else if (state == STATE_COMPUTE) begin
                if (bfs_start && !bfs_busy) begin
                    bfs_busy <= 1'b1;
                    bfs_rst <= 1'b1;
                end else if (bfs_busy && bfs_done) begin
                    bfs_busy <= 1'b0;
                    bfs_rst <= 1'b0;
                    // Switch instance
                    if (bfs_instance == 2'd0) begin
                        if (found_elsa_reg || !bfs_found) bfs_instance <= 2'd1;
                        // If Elsa found, we proceed to Father
                        // If Elsa failed, we still check Father (logic above handles done)
                        if (!found_elsa_reg && bfs_found) bfs_instance <= 2'd1; // Elsa found, go to Father
                    end else begin
                        // Father done
                    end
                end else begin
                    bfs_rst <= 1'b0;
                end
            end
        end
    end

    // Neighbor Check Combinational Logic
    // Calculates if neighbor (curr_x + iter_x - 1, curr_y + iter_y - 1) is valid
    always @(*) begin
        check_x = curr_x + iter_x - 1;
        check_y = curr_y + iter_y - 1;
        
        // Check bounds
        if (check_x < 16 && check_y < 16) begin
            neighbor_state = map_storage[{check_y, check_x}];
            // Check cell type
            if (neighbor_state == CELL_W || neighbor_state == CELL_G) begin
                // Check distance
                dx = (check_x > curr_x) ? (check_x - curr_x) : (curr_x - check_x);
                dy = (check_y > curr_y) ? (check_y - curr_y) : (curr_y - check_y);
                
                if (bfs_instance == 2'd0) begin
                    // Elsa: Euclidean squared <= step^2
                    dist_sq = (dx * dx) + (dy * dy);
                    // step_elsa is scaled. Assuming direct comparison for simplicity or scaled input.
                    // If step_elsa is squared distance limit:
                    if (dist_sq <= step_elsa) begin
                        neighbor_valid = 1'b1;
                    end else begin
                        neighbor_valid = 1'b0;
                    end
                end else begin
                    // Father: Manhattan <= step_father
                    if ((dx + dy) <= step_father) begin
                        neighbor_valid = 1'b1;
                    end else begin
                        neighbor_valid = 1'b0;
                    end
                end
            end else begin
                neighbor_valid = 1'b0;
            end
        end else begin
            neighbor_valid = 1'b0;
        end
    end

    // BFS Inner State Machine
    localparam [2:0] BFS_IDLE = 3'd0;
    localparam [2:0] BFS_READ_CELL = 3'd1;
    localparam [2:0] BFS_CHECK_NEIGHBORS = 3'd2;
    localparam [2:0] BFS_POP = 3'd3;
    localparam [2:0] BFS_FINISHED = 3'd4;

    reg [2:0] bfs_state, bfs_next_state;
    reg [7:0] current_cell;
    reg [3:0] temp_x, temp_y;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bfs_state <= BFS_IDLE;
        end else begin
            bfs_state <= bfs_next_state;
        end
    end

    // BFS Logic
    always @(*) begin
        bfs_next_state = bfs_state;
        bfs_done = 1'b0;
        bfs_found = 1'b0;
        bfs_depth = 4'd0;
        
        case (bfs_state)
            BFS_IDLE: begin
                if (bfs_rst) begin
                    bfs_next_state = BFS_READ_CELL;
                end
            end
            BFS_READ_CELL: begin
                if (q_count == 0) begin
                    bfs_next_state = BFS_FINISHED; // No path
                end else begin
                    bfs_next_state = BFS_CHECK_NEIGHBORS;
                end
            end
            BFS_CHECK_NEIGHBORS: begin
                // Iterate through 3x3 neighbors (including current, which is skipped)
                if (iter_x == 3'd3 && iter_y == 3'd3) begin
                    bfs_next_state = BFS_POP;
                end
            end
            BFS_POP: begin
                if (q_count == 0) begin
                     // If queue empty and we haven't found G, go to FINISHED (No path)
                     // But if depth_count > 0, we processed a level. 
                     // The loop logic handles transition to next level.
                end
                // Move to next cell in current level
                if (depth_count == 8'd1) begin
                    // Level finished
                    if (q_count == 0) begin
                        bfs_next_state = BFS_FINISHED;
                    end else begin
                        bfs_next_state = BFS_READ_CELL;
                    end
                end else begin
                    bfs_next_state = BFS_READ_CELL;
                end
            end
            BFS_FINISHED: begin
                bfs_done = 1'b1;
                // bfs_found is set based on logic below
            end
            default: bfs_next_state = BFS_IDLE;
        endcase
    end

    // BFS Data Path
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_head <= 8'd0;
            q_tail <= 8'd0;
            q_count <= 8'd0;
            cells_processed <= 8'd0;
            depth_count <= 8'd0;
            current_depth <= 4'd0;
            iter_x <= 3'd0;
            iter_y <= 3'd0;
            for (i = 0; i < 256; i = i + 1) visited[i] <= 8'd0;
        end else begin
            if (bfs_rst) begin
                // Reset for new BFS
                q_head <= 8'd0;
                q_tail <= 8'd0;
                q_count <= 8'd0;
                current_depth <= 4'd0;
                depth_count <= 8'd0;
                cells_processed <= 8'd0;
                iter_x <= 3'd0;
                iter_y <= 3'd0;
                for (i = 0; i < 256; i = i + 1) visited[i] <= 8'd0;
                
                // Find Start Position
                temp_x = 4'd0;
                temp_y = 4'd0;
                for (i = 0; i < 256; i = i + 1) begin
                    if (map_storage[i] == CELL_S) begin
                        temp_x = i[3:0];
                        temp_y = i[7:4];
                    end
                end
                
                // Enqueue Start
                queue[0] <= {temp_y, temp_x};
                q_tail <= 8'd1;
                q_count <= 8'd1;
                visited[{temp_y, temp_x}] <= 1'b1;
                depth_count <= 8'd1; // 1 cell in first level
                current_depth <= 4'd0;
            end else begin
                case (bfs_state)
                    BFS_READ_CELL: begin
                        if (q_count > 0) begin
                            current_cell <= queue[q_head];
                            curr_y <= queue[q_head][7:4];
                            curr_x <= queue[q_head][3:0];
                            iter_x <= 3'd0;
                            iter_y <= 3'd0;
                        end
                    end
                    BFS_CHECK_NEIGHBORS: begin
                        // Increment iterators
                        if (iter_x < 3'd3) begin
                            iter_x <= iter_x + 1'b1;
                        end else begin
                            iter_x <= 3'd0;
                            iter_y <= iter_y + 1'b1;
                        end
                        
                        // Check neighbor validity
                        if (neighbor_valid && !(check_x == curr_x && check_y == curr_y)) begin
                            if (visited[{check_y, check_x}] == 1'b0) begin
                                visited[{check_y, check_x}] <= 1'b1;
                                // Enqueue
                                queue[q_tail] <= {check_y, check_x};
                                q_tail <= q_tail + 1'b1;
                                q_count <= q_count + 1'b1;
                                
                                // Check for Goal
                                if (map_storage[{check_y, check_x}] == CELL_G) begin
                                    bfs_found <= 1'b1;
                                    bfs_depth <= current_depth + 1'b1;
                                end
                            end
                        end
                    end
                    BFS_POP: begin
                        q_head <= q_head + 1'b1;
                        q_count <= q_count - 1'b1;
                        cells_processed <= cells_processed + 1'b1;
                        
                        if (depth_count > 8'd1) begin
                            depth_count <= depth_count - 1'b1;
                        end else begin
                            // End of level
                            current_depth <= current_depth + 1'b1;
                            depth_count <= q_count - 1'b1; // Remaining items in queue are next level
                        end
                    end
                endcase
            end
        end
    end

endmodule