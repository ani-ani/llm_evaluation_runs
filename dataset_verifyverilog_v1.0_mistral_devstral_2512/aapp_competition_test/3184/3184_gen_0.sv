module CameraCover(
    input clk,
    input rst_n,
    input start,
    input [2:0] a_i [0:7],
    input [2:0] b_i [0:7],
    output reg done,
    output reg [7:0] result
);

    // Parameters
    localparam N = 8;
    localparam K = 8;
    localparam MAX_STATES = 256;
    localparam MAX_DISTANCE = 4;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_MASKS = 3'd1;
    localparam [2:0] INIT_BFS = 3'd2;
    localparam [2:0] BFS_DEQUEUE = 3'd3;
    localparam [2:0] BFS_PROCESS = 3'd4;
    localparam [2:0] UPDATE_QUEUE = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Internal signals
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [N-1:0] mask [0:K-1];
    reg [MAX_STATES-1:0] visited;
    reg [MAX_DISTANCE-1:0] distance [0:MAX_STATES-1];
    reg [7:0] queue [0:MAX_STATES-1];
    reg [7:0] queue_head, queue_tail;
    reg [7:0] current_state;
    reg [7:0] next_state_val;
    reg [7:0] camera_index;
    reg [7:0] temp_mask;
    reg [7:0] i, j;

    // FSM state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            cycle_count <= 8'd0;
            queue_head <= 8'd0;
            queue_tail <= 8'd0;
            current_state <= 8'd0;
            next_state_val <= 8'd0;
            camera_index <= 8'd0;
            temp_mask <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;

            // Initialize visited and distance arrays
            for (i = 0; i < MAX_STATES; i = i + 1) begin
                visited[i] <= 1'b0;
                distance[i] <= 4'd0;
            end

            // Initialize mask array
            for (i = 0; i < K; i = i + 1) begin
                mask[i] <= 8'd0;
            end

            // Initialize queue
            for (i = 0; i < MAX_STATES; i = i + 1) begin
                queue[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in reset
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD_MASKS;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD_MASKS: begin
                    // Compute masks for all cameras
                    for (i = 0; i < K; i = i + 1) begin
                        if (a_i[i] != 3'd0) begin
                            if (a_i[i] <= b_i[i]) begin
                                // Non-wrapping case
                                temp_mask <= ((1 << (b_i[i] - a_i[i] + 1)) - 1) << (a_i[i] - 1);
                            end else begin
                                // Wrapping case
                                temp_mask <= (((1 << (N - a_i[i] + 1)) - 1) << (a_i[i] - 1)) | ((1 << b_i[i]) - 1);
                            end
                            mask[i] <= temp_mask;
                        end else begin
                            mask[i] <= 8'd0;
                        end
                    end
                    next_state <= INIT_BFS;
                end

                INIT_BFS: begin
                    // Initialize BFS
                    visited[0] <= 1'b1;
                    distance[0] <= 4'd0;
                    queue[0] <= 8'd0;
                    queue_head <= 8'd0;
                    queue_tail <= 8'd1;
                    next_state <= BFS_DEQUEUE;
                end

                BFS_DEQUEUE: begin
                    if (queue_head != queue_tail) begin
                        current_state <= queue[queue_head];
                        queue_head <= queue_head + 8'd1;
                        next_state <= BFS_PROCESS;
                    end else begin
                        // Queue empty, no solution
                        result <= 8'd0;
                        next_state <= DONE_STATE;
                    end
                end

                BFS_PROCESS: begin
                    if (current_state == (1 << N) - 1) begin
                        // All walls covered
                        result <= distance[current_state];
                        next_state <= DONE_STATE;
                    end else begin
                        camera_index <= 8'd0;
                        next_state <= UPDATE_QUEUE;
                    end
                end

                UPDATE_QUEUE: begin
                    if (camera_index < K) begin
                        next_state_val <= current_state | mask[camera_index];
                        if ((next_state_val != current_state) && !visited[next_state_val]) begin
                            visited[next_state_val] <= 1'b1;
                            distance[next_state_val] <= distance[current_state] + 4'd1;
                            queue[queue_tail] <= next_state_val;
                            queue_tail <= queue_tail + 8'd1;
                        end
                        camera_index <= camera_index + 8'd1;
                        next_state <= UPDATE_QUEUE;
                    end else begin
                        next_state <= BFS_DEQUEUE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule