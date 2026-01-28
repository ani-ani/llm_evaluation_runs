module GraphPartitioner(
    input clk,
    input rst_n,
    input start,
    input [15:0] graph_row,  // Sequential input for rows
    input [3:0] num_nodes,
    output reg result_valid,
    output reg output_done,
    output reg [15:0] trips [0:15],  // {trip_id[3:0], node_id[3:0], last[0]} packed
    output reg [3:0] trip_count,
    output reg [3:0] nodes_per_trip [0:15]
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] LOAD_GRAPH    = 3'd1;
    localparam [2:0] CHECK_DEGREES = 3'd2;
    localparam [2:0] FIND_CYCLES   = 3'd3;
    localparam [2:0] PACK_OUTPUT   = 3'd4;
    localparam [2:0] DONE          = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] row_counter;
    reg [3:0] current_node;
    reg [3:0] start_node;
    reg [15:0] visited;
    reg [3:0] trip_idx;
    reg [3:0] node_idx;
    reg [3:0] out_deg [0:15];
    reg [3:0] in_deg [0:15];
    reg [15:0] cycle_nodes [0:15];
    reg [3:0] cycle_len;
    reg [3:0] stack [0:15];
    reg [3:0] stack_ptr;
    reg [3:0] cycle_id;
    reg [7:0] cycle_count;
    reg [3:0] output_ptr;
    reg degree_error;
    reg [15:0] graph [0:15];
    reg [3:0] i, j, k;
    reg found_cycle;
    reg [3:0] temp_node;
    reg [3:0] next_node;
    reg self_loop_found;
    reg [3:0] valid_nodes;
    reg [3:0] nodes_traversed;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            output_done <= 1'b0;
            trip_count <= 4'd0;
            row_counter <= 4'd0;
            current_node <= 4'd0;
            start_node <= 4'd0;
            visited <= 16'd0;
            trip_idx <= 4'd0;
            node_idx <= 4'd0;
            cycle_len <= 4'd0;
            stack_ptr <= 4'd0;
            cycle_id <= 4'd0;
            cycle_count <= 8'd0;
            output_ptr <= 4'd0;
            degree_error <= 1'b0;
            found_cycle <= 1'b0;
            self_loop_found <= 1'b0;
            valid_nodes <= 4'd0;
            nodes_traversed <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                trips[i] <= 16'd0;
                nodes_per_trip[i] <= 4'd0;
                out_deg[i] <= 4'd0;
                in_deg[i] <= 4'd0;
                graph[i] <= 16'd0;
                cycle_nodes[i] <= 16'd0;
                stack[i] <= 4'd0;
            end
        end else begin
            output_done <= 1'b0;
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    row_counter <= 4'd0;
                    visited <= 16'd0;
                    trip_idx <= 4'd0;
                    cycle_id <= 4'd0;
                    degree_error <= 1'b0;
                    valid_nodes <= 4'd0;
                    if (start) begin
                        state <= LOAD_GRAPH;
                    end
                end

                LOAD_GRAPH: begin
                    graph[row_counter] <= graph_row;
                    row_counter <= row_counter + 4'd1;
                    if (row_counter == num_nodes) begin
                        state <= CHECK_DEGREES;
                        row_counter <= 4'd0;
                    end
                end

                CHECK_DEGREES: begin
                    // Reset degrees
                    for (i = 0; i < 16; i = i + 1) begin
                        out_deg[i] <= 4'd0;
                        in_deg[i] <= 4'd0;
                    end
                    state <= FIND_CYCLES;
                end

                FIND_CYCLES: begin
                    // Calculate degrees and check for immediate impossibility
                    if (row_counter < num_nodes) begin
                        for (j = 0; j < num_nodes; j = j + 1) begin
                            if (graph[row_counter][j]) begin
                                if (j != row_counter) begin
                                    out_deg[row_counter] <= out_deg[row_counter] + 4'd1;
                                end
                            end
                            if (graph[j][row_counter]) begin
                                if (j != row_counter) begin
                                    in_deg[row_counter] <= in_deg[row_counter] + 4'd1;
                                end
                            end
                        end
                        row_counter <= row_counter + 4'd1;
                    end else if (row_counter < num_nodes + 4'd1) begin
                        // Check degrees after calculation
                        // Node must have in_deg > 0 OR out_deg > 0 OR self-loop
                        if ((out_deg[row_counter - 4'd1] == 4'd0) && (in_deg[row_counter - 4'd1] == 4'd0)) begin
                            // Check if self-loop exists
                            self_loop_found = 1'b0;
                            if (graph[row_counter - 4'd1][row_counter - 4'd1]) begin
                                self_loop_found = 1'b1;
                            end
                            if (!self_loop_found) begin
                                degree_error <= 1'b1;
                            end
                        end
                        // Additional check: if out_deg == 0 and no self-loop, impossible
                        if ((out_deg[row_counter - 4'd1] == 4'd0) && !graph[row_counter - 4'd1][row_counter - 4'd1]) begin
                            degree_error <= 1'b1;
                        end
                        // Additional check: if in_deg == 0 and no self-loop, impossible
                        if ((in_deg[row_counter - 4'd1] == 4'd0) && !graph[row_counter - 4'd1][row_counter - 4'd1]) begin
                            degree_error <= 1'b1;
                        end
                        row_counter <= row_counter + 4'd1;
                    end else begin
                        row_counter <= 4'd0;
                        if (degree_error) begin
                            result_valid <= 1'b0;
                            state <= DONE;
                        end else begin
                            // Initialize cycle finding
                            visited <= 16'd0;
                            trip_idx <= 4'd0;
                            cycle_id <= 4'd0;
                            state <= PACK_OUTPUT;  // Try to find cycles
                        end
                    end
                end

                PACK_OUTPUT: begin
                    // Find unvisited node
                    if (valid_nodes < num_nodes) begin
                        if (start_node < num_nodes) begin
                            if (!visited[start_node]) begin
                                // Start cycle finding from start_node
                                found_cycle <= 1'b0;
                                cycle_len <= 4'd0;
                                stack_ptr <= 4'd0;
                                current_node <= start_node;
                                visited[start_node] <= 1'b1;
                                nodes_traversed <= 4'd1;
                                stack[0] <= start_node;
                                stack_ptr <= 4'd1;
                                state <= PACK_OUTPUT;  // Stay in same state for DFS
                            end else begin
                                start_node <= start_node + 4'd1;
                            end
                        end else begin
                            // All nodes visited
                            if (valid_nodes < num_nodes) begin
                                result_valid <= 1'b0;
                                state <= DONE;
                            end else begin
                                result_valid <= 1'b1;
                                state <= DONE;
                            end
                        end
                    end else begin
                        result_valid <= 1'b1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    output_done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for cycle finding and traversal
    always @(*) begin
        // Default values
        found_cycle = 1'b0;
        cycle_len = 4'd0;
        next_node = 4'd0;
        
        if (state == PACK_OUTPUT) begin
            if (stack_ptr > 0) begin
                temp_node = stack[stack_ptr - 4'd1];
                
                // Check for cycle
                for (j = 0; j < num_nodes; j = j + 1) begin
                    if (graph[temp_node][j] && (j == start_node) && (stack_ptr > 4'd1)) begin
                        found_cycle = 1'b1;
                        cycle_len = stack_ptr;
                    end
                end
                
                // Check self-loop
                if (!found_cycle && graph[temp_node][temp_node]) begin
                    found_cycle = 1'b1;
                    cycle_len = 4'd1;
                end
            end
        end
    end

endmodule