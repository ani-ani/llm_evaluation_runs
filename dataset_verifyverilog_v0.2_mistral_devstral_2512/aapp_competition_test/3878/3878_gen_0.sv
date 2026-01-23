module graph_optimizer (
    input clk,
    input rst_n,
    input start,
    input [15:0] adj_matrix_0,
    input [15:0] adj_matrix_1,
    input [15:0] adj_matrix_2,
    input [15:0] adj_matrix_3,
    input [15:0] adj_matrix_4,
    input [15:0] adj_matrix_5,
    input [15:0] adj_matrix_6,
    input [15:0] adj_matrix_7,
    input [15:0] adj_matrix_8,
    input [15:0] adj_matrix_9,
    input [15:0] adj_matrix_10,
    input [15:0] adj_matrix_11,
    input [15:0] adj_matrix_12,
    input [15:0] adj_matrix_13,
    input [15:0] adj_matrix_14,
    input [15:0] adj_matrix_15,
    input [3:0] n,
    output reg [3:0] result_steps,
    output reg [15:0] result_mask,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        BUILD_COMPLEMENTS,
        BFS_INIT,
        BFS_LOOP,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Complement adjacency masks (non-edges)
    reg [15:0] comp_mask [0:15];

    // BFS queue and visited tracking
    reg [15:0] queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg [3:0] queue_size;
    reg [15:0] visited [0:15];

    // Current mask and distance being processed
    reg [15:0] current_mask;
    reg [3:0] current_distance;

    // Result tracking
    reg [3:0] min_distance;
    reg [15:0] min_mask;

    // Temporary variables
    reg [15:0] new_mask;
    reg [3:0] i, j;
    reg mask_ready;
    reg [15:0] all_non_edges_covered;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result_steps <= 0;
            result_mask <= 0;
            queue_head <= 0;
            queue_tail <= 0;
            queue_size <= 0;
            current_distance <= 0;
            min_distance <= 0;
            min_mask <= 0;
            mask_ready <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = BUILD_COMPLEMENTS;
            end
            BUILD_COMPLEMENTS: begin
                if (mask_ready) next_state = BFS_INIT;
            end
            BFS_INIT: begin
                next_state = BFS_LOOP;
            end
            BFS_LOOP: begin
                if (min_distance != 0) next_state = DONE;
                else if (queue_size == 0) next_state = BFS_INIT;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Build complement masks
    always @(posedge clk) begin
        if (current_state == BUILD_COMPLEMENTS) begin
            for (i = 0; i < 16; i = i + 1) begin
                case (i)
                    0: comp_mask[i] = ~adj_matrix_0 & ((1 << n) - 1);
                    1: comp_mask[i] = ~adj_matrix_1 & ((1 << n) - 1);
                    2: comp_mask[i] = ~adj_matrix_2 & ((1 << n) - 1);
                    3: comp_mask[i] = ~adj_matrix_3 & ((1 << n) - 1);
                    4: comp_mask[i] = ~adj_matrix_4 & ((1 << n) - 1);
                    5: comp_mask[i] = ~adj_matrix_5 & ((1 << n) - 1);
                    6: comp_mask[i] = ~adj_matrix_6 & ((1 << n) - 1);
                    7: comp_mask[i] = ~adj_matrix_7 & ((1 << n) - 1);
                    8: comp_mask[i] = ~adj_matrix_8 & ((1 << n) - 1);
                    9: comp_mask[i] = ~adj_matrix_9 & ((1 << n) - 1);
                    10: comp_mask[i] = ~adj_matrix_10 & ((1 << n) - 1);
                    11: comp_mask[i] = ~adj_matrix_11 & ((1 << n) - 1);
                    12: comp_mask[i] = ~adj_matrix_12 & ((1 << n) - 1);
                    13: comp_mask[i] = ~adj_matrix_13 & ((1 << n) - 1);
                    14: comp_mask[i] = ~adj_matrix_14 & ((1 << n) - 1);
                    15: comp_mask[i] = ~adj_matrix_15 & ((1 << n) - 1);
                endcase
            end
            mask_ready <= 1;
        end
    end

    // BFS initialization
    always @(posedge clk) begin
        if (current_state == BFS_INIT) begin
            // Reset visited array
            for (i = 0; i < 16; i = i + 1) begin
                visited[i] <= 0;
            end
            // Initialize queue with empty mask
            queue[0] <= 0;
            queue_head <= 0;
            queue_tail <= 1;
            queue_size <= 1;
            current_distance <= 0;
            min_distance <= 0;
            min_mask <= 0;
        end
    end

    // BFS loop processing
    always @(posedge clk) begin
        if (current_state == BFS_LOOP && queue_size > 0) begin
            current_mask <= queue[queue_head];
            queue_head <= queue_head + 1;
            queue_size <= queue_size - 1;

            // Check if current mask covers all non-edges
            all_non_edges_covered = 1;
            for (i = 0; i < n; i = i + 1) begin
                if ((current_mask & comp_mask[i]) != comp_mask[i]) begin
                    all_non_edges_covered = 0;
                end
            end

            if (all_non_edges_covered && min_distance == 0) begin
                min_distance <= current_distance;
                min_mask <= current_mask;
            end

            // Generate new masks by adding one vertex
            for (i = 0; i < n; i = i + 1) begin
                if (!(current_mask[i])) begin
                    new_mask = current_mask | (1 << i);
                    if (!visited[new_mask] && queue_size < 16) begin
                        queue[queue_tail] <= new_mask;
                        queue_tail <= queue_tail + 1;
                        queue_size <= queue_size + 1;
                        visited[new_mask] <= 1;
                    end
                end
            end
        end else if (current_state == BFS_LOOP && queue_size == 0) begin
            current_distance <= current_distance + 1;
        end
    end

    // Output results
    always @(posedge clk) begin
        if (current_state == DONE) begin
            done <= 1;
            result_steps <= min_distance;
            result_mask <= min_mask;
        end else begin
            done <= 0;
        end
    end

endmodule