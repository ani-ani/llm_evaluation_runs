module arrange_solver_4 (
    input clk,
    input rst_n,
    input start,
    input start_swap_config,
    input [3:0] swap_indices [2:0],
    input [3:0] perm_in [3:0],
    output reg [3:0] min_swaps,
    output reg done,
    output reg valid
);

    // State machine states
    typedef enum logic [2:0] {
        IDLE,
        LOAD_PERM,
        LOAD_SWAPS,
        BFS_INIT,
        BFS_LOOP,
        FINISHED
    } state_t;

    state_t current_state, next_state;

    // BFS queue and visited array
    reg [3:0] queue_perm [0:23][0:3];
    reg [3:0] queue_dist [0:23];
    reg [23:0] visited;
    reg [4:0] queue_head, queue_tail;

    // Current permutation and swap indices
    reg [3:0] current_perm [0:3];
    reg [3:0] swap_list [0:3];
    reg [1:0] swap_count;

    // Helper functions
    function logic [4:0] perm_to_index;
        input [3:0] p [0:3];
        integer i, j, rank;
        begin
            rank = 0;
            for (i = 0; i < 4; i = i + 1) begin
                for (j = i + 1; j < 4; j = j + 1) begin
                    if (p[i] > p[j]) rank = rank + 1;
                end
            end
            perm_to_index = rank;
        end
    endfunction

    function logic [3:0] index_to_perm;
        input [4:0] idx;
        integer i, j, k, temp;
        reg [3:0] p [0:3];
        begin
            for (i = 0; i < 4; i = i + 1) p[i] = i + 1;
            for (i = 0; i < 4; i = i + 1) begin
                temp = idx % (4 - i);
                idx = idx / (4 - i);
                for (j = i; j < 3; j = j + 1) p[j] = p[j + 1];
                p[3] = p[i + temp];
                for (k = 3; k > i + temp; k = k - 1) p[k] = p[k - 1];
                p[i + temp] = temp + 1;
            end
            index_to_perm = {p[0], p[1], p[2], p[3]};
        end
    endfunction

    // Swap function
    function logic [3:0] apply_swap;
        input [3:0] p [0:3];
        input [1:0] a, b;
        begin
            p[a] = p[a] ^ p[b];
            p[b] = p[a] ^ p[b];
            p[a] = p[a] ^ p[b];
            apply_swap = {p[0], p[1], p[2], p[3]};
        end
    endfunction

    // Check if permutation is sorted
    function logic is_sorted;
        input [3:0] p [0:3];
        begin
            is_sorted = (p[0] == 1 && p[1] == 2 && p[2] == 3 && p[3] == 4);
        end
    endfunction

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            valid <= 0;
            min_swaps <= 0;
            queue_head <= 0;
            queue_tail <= 0;
            visited <= 0;
            swap_count <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD_PERM;
            end
            LOAD_PERM: begin
                next_state = LOAD_SWAPS;
            end
            LOAD_SWAPS: begin
                if (start_swap_config) next_state = BFS_INIT;
            end
            BFS_INIT: begin
                next_state = BFS_LOOP;
            end
            BFS_LOOP: begin
                if (done) next_state = FINISHED;
            end
            FINISHED: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Load permutation
    always @(posedge clk) begin
        if (current_state == LOAD_PERM) begin
            for (int i = 0; i < 4; i = i + 1) begin
                current_perm[i] <= perm_in[i];
            end
        end
    end

    // Load swap indices
    always @(posedge clk) begin
        if (current_state == LOAD_SWAPS && start_swap_config) begin
            for (int i = 0; i < 3; i = i + 1) begin
                swap_list[i] <= swap_indices[i];
            end
            swap_count <= 3;
        end
    end

    // BFS initialization
    always @(posedge clk) begin
        if (current_state == BFS_INIT) begin
            // Reset visited array
            visited <= 0;
            // Reset queue
            queue_head <= 0;
            queue_tail <= 0;
            // Push initial permutation
            for (int i = 0; i < 4; i = i + 1) begin
                queue_perm[0][i] <= current_perm[i];
            end
            queue_dist[0] <= 0;
            visited[perm_to_index(current_perm)] <= 1;
            queue_tail <= queue_tail + 1;
        end
    end

    // BFS loop
    always @(posedge clk) begin
        if (current_state == BFS_LOOP && !done) begin
            reg [3:0] current_queue_perm [0:3];
            reg [3:0] current_dist;
            reg [4:0] current_index;

            // Dequeue
            if (queue_head < queue_tail) begin
                for (int i = 0; i < 4; i = i + 1) begin
                    current_queue_perm[i] <= queue_perm[queue_head][i];
                end
                current_dist <= queue_dist[queue_head];
                current_index <= perm_to_index(current_queue_perm);
                queue_head <= queue_head + 1;

                // Check if sorted
                if (is_sorted(current_queue_perm)) begin
                    min_swaps <= current_dist;
                    done <= 1;
                    valid <= 1;
                end else begin
                    // Generate neighbors
                    for (int i = 0; i < swap_count; i = i + 1) begin
                        reg [3:0] new_perm [0:3];
                        reg [1:0] a, b;
                        reg [4:0] new_index;

                        a = swap_list[i][3:2];
                        b = swap_list[i][1:0];

                        for (int j = 0; j < 4; j = j + 1) begin
                            new_perm[j] = current_queue_perm[j];
                        end

                        new_perm[a] = current_queue_perm[b];
                        new_perm[b] = current_queue_perm[a];

                        new_index = perm_to_index(new_perm);

                        if (!visited[new_index]) begin
                            visited[new_index] = 1;
                            for (int j = 0; j < 4; j = j + 1) begin
                                queue_perm[queue_tail][j] = new_perm[j];
                            end
                            queue_dist[queue_tail] = current_dist + 1;
                            queue_tail = queue_tail + 1;
                        end
                    end
                end
            end else begin
                done <= 1;
                valid <= 0;
            end
        end
    end

endmodule