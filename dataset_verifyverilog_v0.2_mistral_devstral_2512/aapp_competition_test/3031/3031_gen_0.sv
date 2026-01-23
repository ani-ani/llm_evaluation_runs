module good_nodes_finder(
    input clk,
    input rst_n,
    input start,
    input [3:0] node_count,
    input [23:0] edge_data,
    input [2:0] edge_index,
    output reg [7:0] good_nodes,
    output reg done
);

    // Define states
    typedef enum logic [1:0] {
        IDLE,
        LOAD_EDGES,
        CHECK_NODES,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Edge storage (max 7 edges for 8 nodes)
    logic [23:0] edges [0:6];
    logic [3:0] edge_count;

    // Node checking variables
    logic [3:0] current_node;
    logic [7:0] visited;
    logic [3:0] parent_color;
    logic [3:0] parent_node;
    logic [3:0] path_stack [0:6];
    logic [3:0] color_stack [0:6];
    logic [3:0] stack_ptr;

    // Temporary good node status
    logic [7:0] temp_good_nodes;

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            edge_count <= 0;
            current_node <= 0;
            visited <= 0;
            parent_color <= 0;
            parent_node <= 0;
            stack_ptr <= 0;
            temp_good_nodes <= 0;
            good_nodes <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_EDGES;
                    edge_count = 0;
                    temp_good_nodes = 0;
                end
            end
            LOAD_EDGES: begin
                if (edge_index == node_count - 2) begin
                    next_state = CHECK_NODES;
                    current_node = 1;
                    temp_good_nodes = 8'hFF; // Assume all good initially
                end
            end
            CHECK_NODES: begin
                if (current_node == node_count) begin
                    next_state = DONE;
                    good_nodes = temp_good_nodes;
                    done = 1;
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                    done = 0;
                end
            end
        endcase
    end

    // Edge loading
    always_ff @(posedge clk) begin
        if (current_state == LOAD_EDGES && edge_index < 7) begin
            edges[edge_index] <= edge_data;
            edge_count <= edge_index + 1;
        end
    end

    // Node checking logic
    always_ff @(posedge clk) begin
        if (current_state == CHECK_NODES) begin
            // Initialize for new node
            if (current_node != parent_node) begin
                visited <= 0;
                stack_ptr <= 0;
                parent_node <= current_node;
                parent_color <= 0;
                path_stack[0] <= current_node;
                color_stack[0] <= 0;
            end

            // DFS traversal
            if (stack_ptr < 7) begin
                logic [3:0] current_path_node = path_stack[stack_ptr];
                logic [3:0] current_color = color_stack[stack_ptr];
                logic node_found = 0;

                // Check all edges for children
                for (int i = 0; i < edge_count; i++) begin
                    logic [3:0] node_a = edges[i][19:16];
                    logic [3:0] node_b = edges[i][15:12];
                    logic [3:0] color = edges[i][3:0];

                    if (node_a == current_path_node && node_b != parent_node) begin
                        if (!visited[node_b - 1]) begin
                            // Check rainbow condition
                            if (current_color != 0 && current_color == color) begin
                                temp_good_nodes[current_node - 1] = 0;
                            end

                            // Push to stack
                            stack_ptr <= stack_ptr + 1;
                            path_stack[stack_ptr] <= node_b;
                            color_stack[stack_ptr] <= color;
                            visited[node_b - 1] <= 1;
                            parent_node <= current_path_node;
                            parent_color <= color;
                            node_found = 1;
                        end
                    end
                    else if (node_b == current_path_node && node_a != parent_node) begin
                        if (!visited[node_a - 1]) begin
                            // Check rainbow condition
                            if (current_color != 0 && current_color == color) begin
                                temp_good_nodes[current_node - 1] = 0;
                            end

                            // Push to stack
                            stack_ptr <= stack_ptr + 1;
                            path_stack[stack_ptr] <= node_a;
                            color_stack[stack_ptr] <= color;
                            visited[node_a - 1] <= 1;
                            parent_node <= current_path_node;
                            parent_color <= color;
                            node_found = 1;
                        end
                    end
                end

                // If no children found, pop stack
                if (!node_found && stack_ptr > 0) begin
                    stack_ptr <= stack_ptr - 1;
                    parent_node <= path_stack[stack_ptr];
                    parent_color <= color_stack[stack_ptr];
                end
                // If stack empty, move to next node
                else if (stack_ptr == 0 && node_found == 0) begin
                    current_node <= current_node + 1;
                end
            end else begin
                // Stack full, pop
                stack_ptr <= stack_ptr - 1;
                parent_node <= path_stack[stack_ptr];
                parent_color <= color_stack[stack_ptr];
            end
        end
    end

endmodule