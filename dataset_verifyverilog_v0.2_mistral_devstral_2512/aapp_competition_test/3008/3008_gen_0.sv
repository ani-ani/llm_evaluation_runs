module max_ranks (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] k,
    input [7:0] a [0:7],
    input [7:0] b [0:7],
    output reg [3:0] result,
    output reg done
);

    // States
    typedef enum logic [1:0] {
        IDLE,
        BUILD_GRAPH,
        COMPUTE_MATCHING,
        DONE
    } state_t;
    state_t state, next_state;

    // Graph adjacency matrix (8x8)
    reg [7:0] adj_matrix [0:7];

    // Matching arrays
    reg [2:0] matchL [0:7]; // Left partition match
    reg [2:0] matchR [0:7]; // Right partition match
    reg [7:0] visited;

    // Counters
    reg [2:0] i, j, l;
    reg [2:0] max_matching;
    reg [2:0] path_count;

    // Internal signals
    reg [2:0] current_node;
    reg found_augmenting_path;

    // Initialize state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
        end else begin
            state <= next_state;
        end
    end

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = BUILD_GRAPH;
            end
            BUILD_GRAPH: begin
                if (i == n - 1 && j == n) next_state = COMPUTE_MATCHING;
            end
            COMPUTE_MATCHING: begin
                if (done) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Build graph state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 0;
            j <= 0;
            for (int x = 0; x < 8; x++) begin
                adj_matrix[x] <= 0;
            end
        end else if (state == BUILD_GRAPH) begin
            if (j == 0) begin
                if (i < n - 1) begin
                    i <= i + 1;
                    j <= i + 1;
                end
            end else if (j < n) begin
                // Check dominance condition
                if ((a[i] + k < a[j]) || (b[i] + k < b[j])) begin
                    adj_matrix[i][j] <= 1;
                end else begin
                    adj_matrix[i][j] <= 0;
                end
                j <= j + 1;
            end
        end
    end

    // Compute matching state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_matching <= 0;
            for (int x = 0; x < 8; x++) begin
                matchL[x] <= 0;
                matchR[x] <= 0;
            end
            current_node <= 0;
            found_augmenting_path <= 0;
            visited <= 0;
            l <= 0;
        end else if (state == COMPUTE_MATCHING) begin
            case (l)
                0: begin // Initialize matching
                    max_matching <= 0;
                    for (int x = 0; x < 8; x++) begin
                        matchL[x] <= 0;
                        matchR[x] <= 0;
                    end
                    current_node <= 0;
                    l <= 1;
                end
                1: begin // Try to find augmenting paths
                    if (current_node < n) begin
                        visited <= 0;
                        found_augmenting_path <= 0;
                        l <= 2;
                    end else begin
                        result <= n - max_matching;
                        done <= 1;
                        l <= 0;
                    end
                end
                2: begin // DFS for augmenting path
                    if (i < n && !visited[i]) begin
                        visited[i] <= 1;
                        if (adj_matrix[current_node][i] && (matchR[i] == 0 || found_augmenting_path)) begin
                            if (matchR[i] == 0) begin
                                found_augmenting_path <= 1;
                                matchL[current_node] <= i;
                                matchR[i] <= current_node;
                                max_matching <= max_matching + 1;
                            end else begin
                                current_node <= matchR[i];
                                i <= 0;
                            end
                        end else begin
                            i <= i + 1;
                        end
                    end else begin
                        if (found_augmenting_path) begin
                            current_node <= current_node + 1;
                            i <= 0;
                            l <= 1;
                        end else begin
                            i <= 0;
                            l <= 3;
                        end
                    end
                end
                3: begin // Reset for next node
                    current_node <= current_node + 1;
                    i <= 0;
                    l <= 1;
                end
            endcase
        end
    end

    // Default assignments
    always @(*) begin
        i = 0;
        j = 0;
    end

endmodule