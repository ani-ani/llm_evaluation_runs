module network_merger (
    input clk,
    input rst_n,
    input start,
    input [7:0] num_nodes,
    input [7:0] k,
    input [63:0] edge_mask,
    input [63:0] capacity_mask,
    output reg result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        PARSE,
        FLOYD_ITER,
        COUNT_COMPONENTS,
        CHECK_CONDITIONS,
        DONE
    } state_t;

    state_t state;
    reg [5:0] cycle_count;

    // Internal registers
    reg [7:0] node_capacities [0:7];
    reg [7:0] node_degrees [0:7];
    reg [7:0] reachable [0:7];
    reg [7:0] component_count;
    reg [7:0] required_additions;
    reg [7:0] available_removals;
    reg [7:0] existing_free_sockets;
    reg [7:0] total_capacity;

    // Floyd-Warshall registers
    reg [7:0] R [0:7][0:7];
    reg [2:0] floyd_k;

    // Component counting registers
    reg [7:0] visited [0:7];
    reg [2:0] current_node;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 0;
            result <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PARSE;
                        cycle_count <= 0;
                    end
                end
                PARSE: begin
                    // Parse capacities
                    for (int i = 0; i < 8; i++) begin
                        node_capacities[i] <= capacity_mask[(i*4)+:4];
                    end

                    // Calculate degrees
                    for (int i = 0; i < 8; i++) begin
                        node_degrees[i] <= 0;
                        for (int j = 0; j < 8; j++) begin
                            if (i != j && edge_mask[i*8 + j]) begin
                                node_degrees[i] <= node_degrees[i] + 1;
                            end
                        end
                    end

                    // Initialize reachability matrix
                    for (int i = 0; i < 8; i++) begin
                        for (int j = 0; j < 8; j++) begin
                            R[i][j] <= (i == j) || edge_mask[i*8 + j];
                        end
                    end

                    state <= FLOYD_ITER;
                    floyd_k <= 0;
                end
                FLOYD_ITER: begin
                    // Floyd-Warshall iteration
                    for (int i = 0; i < 8; i++) begin
                        for (int j = 0; j < 8; j++) begin
                            R[i][j] <= R[i][j] || (R[i][floyd_k] && R[floyd_k][j]);
                        end
                    end

                    floyd_k <= floyd_k + 1;
                    if (floyd_k == 7) begin
                        state <= COUNT_COMPONENTS;
                        current_node <= 0;
                        component_count <= 0;
                        for (int i = 0; i < 8; i++) begin
                            visited[i] <= 0;
                        end
                    end
                end
                COUNT_COMPONENTS: begin
                    // Count connected components
                    if (!visited[current_node] && current_node < num_nodes) begin
                        component_count <= component_count + 1;
                        visited[current_node] <= 1;

                        // Mark all reachable nodes
                        for (int i = 0; i < 8; i++) begin
                            if (R[current_node][i] && !visited[i] && i < num_nodes) begin
                                visited[i] <= 1;
                            end
                        end
                    end

                    current_node <= current_node + 1;
                    if (current_node == 8) begin
                        state <= CHECK_CONDITIONS;
                    end
                end
                CHECK_CONDITIONS: begin
                    // Calculate required additions
                    required_additions <= component_count - 1;

                    // Calculate available removals and free sockets
                    available_removals <= 0;
                    existing_free_sockets <= 0;
                    total_capacity <= 0;

                    for (int i = 0; i < num_nodes; i++) begin
                        total_capacity <= total_capacity + node_capacities[i];
                        if (node_degrees[i] >= 2) begin
                            available_removals <= available_removals + (node_degrees[i] - 1);
                        end
                        if (node_capacities[i] >= 2) begin
                            existing_free_sockets <= existing_free_sockets + (node_capacities[i] - 1);
                        end
                    end

                    // Check feasibility
                    if (k < required_additions) begin
                        result <= 0;
                    end else if (total_capacity >= num_nodes) begin
                        result <= 1;
                    end else if ((available_removals + existing_free_sockets) >= required_additions) begin
                        result <= 1;
                    end else begin
                        result <= 0;
                    end

                    state <= DONE;
                end
                DONE: begin
                    done <= 1;
                end
                default: begin
                    state <= IDLE;
                    done <= 0;
                end
            endcase

            cycle_count <= cycle_count + 1;
            if (cycle_count == 50) begin
                done <= 1;
            end
        end
    end

endmodule