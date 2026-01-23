module uw_distance_calculator (
    input clk,
    input rst_n,
    input start,
    input [2:0] node_count,
    input [31:0] gravity_in,
    input node_valid,
    input [7:0] adjacency_in,
    input adj_valid,
    input [2:0] type_in,
    input type_valid,
    output reg [31:0] min_distance,
    output reg result_valid
);

    // Parameters
    parameter N = 8;
    parameter Q_FORMAT = 16; // Q16.16 format

    // State machine states
    typedef enum logic [2:0] {
        IDLE,
        LOAD_GRAVITY,
        LOAD_ADJACENCY,
        LOAD_TYPE,
        FLOYD_WARSHALL,
        CALCULATE_DISTANCES,
        PLACE_DEVICE,
        DONE
    } state_t;

    // Internal registers
    state_t state;
    reg [2:0] current_node;
    reg [2:0] current_pair_i;
    reg [2:0] current_pair_j;
    reg [2:0] current_device_node;
    reg [2:0] fw_k;
    reg [2:0] fw_i;
    reg [2:0] fw_j;

    // Node data storage
    reg [31:0] gravity [0:N-1];
    reg [7:0] adjacency [0:N-1];
    reg [2:0] node_type [0:N-1];

    // Shortest path storage
    reg [31:0] dist [0:N-1][0:N-1];
    reg [2:0] next [0:N-1][0:N-1];

    // Temporary storage for device placement
    reg [31:0] temp_gravity [0:N-1];

    // Intermediate calculation registers
    reg [31:0] cap, pot, ind, term, sum;
    reg [31:0] current_distance;

    // Initialize state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_node <= 0;
            current_pair_i <= 0;
            current_pair_j <= 0;
            current_device_node <= 0;
            fw_k <= 0;
            fw_i <= 0;
            fw_j <= 0;
            min_distance <= 0;
            result_valid <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_GRAVITY;
                        current_node <= 0;
                    end
                end
                LOAD_GRAVITY: begin
                    if (node_valid) begin
                        gravity[current_node] <= gravity_in;
                        current_node <= current_node + 1;
                        if (current_node == node_count) begin
                            state <= LOAD_ADJACENCY;
                            current_node <= 0;
                        end
                    end
                end
                LOAD_ADJACENCY: begin
                    if (adj_valid) begin
                        adjacency[current_node] <= adjacency_in;
                        current_node <= current_node + 1;
                        if (current_node == node_count) begin
                            state <= LOAD_TYPE;
                            current_node <= 0;
                        end
                    end
                end
                LOAD_TYPE: begin
                    if (type_valid) begin
                        node_type[current_node] <= type_in;
                        current_node <= current_node + 1;
                        if (current_node == node_count) begin
                            state <= FLOYD_WARSHALL;
                            fw_k <= 0;
                            fw_i <= 0;
                            fw_j <= 0;
                            // Initialize distance matrix
                            for (int i = 0; i < N; i = i + 1) begin
                                for (int j = 0; j < N; j = j + 1) begin
                                    if (i == j) begin
                                        dist[i][j] <= 0;
                                        next[i][j] <= i;
                                    end else if (adjacency[i][j]) begin
                                        dist[i][j] <= 1;
                                        next[i][j] <= j;
                                    end else begin
                                        dist[i][j] <= 32'hFFFFFFFF;
                                        next[i][j] <= 0;
                                    end
                                end
                            end
                        end
                    end
                end
                FLOYD_WARSHALL: begin
                    // Floyd-Warshall algorithm
                    if (fw_k < node_count) begin
                        if (fw_i < node_count) begin
                            if (fw_j < node_count) begin
                                if (dist[fw_i][fw_k] + dist[fw_k][fw_j] < dist[fw_i][fw_j]) begin
                                    dist[fw_i][fw_j] <= dist[fw_i][fw_k] + dist[fw_k][fw_j];
                                    next[fw_i][fw_j] <= next[fw_i][fw_k];
                                end
                                fw_j <= fw_j + 1;
                            end else begin
                                fw_j <= 0;
                                fw_i <= fw_i + 1;
                            end
                        end else begin
                            fw_i <= 0;
                            fw_k <= fw_k + 1;
                        end
                    end else begin
                        state <= CALCULATE_DISTANCES;
                        current_pair_i <= 0;
                        current_pair_j <= 0;
                        min_distance <= 32'hFFFFFFFF;
                    end
                end
                CALCULATE_DISTANCES: begin
                    if (current_pair_i < node_count) begin
                        if (current_pair_j < node_count) begin
                            if (node_type[current_pair_i] == 0 && node_type[current_pair_j] == 1) begin
                                // Calculate UW distance for this pair
                                sum <= 0;
                                // Reconstruct path
                                reg [2:0] path [0:N-1];
                                reg [2:0] path_len;
                                reg [2:0] current;
                                
                                current <= current_pair_i;
                                path_len <= 0;
                                while (current != current_pair_j && path_len < N) begin
                                    path[path_len] <= current;
                                    current <= next[current][current_pair_j];
                                    path_len <= path_len + 1;
                                end
                                path[path_len] <= current_pair_j;
                                path_len <= path_len + 1;
                                
                                // Calculate distance using formula
                                for (int k = 1; k < path_len; k = k + 1) begin
                                    cap <= gravity[path[k]] + gravity[path[k-1]];
                                    pot <= gravity[path[k]] - gravity[path[k-1]];
                                    ind <= gravity[path[k]] * gravity[path[k-1]];
                                    term <= pot * ((cap * cap) - ind);
                                    sum <= sum + term;
                                end
                                current_distance <= sum[31] ? -sum : sum; // Absolute value
                                
                                if (current_distance < min_distance) begin
                                    min_distance <= current_distance;
                                end
                            end
                            current_pair_j <= current_pair_j + 1;
                        end else begin
                            current_pair_j <= 0;
                            current_pair_i <= current_pair_i + 1;
                        end
                    end else begin
                        state <= PLACE_DEVICE;
                        current_device_node <= 0;
                        // Copy original gravity values
                        for (int i = 0; i < N; i = i + 1) begin
                            temp_gravity[i] <= gravity[i];
                        end
                    end
                end
                PLACE_DEVICE: begin
                    if (current_device_node < node_count) begin
                        // Modify gravity values for device placement
                        if (current_device_node > 0) begin
                            temp_gravity[current_device_node-1] <= temp_gravity[current_device_node-1] - 1;
                        end
                        for (int i = 0; i < node_count; i = i + 1) begin
                            if (adjacency[current_device_node][i]) begin
                                temp_gravity[i] <= temp_gravity[i] + 1;
                            end
                        end
                        
                        // Re-calculate distances with modified gravity
                        current_pair_i <= 0;
                        current_pair_j <= 0;
                        state <= CALCULATE_DISTANCES;
                        
                        // After calculation, restore original gravity values
                        for (int i = 0; i < N; i = i + 1) begin
                            temp_gravity[i] <= gravity[i];
                        end
                        
                        current_device_node <= current_device_node + 1;
                    end else begin
                        state <= DONE;
                        result_valid <= 1;
                    end
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        result_valid <= 0;
                    end
                end
            endcase
        end
    end

endmodule