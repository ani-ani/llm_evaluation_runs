module wonderland_decoder (
    input clk,
    input rst_n,
    input start,
    input [7:0] din,
    input din_valid,
    input din_end,
    output reg [15:0] result,
    output reg result_valid,
    output reg ready
);

    // Constants
    localparam N = 16; // Max locations
    localparam T = 16; // Max trips
    localparam MAX_TRIP_LEN = 32; // Max locations per trip
    localparam MAX_EDGES = 128; // Max unique edges

    // FSM States
    typedef enum logic [3:0] {
        IDLE,
        READ_INPUT,
        DECODE_PHASE1,
        DECODE_PHASE2,
        DECODE_PHASE3,
        DIJKSTRA_INIT,
        DIJKSTRA_LOOP,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Input Buffer
    reg [7:0] trip_data [0:T-1][0:MAX_TRIP_LEN-1];
    reg [7:0] trip_lengths [0:T-1];
    reg [7:0] trip_count;

    // Edge Data
    reg [7:0] edge_from [0:MAX_EDGES-1];
    reg [7:0] edge_to [0:MAX_EDGES-1];
    reg [7:0] edge_count [0:MAX_EDGES-1];
    reg [7:0] edge_weight [0:MAX_EDGES-1];
    reg [7:0] edge_valid [0:MAX_EDGES-1];
    reg [7:0] edge_idx;

    // Dijkstra Data
    reg [7:0] dist [0:N-1];
    reg [7:0] visited [0:N-1];
    reg [7:0] current_node;
    reg [7:0] min_dist;
    reg [7:0] min_node;

    // Counters
    reg [7:0] i, j, k;
    reg [7:0] temp_from, temp_to, temp_weight;
    reg [7:0] temp_count;

    // Control Signals
    reg phase1_done, phase2_done, phase3_done;

    // Initialize
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            result_valid <= 0;
            ready <= 1;
            trip_count <= 0;
            edge_idx <= 0;
            phase1_done <= 0;
            phase2_done <= 0;
            phase3_done <= 0;
            for (i = 0; i < T; i = i + 1) begin
                trip_lengths[i] <= 0;
                for (j = 0; j < MAX_TRIP_LEN; j = j + 1) begin
                    trip_data[i][j] <= 0;
                end
            end
            for (i = 0; i < MAX_EDGES; i = i + 1) begin
                edge_from[i] <= 0;
                edge_to[i] <= 0;
                edge_count[i] <= 0;
                edge_weight[i] <= 0;
                edge_valid[i] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // FSM Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start && ready) begin
                    next_state = READ_INPUT;
                    ready = 0;
                end
            end
            READ_INPUT: begin
                if (din_end) begin
                    next_state = DECODE_PHASE1;
                end
            end
            DECODE_PHASE1: begin
                if (phase1_done) begin
                    next_state = DECODE_PHASE2;
                end
            end
            DECODE_PHASE2: begin
                if (phase2_done) begin
                    next_state = DECODE_PHASE3;
                end
            end
            DECODE_PHASE3: begin
                if (phase3_done) begin
                    next_state = DIJKSTRA_INIT;
                end
            end
            DIJKSTRA_INIT: begin
                next_state = DIJKSTRA_LOOP;
            end
            DIJKSTRA_LOOP: begin
                if (visited[N-1]) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                result_valid = 1;
                ready = 1;
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Read Input
    always @(posedge clk) begin
        if (current_state == READ_INPUT && din_valid) begin
            if (din_end) begin
                phase1_done = 1;
            end else begin
                trip_data[trip_count][trip_lengths[trip_count]] = din;
                trip_lengths[trip_count] = trip_lengths[trip_count] + 1;
                if (din == 0) begin
                    trip_count = trip_count + 1;
                end
            end
        end
    end

    // Phase 1: Discovery
    always @(posedge clk) begin
        if (current_state == DECODE_PHASE1 && !phase1_done) begin
            for (i = 0; i < trip_count; i = i + 1) begin
                for (j = 0; j < trip_lengths[i] - 1; j = j + 1) begin
                    temp_from = trip_data[i][j];
                    temp_to = trip_data[i][j + 1];
                    // Check if edge exists
                    for (k = 0; k < edge_idx; k = k + 1) begin
                        if (edge_from[k] == temp_from && edge_to[k] == temp_to) begin
                            edge_count[k] = edge_count[k] + 1;
                            break;
                        end
                    end
                    // Add new edge
                    if (k == edge_idx && edge_idx < MAX_EDGES) begin
                        edge_from[edge_idx] = temp_from;
                        edge_to[edge_idx] = temp_to;
                        edge_count[edge_idx] = 1;
                        edge_idx = edge_idx + 1;
                    end
                end
            end
            phase1_done = 1;
        end
    end

    // Phase 2: Weight Estimation
    always @(posedge clk) begin
        if (current_state == DECODE_PHASE2 && !phase2_done) begin
            for (i = 0; i < edge_idx; i = i + 1) begin
                temp_count = 0;
                temp_weight = 0;
                for (j = 0; j < trip_count; j = j + 1) begin
                    for (k = 0; k < trip_lengths[j] - 1; k = k + 1) begin
                        if (trip_data[j][k] == edge_from[i] && trip_data[j][k + 1] == edge_to[i]) begin
                            // Calculate weight (simplified for hardware)
                            temp_weight = temp_weight + 1;
                            temp_count = temp_count + 1;
                        end
                    end
                end
                if (temp_count > 0) begin
                    edge_weight[i] = temp_weight / temp_count;
                    edge_valid[i] = 1;
                end
            end
            phase2_done = 1;
        end
    end

    // Phase 3: Verification
    always @(posedge clk) begin
        if (current_state == DECODE_PHASE3 && !phase3_done) begin
            // Simplified verification (assume all edges are valid)
            phase3_done = 1;
        end
    end

    // Dijkstra's Algorithm
    always @(posedge clk) begin
        if (current_state == DIJKSTRA_INIT) begin
            for (i = 0; i < N; i = i + 1) begin
                dist[i] = 255; // Initialize to max
                visited[i] = 0;
            end
            dist[0] = 0; // Source node A (index 0)
            current_node = 0;
        end else if (current_state == DIJKSTRA_LOOP) begin
            // Find min distance node
            min_dist = 255;
            min_node = 0;
            for (i = 0; i < N; i = i + 1) begin
                if (!visited[i] && dist[i] < min_dist) begin
                    min_dist = dist[i];
                    min_node = i;
                end
            end
            if (min_dist == 255) begin
                // No more nodes to visit
                current_node = N - 1;
                visited[N - 1] = 1;
            end else begin
                current_node = min_node;
                visited[current_node] = 1;
                // Update neighbors
                for (i = 0; i < edge_idx; i = i + 1) begin
                    if (edge_from[i] == current_node && edge_valid[i]) begin
                        if (dist[edge_to[i]] > dist[current_node] + edge_weight[i]) begin
                            dist[edge_to[i]] = dist[current_node] + edge_weight[i];
                        end
                    end
                end
            end
        end
    end

    // Output Result
    always @(posedge clk) begin
        if (current_state == DONE) begin
            result = dist[N - 1]; // Destination node R (index N-1)
            result_valid = 1;
        end else begin
            result_valid = 0;
        end
    end

endmodule