module badge_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] s_room,
    input wire [3:0] d_room,
    input wire [4:0] lock_count,
    input wire lock_config_valid,
    input wire [3:0] lock_from,
    input wire [3:0] lock_to,
    input wire [15:0] lock_min,
    input wire [15:0] lock_max,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CONFIG    = 3'd1;
    localparam [2:0] PROCESS   = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;

    // Lock storage (32 entries)
    reg [3:0] lock_from_mem [0:31];
    reg [3:0] lock_to_mem [0:31];
    reg [15:0] lock_min_mem [0:31];
    reg [15:0] lock_max_mem [0:31];

    // Configuration counter
    reg [4:0] config_idx;

    // Processing variables
    reg [15:0] badge_id;
    reg [15:0] valid_count;

    // BFS variables
    reg [3:0] queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg [15:0] visited;

    // Ready signal control
    reg ready_internal;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            config_idx <= 5'd0;
            badge_id <= 16'd0;
            valid_count <= 16'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            visited <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            ready_internal <= 1'b1;

            // Initialize lock memory
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                lock_from_mem[i] <= 4'd0;
                lock_to_mem[i] <= 4'd0;
                lock_min_mem[i] <= 16'd0;
                lock_max_mem[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && ready_internal) begin
                    next_state = PROCESS;
                end else if (lock_config_valid && ready_internal) begin
                    next_state = CONFIG;
                end else begin
                    next_state = IDLE;
                end
            end

            CONFIG: begin
                if (config_idx == lock_count) begin
                    next_state = IDLE;
                end else begin
                    next_state = CONFIG;
                end
            end

            PROCESS: begin
                if (badge_id == 16'd65535) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = PROCESS;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Configuration logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            config_idx <= 5'd0;
        end else if (state == CONFIG && lock_config_valid) begin
            lock_from_mem[config_idx] <= lock_from;
            lock_to_mem[config_idx] <= lock_to;
            lock_min_mem[config_idx] <= lock_min;
            lock_max_mem[config_idx] <= lock_max;
            config_idx <= config_idx + 5'd1;
        end
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            badge_id <= 16'd0;
            valid_count <= 16'd0;
        end else if (state == PROCESS) begin
            // Check if current badge_id is valid
            reg valid_path;
            reg [3:0] current_room;
            reg [3:0] next_room;
            integer i, j;

            // Initialize BFS
            visited <= 16'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            queue[0] <= s_room;
            visited[s_room] <= 1'b1;
            valid_path <= 1'b0;

            // BFS loop
            for (i = 0; i < 16; i = i + 1) begin
                if (queue_head == queue_tail) begin
                    break;
                end

                current_room <= queue[queue_head];
                queue_head <= queue_head + 4'd1;

                // Check if we reached destination
                if (current_room == d_room) begin
                    valid_path <= 1'b1;
                    break;
                end

                // Check all locks for transitions
                for (j = 0; j < 32; j = j + 1) begin
                    if (lock_from_mem[j] == current_room && 
                        badge_id >= lock_min_mem[j] && 
                        badge_id <= lock_max_mem[j]) begin
                        next_room <= lock_to_mem[j];
                        if (!visited[next_room]) begin
                            visited[next_room] <= 1'b1;
                            queue[queue_tail] <= next_room;
                            queue_tail <= queue_tail + 4'd1;
                        end
                    end
                end
            end

            // Update valid count
            if (valid_path) begin
                valid_count <= valid_count + 16'd1;
            end

            // Move to next badge ID
            badge_id <= badge_id + 16'd1;
        end
    end

    // Done state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == DONE_STATE) begin
            result <= valid_count;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // Ready signal logic
    always @(*) begin
        case (state)
            IDLE: ready_internal = 1'b1;
            CONFIG: ready_internal = (config_idx < lock_count) ? 1'b1 : 1'b0;
            PROCESS: ready_internal = 1'b0;
            DONE_STATE: ready_internal = 1'b0;
            default: ready_internal = 1'b1;
        endcase
    end

    assign ready = ready_internal;

endmodule