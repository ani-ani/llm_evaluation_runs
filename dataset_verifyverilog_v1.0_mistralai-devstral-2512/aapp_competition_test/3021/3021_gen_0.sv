module alphabet_order(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0][7:0] word1_arr,
    input wire [15:0][7:0] word2_arr,
    input wire [3:0] num_pairs,
    input wire [3:0] max_char_idx,
    output reg [63:0] result_order,
    output reg [2:0] status,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] EDGE_EXTRACT = 3'd1;
    localparam [2:0] CYCLE_DETECT = 3'd2;
    localparam [2:0] TOPO_SORT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Edge extraction variables
    reg [3:0] pair_idx;
    reg [2:0] char_idx;
    reg [3:0] char1, char2;
    reg edge_found;
    reg [15:0][15:0] adj_matrix;

    // Cycle detection and topological sort variables
    reg [3:0] node_idx;
    reg [3:0] queue_idx;
    reg [3:0] result_idx;
    reg [3:0] zero_degree_count;
    reg [3:0] degree [0:15];
    reg [3:0] queue [0:15];
    reg [3:0] result [0:15];
    reg [3:0] visited [0:15];
    reg [3:0] in_degree [0:15];
    reg cycle_detected;
    reg ambiguous;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 10'd0;
            pair_idx <= 4'd0;
            char_idx <= 3'd0;
            char1 <= 4'd0;
            char2 <= 4'd0;
            edge_found <= 1'b0;
            node_idx <= 4'd0;
            queue_idx <= 4'd0;
            result_idx <= 4'd0;
            zero_degree_count <= 4'd0;
            cycle_detected <= 1'b0;
            ambiguous <= 1'b0;
            done <= 1'b0;
            status <= 3'd0;
            result_order <= 64'd0;

            // Initialize adjacency matrix
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    adj_matrix[i][j] <= 1'b0;
                end
            end

            // Initialize degree arrays
            for (i = 0; i < 16; i = i + 1) begin
                degree[i] <= 4'd0;
                in_degree[i] <= 4'd0;
                visited[i] <= 4'd0;
                result[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        state <= EDGE_EXTRACT;
                    end
                end

                EDGE_EXTRACT: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (pair_idx < num_pairs) begin
                        if (!edge_found) begin
                            char1 <= word1_arr[pair_idx][char_idx];
                            char2 <= word2_arr[pair_idx][char_idx];

                            if (char1 == 8'd0 && char2 == 8'd0) begin
                                // Both words ended, no edge
                                edge_found <= 1'b0;
                                pair_idx <= pair_idx + 4'd1;
                                char_idx <= 3'd0;
                            end else if (char1 == 8'd0) begin
                                // w1 is prefix of w2, valid
                                edge_found <= 1'b0;
                                pair_idx <= pair_idx + 4'd1;
                                char_idx <= 3'd0;
                            end else if (char2 == 8'd0) begin
                                // w2 is prefix of w1, invalid
                                status <= 3'd1;
                                state <= FINISH;
                            end else if (char1 != char2) begin
                                // Found edge
                                adj_matrix[char1 - 8'd"a"][char2 - 8'd"a"] <= 1'b1;
                                edge_found <= 1'b1;
                            end else begin
                                char_idx <= char_idx + 3'd1;
                            end
                        end else begin
                            edge_found <= 1'b0;
                            pair_idx <= pair_idx + 4'd1;
                            char_idx <= 3'd0;
                        end
                    end else begin
                        state <= CYCLE_DETECT;
                    end
                end

                CYCLE_DETECT: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (node_idx < 16) begin
                        if (!visited[node_idx]) begin
                            // Check for cycles using DFS
                            integer j;
                            reg [3:0] stack [0:15];
                            reg [3:0] stack_ptr;
                            reg [3:0] current;
                            reg [15:0] visited_temp;

                            stack_ptr <= 4'd0;
                            stack[stack_ptr] <= node_idx;
                            stack_ptr <= stack_ptr + 4'd1;
                            visited_temp <= 16'd0;

                            while (stack_ptr > 4'd0) begin
                                current <= stack[stack_ptr - 4'd1];
                                stack_ptr <= stack_ptr - 4'd1;

                                if (visited_temp[current]) begin
                                    cycle_detected <= 1'b1;
                                    break;
                                end

                                visited_temp[current] <= 1'b1;

                                for (j = 0; j < 16; j = j + 1) begin
                                    if (adj_matrix[current][j]) begin
                                        stack[stack_ptr] <= j;
                                        stack_ptr <= stack_ptr + 4'd1;
                                    end
                                end
                            end

                            visited[node_idx] <= 4'd1;
                        end
                        node_idx <= node_idx + 4'd1;
                    end else begin
                        if (cycle_detected) begin
                            status <= 3'd1;
                            state <= FINISH;
                        end else begin
                            state <= TOPO_SORT;
                        end
                    end
                end

                TOPO_SORT: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (node_idx < 16) begin
                        // Calculate in-degrees
                        integer j;
                        for (j = 0; j < 16; j = j + 1) begin
                            if (adj_matrix[j][node_idx]) begin
                                in_degree[node_idx] <= in_degree[node_idx] + 4'd1;
                            end
                        end
                        node_idx <= node_idx + 4'd1;
                    end else if (queue_idx < 16) begin
                        // Initialize queue with zero-degree nodes
                        if (in_degree[queue_idx] == 4'd0 && queue_idx <= max_char_idx) begin
                            queue[zero_degree_count] <= queue_idx;
                            zero_degree_count <= zero_degree_count + 4'd1;
                        end
                        queue_idx <= queue_idx + 4'd1;
                    end else if (result_idx < 16) begin
                        if (zero_degree_count > 4'd1) begin
                            ambiguous <= 1'b1;
                        end

                        if (zero_degree_count > 4'd0) begin
                            // Process node
                            integer j;
                            result[result_idx] <= queue[0];
                            result_idx <= result_idx + 4'd1;

                            // Remove node from queue
                            for (j = 0; j < zero_degree_count - 4'd1; j = j + 1) begin
                                queue[j] <= queue[j + 4'd1];
                            end
                            zero_degree_count <= zero_degree_count - 4'd1;

                            // Update in-degrees
                            for (j = 0; j < 16; j = j + 1) begin
                                if (adj_matrix[result[result_idx - 4'd1]][j]) begin
                                    in_degree[j] <= in_degree[j] - 4'd1;
                                    if (in_degree[j] == 4'd0 && j <= max_char_idx) begin
                                        queue[zero_degree_count] <= j;
                                        zero_degree_count <= zero_degree_count + 4'd1;
                                    end
                                end
                            end
                        end else if (result_idx != max_char_idx + 4'd1) begin
                            ambiguous <= 1'b1;
                            state <= FINISH;
                        end else begin
                            state <= FINISH;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    if (cycle_detected) begin
                        status <= 3'd1;
                    end else if (ambiguous) begin
                        status <= 3'd2;
                    end else begin
                        status <= 3'd0;
                        // Pack result into result_order
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            result_order[i*4 +: 4] <= result[i];
                        end
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule