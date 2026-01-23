module secure_network (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] p,
    input [7:0] insecure_mask,
    input [7:0] edge_valid,
    input [2:0] edge_u [27:0],
    input [2:0] edge_v [27:0],
    input [9:0] edge_w [27:0],
    output reg [15:0] result,
    output reg done,
    output reg impossible
);

    // States
    typedef enum logic [3:0] {
        IDLE,
        INIT,
        CHECK_SUBSET,
        CALCULATE_COST,
        UPDATE_BEST,
        DONE
    } state_t;

    state_t state;
    reg [27:0] edge_mask;
    reg [27:0] best_edge_mask;
    reg [15:0] min_cost;
    reg [7:0] connected;
    reg [7:0] degree [7:0];
    reg [7:0] visited;
    reg [2:0] current_edge;
    reg [2:0] edge_count;
    reg [2:0] node;
    reg [2:0] queue [7:0];
    reg [2:0] q_head, q_tail;
    reg [15:0] current_cost;
    reg [2:0] i, j;
    reg valid_tree;
    reg [2:0] total_edges;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            edge_mask <= 0;
            best_edge_mask <= 0;
            min_cost <= 16'hFFFF;
            connected <= 0;
            for (i = 0; i < 8; i = i + 1) begin
                degree[i] <= 0;
            end
            visited <= 0;
            current_edge <= 0;
            edge_count <= 0;
            node <= 0;
            q_head <= 0;
            q_tail <= 0;
            current_cost <= 0;
            valid_tree <= 0;
            total_edges <= 0;
            done <= 0;
            impossible <= 0;
            result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        done <= 0;
                        impossible <= 0;
                        min_cost <= 16'hFFFF;
                        best_edge_mask <= 0;
                    end
                end
                INIT: begin
                    edge_mask <= 0;
                    current_edge <= 0;
                    edge_count <= 0;
                    total_edges <= 0;
                    for (i = 0; i < 28; i = i + 1) begin
                        if (edge_valid[i]) total_edges <= total_edges + 1;
                    end
                    state <= CHECK_SUBSET;
                end
                CHECK_SUBSET: begin
                    if (edge_mask == 0) begin
                        edge_mask <= 1 << current_edge;
                        current_edge <= current_edge + 1;
                    end else begin
                        // Check if current subset is valid
                        // Reset connectivity and degree
                        connected <= 0;
                        for (i = 0; i < 8; i = i + 1) begin
                            degree[i] <= 0;
                        end
                        // Calculate degree and check connectivity
                        for (i = 0; i < 28; i = i + 1) begin
                            if (edge_mask[i] && edge_valid[i]) begin
                                degree[edge_u[i]] <= degree[edge_u[i]] + 1;
                                degree[edge_v[i]] <= degree[edge_v[i]] + 1;
                            end
                        end
                        // BFS to check connectivity
                        visited <= 0;
                        q_head <= 0;
                        q_tail <= 0;
                        // Find first connected node
                        for (i = 0; i < n; i = i + 1) begin
                            if (degree[i] > 0) begin
                                queue[q_tail] <= i;
                                q_tail <= q_tail + 1;
                                visited[i] <= 1;
                                break;
                            end
                        end
                        // BFS
                        while (q_head != q_tail) begin
                            node <= queue[q_head];
                            q_head <= q_head + 1;
                            for (i = 0; i < 28; i = i + 1) begin
                                if (edge_mask[i] && edge_valid[i]) begin
                                    if (edge_u[i] == node && !visited[edge_v[i]]) begin
                                        visited[edge_v[i]] <= 1;
                                        queue[q_tail] <= edge_v[i];
                                        q_tail <= q_tail + 1;
                                    end
                                    if (edge_v[i] == node && !visited[edge_u[i]]) begin
                                        visited[edge_u[i]] <= 1;
                                        queue[q_tail] <= edge_u[i];
                                        q_tail <= q_tail + 1;
                                    end
                                end
                            end
                        end
                        // Check connectivity and tree properties
                        valid_tree <= 1;
                        // Check all nodes connected
                        for (i = 0; i < n; i = i + 1) begin
                            if (!visited[i]) valid_tree <= 0;
                        end
                        // Check tree property (n-1 edges)
                        edge_count <= 0;
                        for (i = 0; i < 28; i = i + 1) begin
                            if (edge_mask[i] && edge_valid[i]) edge_count <= edge_count + 1;
                        end
                        if (edge_count != n - 1) valid_tree <= 0;
                        // Check security (insecure buildings are leaves)
                        for (i = 0; i < 8; i = i + 1) begin
                            if (insecure_mask[i] && visited[i] && degree[i] != 1) valid_tree <= 0;
                        end
                        if (valid_tree) begin
                            state <= CALCULATE_COST;
                        end else begin
                            // Move to next subset
                            edge_mask <= edge_mask + 1;
                            if (edge_mask == 1 << total_edges) begin
                                state <= DONE;
                            end
                        end
                    end
                end
                CALCULATE_COST: begin
                    current_cost <= 0;
                    for (i = 0; i < 28; i = i + 1) begin
                        if (edge_mask[i] && edge_valid[i]) begin
                            current_cost <= current_cost + edge_w[i];
                        end
                    end
                    state <= UPDATE_BEST;
                end
                UPDATE_BEST: begin
                    if (current_cost < min_cost) begin
                        min_cost <= current_cost;
                        best_edge_mask <= edge_mask;
                    end
                    // Move to next subset
                    edge_mask <= edge_mask + 1;
                    if (edge_mask == 1 << total_edges) begin
                        state <= DONE;
                    end else begin
                        state <= CHECK_SUBSET;
                    end
                end
                DONE: begin
                    if (min_cost == 16'hFFFF) begin
                        impossible <= 1;
                    end else begin
                        result <= min_cost;
                    end
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule