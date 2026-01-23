module fair_ranking_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] k,
    input [7:0] adj_matrix [0:7][0:7],
    input [7:0] s_mask,
    output reg [2:0] min_disqualify_size,
    output reg found,
    output reg impossible
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CHECK_SUBSET,
        VERIFY_GRAPH,
        NEXT_SUBSET,
        DONE,
        IMPOSSIBLE
    } state_t;

    state_t state;
    reg [2:0] current_search_size;
    reg [7:0] subset_mask;
    reg [7:0] subset_counter;
    reg [7:0] max_subset;
    reg [7:0] in_degree [0:7];
    reg [7:0] queue [0:7];
    reg [2:0] queue_head, queue_tail;
    reg [7:0] visited;
    reg [7:0] temp_mask;
    reg [7:0] node;
    reg [7:0] i, j;
    reg [7:0] count;
    reg [7:0] popcount;
    reg acyclic;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_search_size <= 0;
            subset_mask <= 0;
            subset_counter <= 0;
            max_subset <= 0;
            min_disqualify_size <= 0;
            found <= 0;
            impossible <= 0;
            for (i = 0; i < 8; i = i + 1) begin
                in_degree[i] <= 0;
                queue[i] <= 0;
            end
            queue_head <= 0;
            queue_tail <= 0;
            visited <= 0;
            temp_mask <= 0;
            node <= 0;
            count <= 0;
            popcount <= 0;
            acyclic <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CHECK_SUBSET;
                        current_search_size <= 0;
                        subset_counter <= 0;
                        max_subset <= (1 << n) - 1;
                        found <= 0;
                        impossible <= 0;
                    end
                end

                CHECK_SUBSET: begin
                    if (subset_counter == max_subset) begin
                        current_search_size <= current_search_size + 1;
                        if (current_search_size == k) begin
                            state <= IMPOSSIBLE;
                            impossible <= 1;
                        end else begin
                            subset_counter <= 0;
                        end
                    end else begin
                        subset_mask <= subset_counter;
                        // Check if subset_mask has popcount == current_search_size and disjoint from s_mask
                        popcount <= 0;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (subset_mask[i]) popcount <= popcount + 1;
                        end
                        if ((popcount == current_search_size) && ((subset_mask & s_mask) == 0)) begin
                            state <= VERIFY_GRAPH;
                        end else begin
                            subset_counter <= subset_counter + 1;
                        end
                    end
                end

                VERIFY_GRAPH: begin
                    // Initialize in_degree for remaining nodes
                    for (i = 0; i < 8; i = i + 1) begin
                        if ((subset_mask[i] == 0) && (s_mask[i] == 0)) begin
                            in_degree[i] <= 0;
                            for (j = 0; j < 8; j = j + 1) begin
                                if ((subset_mask[j] == 0) && (s_mask[j] == 0) && (adj_matrix[j][i])) begin
                                    in_degree[i] <= in_degree[i] + 1;
                                end
                            end
                        end else begin
                            in_degree[i] <= 0;
                        end
                    end
                    // Initialize queue
                    queue_head <= 0;
                    queue_tail <= 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if ((in_degree[i] == 0) && (subset_mask[i] == 0) && (s_mask[i] == 0)) begin
                            queue[queue_tail] <= i;
                            queue_tail <= queue_tail + 1;
                        end
                    end
                    visited <= 0;
                    count <= 0;
                    state <= NEXT_SUBSET;
                end

                NEXT_SUBSET: begin
                    if (queue_head == queue_tail) begin
                        // Check if all nodes processed
                        for (i = 0; i < 8; i = i + 1) begin
                            if ((subset_mask[i] == 0) && (s_mask[i] == 0) && (visited[i] == 0)) begin
                                acyclic <= 0;
                                break;
                            end
                        end
                        if (acyclic) begin
                            min_disqualify_size <= current_search_size;
                            found <= 1;
                            state <= DONE;
                        end else begin
                            subset_counter <= subset_counter + 1;
                            state <= CHECK_SUBSET;
                        end
                    end else begin
                        node <= queue[queue_head];
                        queue_head <= queue_head + 1;
                        visited[node] <= 1;
                        count <= count + 1;
                        // Update in_degree for neighbors
                        for (i = 0; i < 8; i = i + 1) begin
                            if ((adj_matrix[node][i]) && (subset_mask[i] == 0) && (s_mask[i] == 0)) begin
                                in_degree[i] <= in_degree[i] - 1;
                                if (in_degree[i] == 0) begin
                                    queue[queue_tail] <= i;
                                    queue_tail <= queue_tail + 1;
                                end
                            end
                        end
                    end
                end

                DONE: begin
                    // Stay in DONE state
                end

                IMPOSSIBLE: begin
                    // Stay in IMPOSSIBLE state
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule