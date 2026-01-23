module maze_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] grid_size_x,
    input [2:0] grid_size_y,
    input [2:0] start_x,
    input [2:0] start_y,
    input [5:0] max_left,
    input [5:0] max_right,
    input [7:0] grid_data [63:0],
    output reg [6:0] result,
    output reg done
);

    // Parameters
    localparam MAX_CELLS = 64;
    localparam QUEUE_SIZE = 64;

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        PUSH_START,
        PROCESS_LOOP,
        DONE
    } state_t;

    // Queue structure
    typedef struct {
        logic [2:0] x;
        logic [2:0] y;
        logic [5:0] left_budget;
        logic [5:0] right_budget;
    } queue_entry_t;

    // Visited structure
    typedef struct {
        logic [5:0] best_left;
        logic [5:0] best_right;
        logic valid;
    } visited_entry_t;

    // State registers
    state_t current_state, next_state;
    logic [5:0] queue_head, queue_tail;
    logic [5:0] queue_count;
    queue_entry_t queue [QUEUE_SIZE];
    visited_entry_t visited [8][8];
    logic [6:0] reachable_count;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            queue_head <= 0;
            queue_tail <= 0;
            queue_count <= 0;
            reachable_count <= 0;
            done <= 0;
            result <= 0;
            // Initialize visited array
            for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < 8; j++) begin
                    visited[i][j].valid <= 0;
                    visited[i][j].best_left <= 0;
                    visited[i][j].best_right <= 0;
                end
            end
        end else begin
            current_state <= next_state;
            if (current_state == PUSH_START) begin
                queue_head <= 0;
                queue_tail <= 1;
                queue_count <= 1;
                queue[0].x <= start_x;
                queue[0].y <= start_y;
                queue[0].left_budget <= max_left;
                queue[0].right_budget <= max_right;
                visited[start_x][start_y].valid <= 1;
                visited[start_x][start_y].best_left <= max_left;
                visited[start_x][start_y].best_right <= max_right;
                reachable_count <= 1;
            end else if (current_state == PROCESS_LOOP) begin
                if (queue_count > 0) begin
                    queue_entry_t current = queue[queue_head];
                    logic [2:0] x = current.x;
                    logic [2:0] y = current.y;
                    logic [5:0] left = current.left_budget;
                    logic [5:0] right = current.right_budget;

                    // Process neighbors
                    // Up (cost 0)
                    if (x > 0 && grid_data[(x-1)*8 + y] == 1) begin
                        if (!visited[x-1][y].valid || 
                            (left > visited[x-1][y].best_left || 
                             (left == visited[x-1][y].best_left && right > visited[x-1][y].best_right))) begin
                            // Push to front
                            if (queue_count < QUEUE_SIZE) begin
                                queue_tail = (queue_tail == 0) ? QUEUE_SIZE-1 : queue_tail - 1;
                                queue[queue_tail].x = x-1;
                                queue[queue_tail].y = y;
                                queue[queue_tail].left_budget = left;
                                queue[queue_tail].right_budget = right;
                                queue_count = queue_count + 1;
                                visited[x-1][y].valid = 1;
                                visited[x-1][y].best_left = left;
                                visited[x-1][y].best_right = right;
                                reachable_count = reachable_count + 1;
                            end
                        end
                    end

                    // Down (cost 0)
                    if (x < grid_size_x-1 && grid_data[(x+1)*8 + y] == 1) begin
                        if (!visited[x+1][y].valid || 
                            (left > visited[x+1][y].best_left || 
                             (left == visited[x+1][y].best_left && right > visited[x+1][y].best_right))) begin
                            // Push to front
                            if (queue_count < QUEUE_SIZE) begin
                                queue_tail = (queue_tail == 0) ? QUEUE_SIZE-1 : queue_tail - 1;
                                queue[queue_tail].x = x+1;
                                queue[queue_tail].y = y;
                                queue[queue_tail].left_budget = left;
                                queue[queue_tail].right_budget = right;
                                queue_count = queue_count + 1;
                                visited[x+1][y].valid = 1;
                                visited[x+1][y].best_left = left;
                                visited[x+1][y].best_right = right;
                                reachable_count = reachable_count + 1;
                            end
                        end
                    end

                    // Left (cost 1)
                    if (y > 0 && grid_data[x*8 + (y-1)] == 1 && left > 0) begin
                        if (!visited[x][y-1].valid || 
                            (left-1 > visited[x][y-1].best_left || 
                             (left-1 == visited[x][y-1].best_left && right > visited[x][y-1].best_right))) begin
                            // Push to back
                            if (queue_count < QUEUE_SIZE) begin
                                queue[queue_tail].x = x;
                                queue[queue_tail].y = y-1;
                                queue[queue_tail].left_budget = left-1;
                                queue[queue_tail].right_budget = right;
                                queue_tail = (queue_tail == QUEUE_SIZE-1) ? 0 : queue_tail + 1;
                                queue_count = queue_count + 1;
                                visited[x][y-1].valid = 1;
                                visited[x][y-1].best_left = left-1;
                                visited[x][y-1].best_right = right;
                                reachable_count = reachable_count + 1;
                            end
                        end
                    end

                    // Right (cost 1)
                    if (y < grid_size_y-1 && grid_data[x*8 + (y+1)] == 1 && right > 0) begin
                        if (!visited[x][y+1].valid || 
                            (right-1 > visited[x][y+1].best_right || 
                             (right-1 == visited[x][y+1].best_right && left > visited[x][y+1].best_left))) begin
                            // Push to back
                            if (queue_count < QUEUE_SIZE) begin
                                queue[queue_tail].x = x;
                                queue[queue_tail].y = y+1;
                                queue[queue_tail].left_budget = left;
                                queue[queue_tail].right_budget = right-1;
                                queue_tail = (queue_tail == QUEUE_SIZE-1) ? 0 : queue_tail + 1;
                                queue_count = queue_count + 1;
                                visited[x][y+1].valid = 1;
                                visited[x][y+1].best_left = left;
                                visited[x][y+1].best_right = right-1;
                                reachable_count = reachable_count + 1;
                            end
                        end
                    end

                    // Pop from queue
                    queue_head = (queue_head == QUEUE_SIZE-1) ? 0 : queue_head + 1;
                    queue_count = queue_count - 1;
                end
            end else if (current_state == DONE) begin
                done <= 1;
                result <= reachable_count;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = PUSH_START;
            end
            PUSH_START: begin
                next_state = PROCESS_LOOP;
            end
            PROCESS_LOOP: begin
                if (queue_count == 0) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

endmodule