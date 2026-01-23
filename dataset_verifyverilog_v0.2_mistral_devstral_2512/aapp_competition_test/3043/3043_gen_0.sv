module treasure_hunter (
    input clk,
    input rst_n,
    input start,
    input [5:0] grid [0:63],
    input [5:0] K,
    output reg [5:0] days,
    output reg [5:0] visited_count,
    output reg done,
    output reg impossible
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        FIND_S,
        INIT_DAY,
        PROCESS_DAY,
        CHECK_SUCCESS,
        INCREMENT_DAY,
        DONE,
        IMPOSSIBLE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [5:0] current_days;
    reg [5:0] current_stamina;
    reg [2:0] current_row, current_col;
    reg [2:0] start_row, start_col;
    reg [5:0] queue [0:63];
    reg [5:0] next_queue [0:63];
    reg [5:0] queue_ptr, next_queue_ptr;
    reg [5:0] queue_size, next_queue_size;
    reg [5:0] visited [0:63];
    reg [5:0] visited_ptr;
    reg found_G;
    reg [5:0] temp_visited_count;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            current_days <= 0;
            current_stamina <= 0;
            current_row <= 0;
            current_col <= 0;
            start_row <= 0;
            start_col <= 0;
            queue_ptr <= 0;
            next_queue_ptr <= 0;
            queue_size <= 0;
            next_queue_size <= 0;
            visited_ptr <= 0;
            found_G <= 0;
            temp_visited_count <= 0;
            days <= 0;
            visited_count <= 0;
            done <= 0;
            impossible <= 0;
        end else begin
            current_state <= next_state;
            if (current_state == FIND_S) begin
                if (grid[visited_ptr] == 6'h53) begin
                    start_row <= visited_ptr[5:3];
                    start_col <= visited_ptr[2:0];
                    next_state <= INIT_DAY;
                end else if (visited_ptr == 63) begin
                    next_state <= IMPOSSIBLE;
                end else begin
                    visited_ptr <= visited_ptr + 1;
                end
            end else if (current_state == INIT_DAY) begin
                queue[0] <= {start_row, start_col};
                queue_size <= 1;
                queue_ptr <= 0;
                next_queue_size <= 0;
                next_queue_ptr <= 0;
                current_stamina <= K;
                current_days <= 0;
                temp_visited_count <= 1;
                visited[0] <= {start_row, start_col};
                next_state <= PROCESS_DAY;
            end else if (current_state == PROCESS_DAY) begin
                if (queue_ptr < queue_size) begin
                    current_row <= queue[queue_ptr][5:3];
                    current_col <= queue[queue_ptr][2:0];
                    queue_ptr <= queue_ptr + 1;
                end else begin
                    next_state <= CHECK_SUCCESS;
                end
            end else if (current_state == CHECK_SUCCESS) begin
                if (found_G) begin
                    days <= current_days;
                    visited_count <= temp_visited_count;
                    next_state <= DONE;
                end else if (next_queue_size == 0) begin
                    next_state <= IMPOSSIBLE;
                end else begin
                    next_state <= INCREMENT_DAY;
                end
            end else if (current_state == INCREMENT_DAY) begin
                current_days <= current_days + 1;
                queue_size <= next_queue_size;
                queue_ptr <= 0;
                next_queue_size <= 0;
                next_queue_ptr <= 0;
                current_stamina <= K;
                next_state <= PROCESS_DAY;
            end else if (current_state == DONE) begin
                done <= 1;
            end else if (current_state == IMPOSSIBLE) begin
                impossible <= 1;
            end
        end
    end

    // Process neighbors
    always @(posedge clk) begin
        if (current_state == PROCESS_DAY && queue_ptr < queue_size) begin
            reg [2:0] new_row, new_col;
            reg [5:0] cell_type;
            reg [5:0] stamina_cost;
            reg [5:0] new_pos;

            // Check all four directions
            for (int i = 0; i < 4; i++) begin
                case (i)
                    0: begin // Up
                        new_row = current_row - 1;
                        new_col = current_col;
                    end
                    1: begin // Down
                        new_row = current_row + 1;
                        new_col = current_col;
                    end
                    2: begin // Left
                        new_row = current_row;
                        new_col = current_col - 1;
                    end
                    3: begin // Right
                        new_row = current_row;
                        new_col = current_col + 1;
                    end
                endcase

                // Check boundaries
                if (new_row < 8 && new_col < 8) begin
                    new_pos = {new_row, new_col};
                    cell_type = grid[new_pos];

                    // Check if cell is not blocked and not visited
                    if (cell_type != 6'h23) begin
                        reg visited_flag = 0;
                        for (int j = 0; j < temp_visited_count; j++) begin
                            if (visited[j] == new_pos) begin
                                visited_flag = 1;
                            end
                        end

                        if (!visited_flag) begin
                            case (cell_type)
                                6'h2E: stamina_cost = 1;
                                6'h46: stamina_cost = 2;
                                6'h4D: stamina_cost = 3;
                                default: stamina_cost = 0;
                            endcase

                            if (current_stamina >= stamina_cost) begin
                                // Add to current queue
                                queue[queue_size] <= new_pos;
                                queue_size <= queue_size + 1;
                                current_stamina <= current_stamina - stamina_cost;
                                visited[temp_visited_count] <= new_pos;
                                temp_visited_count <= temp_visited_count + 1;

                                if (cell_type == 6'h47) begin
                                    found_G <= 1;
                                end
                            end else begin
                                // Add to next queue
                                next_queue[next_queue_size] <= new_pos;
                                next_queue_size <= next_queue_size + 1;
                                visited[temp_visited_count] <= new_pos;
                                temp_visited_count <= temp_visited_count + 1;

                                if (cell_type == 6'h47) begin
                                    found_G <= 1;
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    // Start signal handling
    always @(posedge clk) begin
        if (start && current_state == IDLE) begin
            next_state <= FIND_S;
            visited_ptr <= 0;
            found_G <= 0;
            temp_visited_count <= 0;
            done <= 0;
            impossible <= 0;
        end
    end

endmodule