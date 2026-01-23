module forest_growth (
    input clk,
    input rst_n,
    input start,
    input [7:0] heights [0:63],
    input [7:0] speeds [0:63],
    output reg [7:0] max_group_size,
    output reg done
);

    // Parameters
    localparam N = 8;
    localparam GRID_SIZE = N * N;
    localparam NUM_STATES = 5;
    localparam IDLE = 0;
    localparam CHECK_CELL = 1;
    localparam PROPAGATE_COMPONENT = 2;
    localparam UPDATE_MAX = 3;
    localparam DONE_STATE = 4;

    // State machine
    reg [2:0] state;
    reg [2:0] next_state;

    // Visited array (1 bit per cell)
    reg [GRID_SIZE-1:0] visited;

    // BFS queue
    reg [5:0] queue [0:GRID_SIZE-1];
    reg [5:0] queue_head;
    reg [5:0] queue_tail;
    reg [5:0] queue_size;

    // Current component tracking
    reg [5:0] current_root;
    reg [5:0] current_size;
    reg [7:0] current_h;
    reg [7:0] current_v;

    // Counters
    reg [5:0] cell_counter;
    reg [5:0] neighbor_counter;

    // Neighbor offsets (4 directions)
    localparam [5:0] NEIGHBOR_OFFSETS [0:3] = '{0, 1, N, -1, -N};

    // Initialize
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            visited <= 0;
            queue_head <= 0;
            queue_tail <= 0;
            queue_size <= 0;
            current_root <= 0;
            current_size <= 0;
            cell_counter <= 0;
            neighbor_counter <= 0;
            max_group_size <= 0;
            done <= 0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_CELL;
                    visited = 0;
                    cell_counter = 0;
                    max_group_size = 0;
                    done = 0;
                end
            end

            CHECK_CELL: begin
                if (cell_counter < GRID_SIZE) begin
                    if (!visited[cell_counter]) begin
                        // Start new component
                        current_root = cell_counter;
                        current_h = heights[cell_counter];
                        current_v = speeds[cell_counter];
                        current_size = 1;
                        visited[cell_counter] = 1;
                        queue[0] = cell_counter;
                        queue_head = 0;
                        queue_tail = 1;
                        queue_size = 1;
                        neighbor_counter = 0;
                        next_state = PROPAGATE_COMPONENT;
                    end else begin
                        cell_counter = cell_counter + 1;
                    end
                end else begin
                    next_state = DONE_STATE;
                end
            end

            PROPAGATE_COMPONENT: begin
                if (queue_size > 0) begin
                    reg [5:0] current_cell = queue[queue_head];
                    reg [5:0] neighbor_pos;
                    reg [7:0] neighbor_h;
                    reg [7:0] neighbor_v;
                    reg valid_neighbor;

                    if (neighbor_counter < 4) begin
                        neighbor_pos = current_cell + NEIGHBOR_OFFSETS[neighbor_counter];
                        valid_neighbor = (neighbor_pos >= 0) && (neighbor_pos < GRID_SIZE);

                        if (valid_neighbor && !visited[neighbor_pos]) begin
                            neighbor_h = heights[neighbor_pos];
                            neighbor_v = speeds[neighbor_pos];

                            // Check if same (h,v) pair
                            if ((neighbor_h == current_h) && (neighbor_v == current_v)) begin
                                visited[neighbor_pos] = 1;
                                queue[queue_tail] = neighbor_pos;
                                queue_tail = (queue_tail + 1) % GRID_SIZE;
                                queue_size = queue_size + 1;
                                current_size = current_size + 1;
                            end
                        end
                        neighbor_counter = neighbor_counter + 1;
                    end else begin
                        queue_head = (queue_head + 1) % GRID_SIZE;
                        queue_size = queue_size - 1;
                        neighbor_counter = 0;
                    end
                end else begin
                    next_state = UPDATE_MAX;
                end
            end

            UPDATE_MAX: begin
                if (current_size > max_group_size) begin
                    max_group_size = current_size;
                end
                next_state = CHECK_CELL;
                cell_counter = cell_counter + 1;
            end

            DONE_STATE: begin
                done = 1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule