module shortest_cycle_finder (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_nodes,
    input [255:0] adj_matrix_flat,
    output reg [3:0] cycle_len,
    output reg [3:0] cycle_nodes [0:15],
    output reg done
);

    // Internal state definitions
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        FLOYD_LOOP_I,
        FLOYD_LOOP_J,
        FLOYD_LOOP_K,
        CHECK_CYCLES,
        BACKTRACK,
        DONE
    } state_t;

    state_t state;

    // Internal registers for Floyd-Warshall
    reg [4:0] dist [0:15][0:15]; // 5-bit distances
    reg [3:0] parent [0:15][0:15]; // 4-bit parent indices

    // Loop counters
    reg [3:0] i, j, k;
    reg [3:0] start_node;
    reg [3:0] min_cycle_len;
    reg [3:0] path [0:15]; // Temporary path storage
    reg [3:0] path_len;
    reg [3:0] curr, prev;

    // Initialize state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            cycle_len <= 0;
            for (int idx = 0; idx < 16; idx++) begin
                cycle_nodes[idx] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        done <= 0;
                    end
                end
                INIT: begin
                    // Initialize dist and parent matrices
                    for (int idx = 0; idx < 16; idx++) begin
                        for (int jdx = 0; jdx < 16; jdx++) begin
                            if (idx == jdx) begin
                                dist[idx][jdx] <= 5'b00000; // Distance to self is 0
                            end else if (adj_matrix_flat[(idx * 16) + jdx]) begin
                                dist[idx][jdx] <= 5'b00001; // Direct edge
                                parent[idx][jdx] <= idx;
                            end else begin
                                dist[idx][jdx] <= 5'b11111; // Infinity
                                parent[idx][jdx] <= 4'b0000;
                            end
                        end
                    end
                    i <= 0;
                    j <= 0;
                    k <= 0;
                    state <= FLOYD_LOOP_I;
                end
                FLOYD_LOOP_I: begin
                    if (i < num_nodes) begin
                        j <= 0;
                        state <= FLOYD_LOOP_J;
                    end else begin
                        state <= CHECK_CYCLES;
                    end
                end
                FLOYD_LOOP_J: begin
                    if (j < num_nodes) begin
                        k <= 0;
                        state <= FLOYD_LOOP_K;
                    end else begin
                        i <= i + 1;
                        state <= FLOYD_LOOP_I;
                    end
                end
                FLOYD_LOOP_K: begin
                    if (k < num_nodes) begin
                        // Floyd-Warshall update
                        if (dist[i][k] + dist[k][j] < dist[i][j]) begin
                            dist[i][j] <= dist[i][k] + dist[k][j];
                            parent[i][j] <= parent[k][j];
                        end
                        k <= k + 1;
                    end else begin
                        j <= j + 1;
                        state <= FLOYD_LOOP_J;
                    end
                end
                CHECK_CYCLES: begin
                    min_cycle_len <= 5'b11111;
                    start_node <= 0;
                    for (int idx = 0; idx < num_nodes; idx++) begin
                        if (dist[idx][idx] < min_cycle_len && dist[idx][idx] != 0) begin
                            min_cycle_len <= dist[idx][idx];
                            start_node <= idx;
                        end
                    end
                    if (min_cycle_len == 5'b11111) begin
                        cycle_len <= 0;
                        state <= DONE;
                    end else begin
                        path_len <= 0;
                        path[path_len] <= start_node;
                        curr <= start_node;
                        prev <= parent[start_node][start_node];
                        state <= BACKTRACK;
                    end
                end
                BACKTRACK: begin
                    if (prev != start_node && path_len < 15) begin
                        path_len <= path_len + 1;
                        path[path_len] <= prev;
                        curr <= prev;
                        prev <= parent[curr][start_node];
                    end else begin
                        // Reverse path to get correct order
                        for (int idx = 0; idx < path_len + 1; idx++) begin
                            cycle_nodes[idx] <= path[path_len - idx];
                        end
                        cycle_len <= path_len + 1;
                        state <= DONE;
                    end
                end
                DONE: begin
                    done <= 1;
                    if (start) begin
                        state <= INIT;
                        done <= 0;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule