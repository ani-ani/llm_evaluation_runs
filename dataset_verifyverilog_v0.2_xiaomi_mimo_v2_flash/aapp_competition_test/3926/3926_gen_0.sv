module maze_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] grid_size_x,
    input wire [2:0] grid_size_y,
    input wire [2:0] start_x,
    input wire [2:0] start_y,
    input wire [5:0] max_left,
    input wire [5:0] max_right,
    input wire [7:0] grid_data [63:0],
    output reg [6:0] result,
    output reg done
);

    // State definition
    localparam S_IDLE = 3'b000;
    localparam S_PUSH_START = 3'b001;
    localparam S_POP_WAIT = 3'b010;
    localparam S_CHECK_BOUND = 3'b011;
    localparam S_PROCESS = 3'b100;
    localparam S_DONE = 3'b101;

    reg [2:0] state, next_state;

    // Queue pointers (Circular Buffer of 64 entries)
    // We use 6-bit pointers: 0 to 63
    reg [5:0] head_ptr;
    reg [5:0] tail_ptr;
    reg [5:0] next_head_ptr;
    reg [5:0] next_tail_ptr;

    // Queue Memory (30 bits wide: 6x, 6y, 6l, 6r, 6 unused)
    // Using separate arrays for easier indexing logic
    reg [5:0] q_x [63:0];
    reg [5:0] q_y [63:0];
    reg [5:0] q_l [63:0];
    reg [5:0] q_r [63:0];

    // Registers for popped current node
    reg [5:0] curr_x;
    reg [5:0] curr_y;
    reg [5:0] curr_l;
    reg [5:0] curr_r;
    
    // Registers for neighbor processing
    reg [5:0] next_x;
    reg [5:0] next_y;
    reg [5:0] next_l;
    reg [5:0] next_r;
    reg [1:0] neighbor_sel; // 0:Up, 1:Down, 2:Left, 3:Right
    
    // Visited Registers: Stores best (Left, Right) for each cell
    // 12 bits per cell: 6b L, 6b R. Initial value 6'b111111 (max budget - 1) to indicate unvisited if budgets are smaller
    // We'll store best L and R. When checking if we should push, we verify if new state has STRICTLY more budget (or equal L but more R, etc)
    // Actually, standard 0-1 BFS strategy: store max remaining budget. If new path offers better budget, update and push.
    // To detect "better", we need to store best L and R found so far.
    reg [5:0] vis_l [63:0];
    reg [5:0] vis_r [63:0];
    // Initially all 0, but we need to set start node. 
    // We will treat 0 as unvisited OR handle explicitly. Let's use a specific init value or a flag.
    // Since max budget is 63, 63 is valid. Let's use a separate visited flag bit or use -1 logic.
    // Let's use an 'unvisited' flag to avoid ambiguity.
    reg [63:0] visited_flag;

    // Helper wires for index calculation
    wire [5:0] curr_idx;
    assign curr_idx = {curr_y[2:0], curr_x[2:0]}; // Flatten: row * 8 + col. y=row, x=col

    // Neighbors calculation
    reg [5:0] up_y, down_y, left_x, right_x;
    always @(*) begin
        up_y = (curr_y > 0) ? curr_y - 1 : curr_y;
        down_y = (curr_y < grid_size_y - 1) ? curr_y + 1 : curr_y;
        left_x = (curr_x > 0) ? curr_x - 1 : curr_x;
        right_x = (curr_x < grid_size_x - 1) ? curr_x + 1 : curr_x;
    end

    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Main FSM Logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: if (start) next_state = S_PUSH_START;
            S_PUSH_START: next_state = S_POP_WAIT;
            S_POP_WAIT: next_state = S_CHECK_BOUND; // Give 1 cycle for queue read
            S_CHECK_BOUND: begin
                // Check boundary and obstacle
                // Check if curr_x < grid_size_x, curr_y < grid_size_y, grid_data != 0
                if (curr_x < grid_size_x && curr_y < grid_size_y && grid_data[curr_idx] != 0 && visited_flag[curr_idx]) begin
                     // If visited_flag is high (meaning we already visited), we check for better budget later
                     // Actually, for BFS, we usually process only if NOT visited or if visited but better budget.
                     // Since we popped it, it was pushed. We check if it's still valid (better than stored).
                     // If it's not better, we just discard it (don't expand neighbors).
                     // So here we need to check if (curr_l > vis_l[curr_idx] || (curr_l == vis_l[curr_idx] && curr_r > vis_r[curr_idx]))
                     // Since we don't have access to vis registers in combinational block easily without addressing, 
                     // we will check this in S_PROCESS where we can access the array.
                     // For now, basic check:
                     if (grid_data[curr_idx] != 0 && curr_x < grid_size_x && curr_y < grid_size_y)
                        next_state = S_PROCESS;
                     else
                        next_state = S_POP_WAIT; // Invalid cell, pop next
                end else begin
                    next_state = S_POP_WAIT; // Invalid cell (out of bounds), pop next
                end
            end
            S_PROCESS: begin
                // Depending on neighbor_sel, we process neighbors
                if (neighbor_sel < 3) begin
                    next_state = S_PROCESS; // Stay to process next neighbor
                end else begin
                    // Done processing all neighbors for this cell
                    // If queue is not empty, go back to pop. If empty, done.
                    // We need to check queue empty condition here or in S_POP_WAIT
                    next_state = S_POP_WAIT;
                end
            end
            S_DONE: if (!start) next_state = S_IDLE; else next_state = S_DONE; // Wait for start low
        endcase

        // Override for empty queue check
        // We need to check if (head_ptr == tail_ptr) which means empty.
        // But we need to be careful: when popping, we increment head. 
        // If we just popped the last item, head == tail.
        if (state == S_POP_WAIT && head_ptr == tail_ptr) begin
            next_state = S_DONE;
        end
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head_ptr <= 0;
            tail_ptr <= 0;
            result <= 0;
            done <= 0;
            visited_flag <= 64'h0;
            neighbor_sel <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    result <= 0;
                end

                S_PUSH_START: begin
                    // Push start_x, start_y, max_left, max_right to tail
                    q_x[tail_ptr] <= start_x;
                    q_y[tail_ptr] <= start_y;
                    q_l[tail_ptr] <= max_left;
                    q_r[tail_ptr] <= max_right;
                    tail_ptr <= tail_ptr + 1;
                    
                    // Initialize visited for start node
                    // Index calculation for start node
                    visited_flag[start_y * 8 + start_x] <= 1'b1;
                    vis_l[start_y * 8 + start_x] <= max_left;
                    vis_r[start_y * 8 + start_x] <= max_right;
                    
                    // Count start cell
                    result <= 1;
                end

                S_POP_WAIT: begin
                    // Pop from head
                    if (head_ptr != tail_ptr) begin
                        curr_x <= q_x[head_ptr];
                        curr_y <= q_y[head_ptr];
                        curr_l <= q_l[head_ptr];
                        curr_r <= q_r[head_ptr];
                        head_ptr <= head_ptr + 1;
                        neighbor_sel <= 0; // Reset neighbor counter
                    end
                end

                S_PROCESS: begin
                    // Process neighbor specified by neighbor_sel
                    // Check if neighbor improves best state
                    // If yes: Update Visited, Increment Result (if first visit), Push to Queue
                    
                    // Helper logic to determine if we should push
                    // We need to do this inside the case block for neighbor_sel
                    case (neighbor_sel)
                        2'b00: begin // Up
                            // Neighbor: curr_x, up_y
                            if (up_y != curr_y) begin
                                if (visited_flag[up_y * 8 + curr_x]) begin
                                    // Already visited, check if better
                                    // Better: more Left budget (since Up is cost 0 for Left side? No, Up is cost 0 generally)
                                    // But Up/Down allow transfer of full budget. We just need strictly more budget remaining.
                                    // Let's say "Better" if (curr_l > vis_l[idx] || curr_r > vis_r[idx])
                                    // Actually for 0 cost moves, we usually propagate state.
                                    // If we arrived here with (L, R), and stored state is (L_vis, R_vis)
                                    // We push if we have strictly better budget.
                                    if (curr_l > vis_l[up_y * 8 + curr_x] || curr_r > vis_r[up_y * 8 + curr_x]) begin
                                        // Update Visited
                                        vis_l[up_y * 8 + curr_x] <= curr_l;
                                        vis_r[up_y * 8 + curr_x] <= curr_r;
                                        // Push to Front (Cost 0)
                                        // To push to front, we decrement head pointer and write there
                                        // Circular buffer: head = head - 1
                                        // But we just incremented head in POP_WAIT. 
                                        // If we want to push front, we need to write to (head - 1) or (head) and manage pointers carefully.
                                        // Standard 0-1 BFS: Cost 0 -> push to front (decrement head). Cost 1 -> push to back (increment tail).
                                        // Since head was incremented in POP_WAIT, the 'front' of the queue is effectively empty.
                                        // So we can write to (head - 1) and decrement head.
                                        // WARNING: Head pointer manipulation here.
                                        q_x[head_ptr - 1] <= curr_x;
                                        q_y[head_ptr - 1] <= up_y;
                                        q_l[head_ptr - 1] <= curr_l;
                                        q_r[head_ptr - 1] <= curr_r;
                                        head_ptr <= head_ptr - 1;
                                        
                                        if (!visited_flag[up_y * 8 + curr_x]) begin
                                            visited_flag[up_y * 8 + curr_x] <= 1'b1;
                                            result <= result + 1;
                                        end
                                    end
                                end else begin
                                    // Not visited
                                    visited_flag[up_y * 8 + curr_x] <= 1'b1;
                                    vis_l[up_y * 8 + curr_x] <= curr_l;
                                    vis_r[up_y * 8 + curr_x] <= curr_r;
                                    result <= result + 1;
                                    // Push Front
                                    q_x[head_ptr - 1] <= curr_x;
                                    q_y[head_ptr - 1] <= up_y;
                                    q_l[head_ptr - 1] <= curr_l;
                                    q_r[head_ptr - 1] <= curr_r;
                                    head_ptr <= head_ptr - 1;
                                end
                            end
                        end
                        2'b01: begin // Down
                            if (down_y != curr_y) begin
                                if (visited_flag[down_y * 8 + curr_x]) begin
                                    if (curr_l > vis_l[down_y * 8 + curr_x] || curr_r > vis_r[down_y * 8 + curr_x]) begin
                                        vis_l[down_y * 8 + curr_x] <= curr_l;
                                        vis_r[down_y * 8 + curr_x] <= curr_r;
                                        q_x[head_ptr - 1] <= curr_x;
                                        q_y[head_ptr - 1] <= down_y;
                                        q_l[head_ptr - 1] <= curr_l;
                                        q_r[head_ptr - 1] <= curr_r;
                                        head_ptr <= head_ptr - 1;
                                        if (!visited_flag[down_y * 8 + curr_x]) begin
                                            visited_flag[down_y * 8 + curr_x] <= 1'b1;
                                            result <= result + 1;
                                        end
                                    end
                                end else begin
                                    visited_flag[down_y * 8 + curr_x] <= 1'b1;
                                    vis_l[down_y * 8 + curr_x] <= curr_l;
                                    vis_r[down_y * 8 + curr_x] <= curr_r;
                                    result <= result + 1;
                                    q_x[head_ptr - 1] <= curr_x;
                                    q_y[head_ptr - 1] <= down_y;
                                    q_l[head_ptr - 1] <= curr_l;
                                    q_r[head_ptr - 1] <= curr_r;
                                    head_ptr <= head_ptr - 1;
                                end
                            end
                        end
                        2'b10: begin // Left
                            if (left_x != curr_x && curr_l > 0) begin
                                if (visited_flag[curr_y * 8 + left_x]) begin
                                    if ((curr_l - 1) > vis_l[curr_y * 8 + left_x] || curr_r > vis_r[curr_y * 8 + left_x]) begin
                                        vis_l[curr_y * 8 + left_x] <= curr_l - 1;
                                        vis_r[curr_y * 8 + left_x] <= curr_r;
                                        // Push Back (Cost 1)
                                        q_x[tail_ptr] <= left_x;
                                        q_y[tail_ptr] <= curr_y;
                                        q_l[tail_ptr] <= curr_l - 1;
                                        q_r[tail_ptr] <= curr_r;
                                        tail_ptr <= tail_ptr + 1;
                                        if (!visited_flag[curr_y * 8 + left_x]) begin
                                            visited_flag[curr_y * 8 + left_x] <= 1'b1;
                                            result <= result + 1;
                                        end
                                    end
                                end else begin
                                    visited_flag[curr_y * 8 + left_x] <= 1'b1;
                                    vis_l[curr_y * 8 + left_x] <= curr_l - 1;
                                    vis_r[curr_y * 8 + left_x] <= curr_r;
                                    result <= result + 1;
                                    q_x[tail_ptr] <= left_x;
                                    q_y[tail_ptr] <= curr_y;
                                    q_l[tail_ptr] <= curr_l - 1;
                                    q_r[tail_ptr] <= curr_r;
                                    tail_ptr <= tail_ptr + 1;
                                end
                            end
                        end
                        2'b11: begin // Right
                            if (right_x != curr_x && curr_r > 0) begin
                                if (visited_flag[curr_y * 8 + right_x]) begin
                                    if (curr_l > vis_l[curr_y * 8 + right_x] || (curr_r - 1) > vis_r[curr_y * 8 + right_x]) begin
                                        vis_l[curr_y * 8 + right_x] <= curr_l;
                                        vis_r[curr_y * 8 + right_x] <= curr_r - 1;
                                        q_x[tail_ptr] <= right_x;
                                        q_y[tail_ptr] <= curr_y;
                                        q_l[tail_ptr] <= curr_l;
                                        q_r[tail_ptr] <= curr_r - 1;
                                        tail_ptr <= tail_ptr + 1;
                                        if (!visited_flag[curr_y * 8 + right_x]) begin
                                            visited_flag[curr_y * 8 + right_x] <= 1'b1;
                                            result <= result + 1;
                                        end
                                    end
                                end else begin
                                    visited_flag[curr_y * 8 + right_x] <= 1'b1;
                                    vis_l[curr_y * 8 + right_x] <= curr_l;
                                    vis_r[curr_y * 8 + right_x] <= curr_r - 1;
                                    result <= result + 1;
                                    q_x[tail_ptr] <= right_x;
                                    q_y[tail_ptr] <= curr_y;
                                    q_l[tail_ptr] <= curr_l;
                                    q_r[tail_ptr] <= curr_r - 1;
                                    tail_ptr <= tail_ptr + 1;
                                end
                            end
                        end
                    endcase
                    
                    neighbor_sel <= neighbor_sel + 1;
                end

                S_DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule