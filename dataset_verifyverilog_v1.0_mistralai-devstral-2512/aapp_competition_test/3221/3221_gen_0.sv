module min_energy_cycle(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [4:0] M,
    input [4:0] alpha,
    input [3:0] edge_u [0:23],
    input [3:0] edge_v [0:23],
    input [31:0] edge_c [0:23],
    output reg [63:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_SUBSET = 3'd1;
    localparam [2:0] EVALUATE = 3'd2;
    localparam [2:0] UPDATE_MIN = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [23:0] subset_counter;
    reg [3:0] node_degree [0:15];
    reg [31:0] max_c;
    reg [4:0] K;
    reg [63:0] current_energy;
    reg [63:0] min_energy;
    reg [3:0] i, j;
    reg [3:0] current_node;
    reg [3:0] start_node;
    reg [3:0] visited_nodes [0:15];
    reg [3:0] node_queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg [3:0] connected_count;
    reg [3:0] temp_u, temp_v;
    reg [31:0] temp_c;
    reg all_even_degree;
    reg is_connected;
    reg [3:0] edge_index;
    reg [23:0] subset_mask;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            subset_counter <= 24'd0;
            for (i = 0; i < 16; i = i + 1) begin
                node_degree[i] <= 4'd0;
                visited_nodes[i] <= 4'd0;
                node_queue[i] <= 4'd0;
            end
            max_c <= 32'd0;
            K <= 5'd0;
            current_energy <= 64'd0;
            min_energy <= 64'd0;
            i <= 4'd0;
            j <= 4'd0;
            current_node <= 4'd0;
            start_node <= 4'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            connected_count <= 4'd0;
            temp_u <= 4'd0;
            temp_v <= 4'd0;
            temp_c <= 32'd0;
            all_even_degree <= 1'b0;
            is_connected <= 1'b0;
            edge_index <= 4'd0;
            subset_mask <= 24'd0;
            result <= 64'd0;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_SUBSET;
                    subset_counter = 24'd1;
                    min_energy = 64'd0;
                    valid = 1'b0;
                end
            end

            CHECK_SUBSET: begin
                if (subset_counter == 24'd0) begin
                    next_state = DONE_STATE;
                end else begin
                    // Reset evaluation registers
                    for (i = 0; i < 16; i = i + 1) begin
                        node_degree[i] = 4'd0;
                    end
                    max_c = 32'd0;
                    K = 5'd0;
                    subset_mask = subset_counter;

                    // Calculate degrees and max_c for current subset
                    for (edge_index = 0; edge_index < M; edge_index = edge_index + 1) begin
                        if (subset_mask[edge_index]) begin
                            temp_u = edge_u[edge_index];
                            temp_v = edge_v[edge_index];
                            temp_c = edge_c[edge_index];
                            node_degree[temp_u] = node_degree[temp_u] + 4'd1;
                            node_degree[temp_v] = node_degree[temp_v] + 4'd1;
                            if (temp_c > max_c) begin
                                max_c = temp_c;
                            end
                            K = K + 5'd1;
                        end
                    end

                    // Check if all degrees are even
                    all_even_degree = 1'b1;
                    for (i = 0; i < N; i = i + 1) begin
                        if (node_degree[i][0]) begin
                            all_even_degree = 1'b0;
                        end
                    end

                    if (all_even_degree && (K > 5'd0)) begin
                        next_state = EVALUATE;
                    end else begin
                        next_state = CHECK_SUBSET;
                        subset_counter = subset_counter + 24'd1;
                    end
                end
            end

            EVALUATE: begin
                // Check connectivity using BFS
                is_connected = 1'b0;
                connected_count = 4'd0;
                queue_head = 4'd0;
                queue_tail = 4'd0;

                // Find first node with degree > 0
                for (i = 0; i < N; i = i + 1) begin
                    if (node_degree[i] > 4'd0) begin
                        start_node = i;
                        break;
                    end
                end

                // Initialize visited
                for (i = 0; i < 16; i = i + 1) begin
                    visited_nodes[i] = 4'd0;
                end

                // BFS
                if (start_node != 4'd0) begin
                    node_queue[queue_tail] = start_node;
                    queue_tail = queue_tail + 4'd1;
                    visited_nodes[start_node] = 4'd1;
                    connected_count = 4'd1;

                    while (queue_head != queue_tail) begin
                        current_node = node_queue[queue_head];
                        queue_head = queue_head + 4'd1;

                        for (edge_index = 0; edge_index < M; edge_index = edge_index + 1) begin
                            if (subset_mask[edge_index]) begin
                                temp_u = edge_u[edge_index];
                                temp_v = edge_v[edge_index];

                                if (current_node == temp_u) begin
                                    if (!visited_nodes[temp_v]) begin
                                        node_queue[queue_tail] = temp_v;
                                        queue_tail = queue_tail + 4'd1;
                                        visited_nodes[temp_v] = 4'd1;
                                        connected_count = connected_count + 4'd1;
                                    end
                                end else if (current_node == temp_v) begin
                                    if (!visited_nodes[temp_u]) begin
                                        node_queue[queue_tail] = temp_u;
                                        queue_tail = queue_tail + 4'd1;
                                        visited_nodes[temp_u] = 4'd1;
                                        connected_count = connected_count + 4'd1;
                                    end
                                end
                            end
                        end
                    end

                    // Check if all nodes with degree > 0 are connected
                    is_connected = 1'b1;
                    for (i = 0; i < N; i = i + 1) begin
                        if ((node_degree[i] > 4'd0) && !visited_nodes[i]) begin
                            is_connected = 1'b0;
                        end
                    end
                end

                if (is_connected) begin
                    current_energy = {32'd0, max_c} * {32'd0, max_c} + {32'd0, alpha} * {32'd0, K};
                    next_state = UPDATE_MIN;
                end else begin
                    next_state = CHECK_SUBSET;
                    subset_counter = subset_counter + 24'd1;
                end
            end

            UPDATE_MIN: begin
                if ((min_energy == 64'd0) || (current_energy < min_energy)) begin
                    min_energy = current_energy;
                    valid = 1'b1;
                end
                next_state = CHECK_SUBSET;
                subset_counter = subset_counter + 24'd1;
            end

            DONE_STATE: begin
                result = min_energy;
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule