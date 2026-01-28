module GraphCyclePartition(
    input clk,
    input rst_n,
    input start,
    input [15:0] graph_row,
    input [3:0] num_nodes,
    output reg result_valid,
    output reg output_done,
    output reg [7:0] trips [0:15],
    output reg [3:0] trip_count,
    output reg [3:0] nodes_per_trip [0:15]
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_GRAPH = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE = 3'd4;

    reg [2:0] state;
    reg [7:0] row_counter;
    reg [15:0] graph [0:15];
    reg [15:0] visited;
    reg [3:0] current_node;
    reg [3:0] trip_id;
    reg [3:0] trip_size;
    reg [3:0] trip_index;
    reg [3:0] node_index;
    reg [3:0] cycle_start;
    reg [3:0] stack [0:15];
    reg [3:0] stack_ptr;
    reg found_cycle;
    reg [7:0] cycle_nodes [0:15];
    reg [3:0] cycle_length;
    reg [3:0] cycle_ptr;
    reg [3:0] output_ptr;
    reg [7:0] cycle_count;
    reg [3:0] temp_trip_count;
    reg [3:0] temp_nodes_per_trip [0:15];
    reg [7:0] temp_trips [0:15];
    reg [3:0] i, j, k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_counter <= 8'd0;
            visited <= 16'd0;
            current_node <= 4'd0;
            trip_id <= 4'd0;
            trip_size <= 4'd0;
            trip_index <= 4'd0;
            node_index <= 4'd0;
            cycle_start <= 4'd0;
            stack_ptr <= 4'd0;
            found_cycle <= 1'b0;
            cycle_length <= 4'd0;
            cycle_ptr <= 4'd0;
            output_ptr <= 4'd0;
            cycle_count <= 8'd0;
            result_valid <= 1'b0;
            output_done <= 1'b0;
            trip_count <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                graph[i] <= 16'd0;
                nodes_per_trip[i] <= 4'd0;
                trips[i] <= 8'd0;
                temp_nodes_per_trip[i] <= 4'd0;
                temp_trips[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    output_done <= 1'b0;
                    if (start) begin
                        state <= LOAD_GRAPH;
                        row_counter <= 8'd0;
                    end
                end

                LOAD_GRAPH: begin
                    graph[row_counter] <= graph_row;
                    row_counter <= row_counter + 8'd1;
                    if (row_counter == 8'd16) begin
                        state <= PROCESS;
                        visited <= 16'd0;
                        current_node <= 4'd0;
                        trip_id <= 4'd0;
                        trip_size <= 4'd0;
                        trip_index <= 4'd0;
                        node_index <= 4'd0;
                        cycle_start <= 4'd0;
                        stack_ptr <= 4'd0;
                        found_cycle <= 1'b0;
                        cycle_length <= 4'd0;
                        cycle_ptr <= 4'd0;
                        output_ptr <= 4'd0;
                        cycle_count <= 8'd0;
                        temp_trip_count <= 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            temp_nodes_per_trip[i] <= 4'd0;
                            temp_trips[i] <= 8'd0;
                        end
                    end
                end

                PROCESS: begin
                    // Check for nodes with zero in-degree or out-degree (except self-loops)
                    reg [15:0] in_degree;
                    reg [15:0] out_degree;
                    reg impossible;
                    impossible <= 1'b0;

                    // Calculate in-degree and out-degree
                    for (i = 0; i < 16; i = i + 1) begin
                        out_degree[i] <= 1'b0;
                        for (j = 0; j < 16; j = j + 1) begin
                            if (graph[i][j]) begin
                                out_degree[i] <= 1'b1;
                            end
                        end
                    end

                    for (i = 0; i < 16; i = i + 1) begin
                        in_degree[i] <= 1'b0;
                        for (j = 0; j < 16; j = j + 1) begin
                            if (graph[j][i]) begin
                                in_degree[i] <= 1'b1;
                            end
                        end
                    end

                    // Check for impossible cases
                    for (i = 0; i < num_nodes; i = i + 1) begin
                        if ((!out_degree[i] && !graph[i][i]) || (!in_degree[i] && !graph[i][i])) begin
                            impossible <= 1'b1;
                        end
                    end

                    if (impossible) begin
                        result_valid <= 1'b0;
                        state <= DONE;
                    end else begin
                        // Find cycles
                        if (current_node < num_nodes && !visited[current_node]) begin
                            // Start DFS from current_node
                            cycle_start <= current_node;
                            stack[0] <= current_node;
                            stack_ptr <= 4'd1;
                            found_cycle <= 1'b0;
                            cycle_length <= 4'd0;
                            cycle_ptr <= 4'd0;

                            // DFS to find cycle
                            for (i = 0; i < 16; i = i + 1) begin
                                cycle_nodes[i] <= 8'd0;
                            end

                            // Simple cycle detection (for synthesis, we'll use iterative approach)
                            // This is a simplified version - in real implementation, use proper DFS
                            reg [3:0] next_node;
                            next_node <= 4'd0;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (graph[current_node][i] && i != current_node && !visited[i]) begin
                                    next_node <= i;
                                    break;
                                end
                            end

                            if (next_node != 4'd0) begin
                                // Found a cycle
                                found_cycle <= 1'b1;
                                cycle_nodes[0] <= current_node;
                                cycle_nodes[1] <= next_node;
                                cycle_length <= 4'd2;
                                cycle_ptr <= 4'd2;

                                // Mark nodes as visited
                                visited[current_node] <= 1'b1;
                                visited[next_node] <= 1'b1;

                                // Store trip
                                temp_trips[trip_index] <= {trip_id, current_node, 1'b0};
                                trip_index <= trip_index + 4'd1;
                                temp_trips[trip_index] <= {trip_id, next_node, 1'b1};
                                trip_index <= trip_index + 4'd1;
                                temp_nodes_per_trip[trip_id] <= 4'd2;
                                trip_id <= trip_id + 4'd1;
                                temp_trip_count <= temp_trip_count + 4'd1;
                            end else if (graph[current_node][current_node]) begin
                                // Self-loop
                                found_cycle <= 1'b1;
                                cycle_nodes[0] <= current_node;
                                cycle_length <= 4'd1;
                                cycle_ptr <= 4'd1;

                                // Mark node as visited
                                visited[current_node] <= 1'b1;

                                // Store trip
                                temp_trips[trip_index] <= {trip_id, current_node, 1'b1};
                                trip_index <= trip_index + 4'd1;
                                temp_nodes_per_trip[trip_id] <= 4'd1;
                                trip_id <= trip_id + 4'd1;
                                temp_trip_count <= temp_trip_count + 4'd1;
                            end

                            if (found_cycle) begin
                                current_node <= current_node + 4'd1;
                            end else begin
                                // Could not find cycle for this node
                                result_valid <= 1'b0;
                                state <= DONE;
                            end
                        end else begin
                            // All nodes processed
                            result_valid <= 1'b1;
                            state <= OUTPUT;
                        end
                    end
                end

                OUTPUT: begin
                    // Copy temp results to outputs
                    for (i = 0; i < 16; i = i + 1) begin
                        nodes_per_trip[i] <= temp_nodes_per_trip[i];
                        trips[i] <= temp_trips[i];
                    end
                    trip_count <= temp_trip_count;
                    state <= DONE;
                end

                DONE: begin
                    output_done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule