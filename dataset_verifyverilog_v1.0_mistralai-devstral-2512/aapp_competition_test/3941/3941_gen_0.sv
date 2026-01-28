module door_unlock_checker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] door_status,
    input wire [255:0] switch_ctrl,
    input wire [3:0] room_index,
    input wire load_room,
    output reg result,
    output reg done
);

    // Parameters
    localparam [3:0] MAX_SWITCHES = 4'd16;
    localparam [3:0] MAX_ROOMS = 4'd16;
    localparam [9:0] MAX_CYCLES = 10'd1000;
    localparam [3:0] QUEUE_SIZE = 4'd16;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Registers
    reg [2:0] state, next_state;
    reg [9:0] cycle_count;
    reg [3:0] current_switch;
    reg [3:0] queue_head, queue_tail;
    reg [3:0] queue [0:QUEUE_SIZE-1];
    reg [15:0][15:0] adjacency_matrix;
    reg [15:0] visited;
    reg [15:0] color;
    reg conflict_detected;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            current_switch <= 4'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            conflict_detected <= 1'b0;

            // Initialize adjacency matrix
            integer i, j;
            for (i = 0; i < MAX_SWITCHES; i = i + 1) begin
                for (j = 0; j < MAX_SWITCHES; j = j + 1) begin
                    adjacency_matrix[i][j] <= 1'b0;
                end
            end

            // Initialize visited and color
            for (i = 0; i < MAX_SWITCHES; i = i + 1) begin
                visited[i] <= 1'b0;
                color[i] <= 1'b0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;

            // Queue management
            if (queue_head != queue_tail) begin
                current_switch <= queue[queue_head];
                queue_head <= queue_head + 4'd1;
            end

            // Conflict detection
            if (conflict_detected) begin
                result <= 1'b0;
            end

            // Cycle count check
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= FINISH;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                if (load_room) begin
                    // Update adjacency matrix based on room_index
                    integer i, j;
                    reg [7:0] switch_indices [0:1];
                    reg [1:0] switch_count;

                    // Find the two set bits in switch_ctrl
                    switch_count = 2'd0;
                    for (i = 0; i < 256; i = i + 1) begin
                        if (switch_ctrl[i] && switch_count < 2'd2) begin
                            switch_indices[switch_count] = i;
                            switch_count = switch_count + 2'd1;
                        end
                    end

                    // Update adjacency matrix
                    if (switch_count == 2'd2) begin
                        adjacency_matrix[switch_indices[0]][switch_indices[1]] = door_status[room_index];
                        adjacency_matrix[switch_indices[1]][switch_indices[0]] = door_status[room_index];
                    end
                end

                // Check if all rooms are loaded (simplified for this example)
                // In a real implementation, you'd need a counter or other mechanism
                next_state = COMPUTE;
            end

            COMPUTE: begin
                if (!conflict_detected) begin
                    if (current_switch < MAX_SWITCHES && !visited[current_switch]) begin
                        // Start BFS from current_switch
                        visited[current_switch] = 1'b1;
                        color[current_switch] = 1'b0;
                        queue[queue_tail] = current_switch;
                        queue_tail = queue_tail + 4'd1;
                    end else if (queue_head == queue_tail) begin
                        // Check if all switches are visited
                        reg all_visited;
                        integer i;
                        all_visited = 1'b1;
                        for (i = 0; i < MAX_SWITCHES; i = i + 1) begin
                            if (!visited[i]) begin
                                all_visited = 1'b0;
                            end
                        end

                        if (all_visited) begin
                            result = 1'b1;
                            next_state = FINISH;
                        end else begin
                            current_switch = current_switch + 4'd1;
                        end
                    end else begin
                        // Process current_switch from queue
                        integer neighbor;
                        for (neighbor = 0; neighbor < MAX_SWITCHES; neighbor = neighbor + 1) begin
                            if (adjacency_matrix[current_switch][neighbor]) begin
                                if (!visited[neighbor]) begin
                                    visited[neighbor] = 1'b1;
                                    color[neighbor] = color[current_switch];
                                    queue[queue_tail] = neighbor;
                                    queue_tail = queue_tail + 4'd1;
                                end else if (color[neighbor] != color[current_switch]) begin
                                    conflict_detected = 1'b1;
                                end
                            end else if (current_switch != neighbor && adjacency_matrix[current_switch][neighbor] === 1'b0) begin
                                if (!visited[neighbor]) begin
                                    visited[neighbor] = 1'b1;
                                    color[neighbor] = ~color[current_switch];
                                    queue[queue_tail] = neighbor;
                                    queue_tail = queue_tail + 4'd1;
                                end else if (color[neighbor] == color[current_switch]) begin
                                    conflict_detected = 1'b1;
                                end
                            end
                        end
                    end
                end else begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule