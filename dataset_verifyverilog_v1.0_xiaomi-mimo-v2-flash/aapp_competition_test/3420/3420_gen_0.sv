module book_circle_presentations (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_boys,
    input wire [3:0] num_girls,
    input wire [191:0] book_edges,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] POPULATE_MATRIX = 3'd1;
    localparam [2:0] FIND_COMPONENTS = 3'd2;
    localparam [2:0] TRAVERSE        = 3'd3;
    localparam [2:0] FINISHED        = 3'd4;

    // Registers for state machine
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Control registers
    reg [7:0] component_count;
    reg [7:0] current_node;
    reg [4:0] edge_counter; // 24 edges, needs 5 bits
    
    // Data structures
    // Adjacency matrix: 16x16 bits (256 bits total)
    reg [15:0] adjacency_matrix [0:15];
    reg [15:0] visited;
    
    // BFS Queue: implemented as circular buffer
    reg [3:0] queue [0:15]; // 16 entries, 4 bits each
    reg [4:0] queue_head; // 5 bits to handle empty/full condition
    reg [4:0] queue_tail;
    
    // Loop counters
    reg [3:0] node_idx;
    reg [3:0] neighbor_idx;
    
    // Cycle counter to prevent infinite loops
    reg [10:0] cycle_count;
    localparam [10:0] MAX_CYCLES = 11'd1024;

    // Synchronous logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            component_count <= 8'd0;
            current_node <= 4'd0;
            edge_counter <= 5'd0;
            visited <= 16'd0;
            queue_head <= 5'd0;
            queue_tail <= 5'd0;
            node_idx <= 4'd0;
            neighbor_idx <= 4'd0;
            cycle_count <= 11'd0;
            // Initialize adjacency matrix
            for (int i = 0; i < 16; i = i + 1) begin
                adjacency_matrix[i] <= 16'd0;
            end
            // Initialize queue
            for (int i = 0; i < 16; i = i + 1) begin
                queue[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 11'd0;
                    if (start) begin
                        state <= POPULATE_MATRIX;
                        edge_counter <= 5'd0;
                        component_count <= 8'd0;
                        visited <= 16'd0;
                        // Initialize adjacency matrix to zeros
                        for (int i = 0; i < 16; i = i + 1) begin
                            adjacency_matrix[i] <= 16'd0;
                        end
                    end
                end

                POPULATE_MATRIX: begin
                    if (edge_counter < 5'd24) begin
                        // Extract boy and girl indices from current edge
                        // Each edge is 8 bits: [7:4] boy, [3:0] girl
                        // Total 24 edges: edges 0-23
                        // book_edges[(edge_counter*8)+7 : (edge_counter*8)]
                        case (edge_counter)
                            5'd0: begin
                                if (book_edges[7:4] < num_boys && book_edges[3:0] < num_girls) begin
                                    adjacency_matrix[book_edges[7:4]] <= adjacency_matrix[book_edges[7:4]] | (16'd1 << book_edges[3:0]);
                                    adjacency_matrix[book_edges[3:0] + 8'd8] <= adjacency_matrix[book_edges[3:0] + 8'd8] | (16'd1 << book_edges[7:4]);
                                end
                            end
                            5'd1: begin
                                if (book_edges[15:12] < num_boys && book_edges[11:8] < num_girls) begin
                                    adjacency_matrix[book_edges[15:12]] <= adjacency_matrix[book_edges[15:12]] | (16'd1 << book_edges[11:8]);
                                    adjacency_matrix[book_edges[11:8] + 8'd8] <= adjacency_matrix[book_edges[11:8] + 8'd8] | (16'd1 << book_edges[15:12]);
                                end
                            end
                            5'd2: begin
                                if (book_edges[23:20] < num_boys && book_edges[19:16] < num_girls) begin
                                    adjacency_matrix[book_edges[23:20]] <= adjacency_matrix[book_edges[23:20]] | (16'd1 << book_edges[19:16]);
                                    adjacency_matrix[book_edges[19:16] + 8'd8] <= adjacency_matrix[book_edges[19:16] + 8'd8] | (16'd1 << book_edges[23:20]);
                                end
                            end
                            5'd3: begin
                                if (book_edges[31:28] < num_boys && book_edges[27:24] < num_girls) begin
                                    adjacency_matrix[book_edges[31:28]] <= adjacency_matrix[book_edges[31:28]] | (16'd1 << book_edges[27:24]);
                                    adjacency_matrix[book_edges[27:24] + 8'd8] <= adjacency_matrix[book_edges[27:24] + 8'd8] | (16'd1 << book_edges[31:28]);
                                end
                            end
                            5'd4: begin
                                if (book_edges[39:36] < num_boys && book_edges[35:32] < num_girls) begin
                                    adjacency_matrix[book_edges[39:36]] <= adjacency_matrix[book_edges[39:36]] | (16'd1 << book_edges[35:32]);
                                    adjacency_matrix[book_edges[35:32] + 8'd8] <= adjacency_matrix[book_edges[35:32] + 8'd8] | (16'd1 << book_edges[39:36]);
                                end
                            end
                            5'd5: begin
                                if (book_edges[47:44] < num_boys && book_edges[43:40] < num_girls) begin
                                    adjacency_matrix[book_edges[47:44]] <= adjacency_matrix[book_edges[47:44]] | (16'd1 << book_edges[43:40]);
                                    adjacency_matrix[book_edges[43:40] + 8'd8] <= adjacency_matrix[book_edges[43:40] + 8'd8] | (16'd1 << book_edges[47:44]);
                                end
                            end
                            5'd6: begin
                                if (book_edges[55:52] < num_boys && book_edges[51:48] < num_girls) begin
                                    adjacency_matrix[book_edges[55:52]] <= adjacency_matrix[book_edges[55:52]] | (16'd1 << book_edges[51:48]);
                                    adjacency_matrix[book_edges[51:48] + 8'd8] <= adjacency_matrix[book_edges[51:48] + 8'd8] | (16'd1 << book_edges[55:52]);
                                end
                            end
                            5'd7: begin
                                if (book_edges[63:60] < num_boys && book_edges[59:56] < num_girls) begin
                                    adjacency_matrix[book_edges[63:60]] <= adjacency_matrix[book_edges[63:60]] | (16'd1 << book_edges[59:56]);
                                    adjacency_matrix[book_edges[59:56] + 8'd8] <= adjacency_matrix[book_edges[59:56] + 8'd8] | (16'd1 << book_edges[63:60]);
                                end
                            end
                            5'd8: begin
                                if (book_edges[71:68] < num_boys && book_edges[67:64] < num_girls) begin
                                    adjacency_matrix[book_edges[71:68]] <= adjacency_matrix[book_edges[71:68]] | (16'd1 << book_edges[67:64]);
                                    adjacency_matrix[book_edges[67:64] + 8'd8] <= adjacency_matrix[book_edges[67:64] + 8'd8] | (16'd1 << book_edges[71:68]);
                                end
                            end
                            5'd9: begin
                                if (book_edges[79:76] < num_boys && book_edges[75:72] < num_girls) begin
                                    adjacency_matrix[book_edges[79:76]] <= adjacency_matrix[book_edges[79:76]] | (16'd1 << book_edges[75:72]);
                                    adjacency_matrix[book_edges[75:72] + 8'd8] <= adjacency_matrix[book_edges[75:72] + 8'd8] | (16'd1 << book_edges[79:76]);
                                end
                            end
                            5'd10: begin
                                if (book_edges[87:84] < num_boys && book_edges[83:80] < num_girls) begin
                                    adjacency_matrix[book_edges[87:84]] <= adjacency_matrix[book_edges[87:84]] | (16'd1 << book_edges[83:80]);
                                    adjacency_matrix[book_edges[83:80] + 8'd8] <= adjacency_matrix[book_edges[83:80] + 8'd8] | (16'd1 << book_edges[87:84]);
                                end
                            end
                            5'd11: begin
                                if (book_edges[95:92] < num_boys && book_edges[91:88] < num_girls) begin
                                    adjacency_matrix[book_edges[95:92]] <= adjacency_matrix[book_edges[95:92]] | (16'd1 << book_edges[91:88]);
                                    adjacency_matrix[book_edges[91:88] + 8'd8] <= adjacency_matrix[book_edges[91:88] + 8'd8] | (16'd1 << book_edges[95:92]);
                                end
                            end
                            5'd12: begin
                                if (book_edges[103:100] < num_boys && book_edges[99:96] < num_girls) begin
                                    adjacency_matrix[book_edges[103:100]] <= adjacency_matrix[book_edges[103:100]] | (16'd1 << book_edges[99:96]);
                                    adjacency_matrix[book_edges[99:96] + 8'd8] <= adjacency_matrix[book_edges[99:96] + 8'd8] | (16'd1 << book_edges[103:100]);
                                end
                            end
                            5'd13: begin
                                if (book_edges[111:108] < num_boys && book_edges[107:104] < num_girls) begin
                                    adjacency_matrix[book_edges[111:108]] <= adjacency_matrix[book_edges[111:108]] | (16'd1 << book_edges[107:104]);
                                    adjacency_matrix[book_edges[107:104] + 8'd8] <= adjacency_matrix[book_edges[107:104] + 8'd8] | (16'd1 << book_edges[111:108]);
                                end
                            end
                            5'd14: begin
                                if (book_edges[119:116] < num_boys && book_edges[115:112] < num_girls) begin
                                    adjacency_matrix[book_edges[119:116]] <= adjacency_matrix[book_edges[119:116]] | (16'd1 << book_edges[115:112]);
                                    adjacency_matrix[book_edges[115:112] + 8'd8] <= adjacency_matrix[book_edges[115:112] + 8'd8] | (16'd1 << book_edges[119:116]);
                                end
                            end
                            5'd15: begin
                                if (book_edges[127:124] < num_boys && book_edges[123:120] < num_girls) begin
                                    adjacency_matrix[book_edges[127:124]] <= adjacency_matrix[book_edges[127:124]] | (16'd1 << book_edges[123:120]);
                                    adjacency_matrix[book_edges[123:120] + 8'd8] <= adjacency_matrix[book_edges[123:120] + 8'd8] | (16'd1 << book_edges[127:124]);
                                end
                            end
                            5'd16: begin
                                if (book_edges[135:132] < num_boys && book_edges[131:128] < num_girls) begin
                                    adjacency_matrix[book_edges[135:132]] <= adjacency_matrix[book_edges[135:132]] | (16'd1 << book_edges[131:128]);
                                    adjacency_matrix[book_edges[131:128] + 8'd8] <= adjacency_matrix[book_edges[131:128] + 8'd8] | (16'd1 << book_edges[135:132]);
                                end
                            end
                            5'd17: begin
                                if (book_edges[143:140] < num_boys && book_edges[139:136] < num_girls) begin
                                    adjacency_matrix[book_edges[143:140]] <= adjacency_matrix[book_edges[143:140]] | (16'd1 << book_edges[139:136]);
                                    adjacency_matrix[book_edges[139:136] + 8'd8] <= adjacency_matrix[book_edges[139:136] + 8'd8] | (16'd1 << book_edges[143:140]);
                                end
                            end
                            5'd18: begin
                                if (book_edges[151:148] < num_boys && book_edges[147:144] < num_girls) begin
                                    adjacency_matrix[book_edges[151:148]] <= adjacency_matrix[book_edges[151:148]] | (16'd1 << book_edges[147:144]);
                                    adjacency_matrix[book_edges[147:144] + 8'd8] <= adjacency_matrix[book_edges[147:144] + 8'd8] | (16'd1 << book_edges[151:148]);
                                end
                            end
                            5'd19: begin
                                if (book_edges[159:156] < num_boys && book_edges[155:152] < num_girls) begin
                                    adjacency_matrix[book_edges[159:156]] <= adjacency_matrix[book_edges[159:156]] | (16'd1 << book_edges[155:152]);
                                    adjacency_matrix[book_edges[155:152] + 8'd8] <= adjacency_matrix[book_edges[155:152] + 8'd8] | (16'd1 << book_edges[159:156]);
                                end
                            end
                            5'd20: begin
                                if (book_edges[167:164] < num_boys && book_edges[163:160] < num_girls) begin
                                    adjacency_matrix[book_edges[167:164]] <= adjacency_matrix[book_edges[167:164]] | (16'd1 << book_edges[163:160]);
                                    adjacency_matrix[book_edges[163:160] + 8'd8] <= adjacency_matrix[book_edges[163:160] + 8'd8] | (16'd1 << book_edges[167:164]);
                                end
                            end
                            5'd21: begin
                                if (book_edges[175:172] < num_boys && book_edges[171:168] < num_girls) begin
                                    adjacency_matrix[book_edges[175:172]] <= adjacency_matrix[book_edges[175:172]] | (16'd1 << book_edges[171:168]);
                                    adjacency_matrix[book_edges[171:168] + 8'd8] <= adjacency_matrix[book_edges[171:168] + 8'd8] | (16'd1 << book_edges[175:172]);
                                end
                            end
                            5'd22: begin
                                if (book_edges[183:180] < num_boys && book_edges[179:176] < num_girls) begin
                                    adjacency_matrix[book_edges[183:180]] <= adjacency_matrix[book_edges[183:180]] | (16'd1 << book_edges[179:176]);
                                    adjacency_matrix[book_edges[179:176] + 8'd8] <= adjacency_matrix[book_edges[179:176] + 8'd8] | (16'd1 << book_edges[183:180]);
                                end
                            end
                            5'd23: begin
                                if (book_edges[191:188] < num_boys && book_edges[187:184] < num_girls) begin
                                    adjacency_matrix[book_edges[191:188]] <= adjacency_matrix[book_edges[191:188]] | (16'd1 << book_edges[187:184]);
                                    adjacency_matrix[book_edges[187:184] + 8'd8] <= adjacency_matrix[book_edges[187:184] + 8'd8] | (16'd1 << book_edges[191:188]);
                                end
                            end
                        endcase
                        edge_counter <= edge_counter + 5'd1;
                    end else begin
                        state <= FIND_COMPONENTS;
                        node_idx <= 4'd0;
                        cycle_count <= cycle_count + 11'd1;
                    end
                end

                FIND_COMPONENTS: begin
                    // Check if we have processed all nodes
                    if (node_idx < (num_boys + num_girls)) begin
                        // Check if current node is visited
                        if (!visited[node_idx]) begin
                            // Start new component traversal
                            component_count <= component_count + 8'd1;
                            visited[node_idx] <= 1'b1;
                            // Initialize BFS queue
                            queue_head <= 5'd0;
                            queue_tail <= 5'd0;
                            queue[0] <= node_idx;
                            queue_tail <= 5'd1;
                            // Move to traverse state
                            state <= TRAVERSE;
                            cycle_count <= cycle_count + 11'd1;
                        end else begin
                            // Node already visited, move to next
                            node_idx <= node_idx + 4'd1;
                            cycle_count <= cycle_count + 11'd1;
                        end
                    end else begin
                        // All nodes processed
                        state <= FINISHED;
                        cycle_count <= cycle_count + 11'd1;
                    end
                    // Check for cycle limit
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISHED;
                    end
                end

                TRAVERSE: begin
                    // BFS traversal: process nodes in queue
                    if (queue_head != queue_tail) begin
                        // Pop from queue
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 5'd1;
                        neighbor_idx <= 4'd0;
                        cycle_count <= cycle_count + 11'd1;
                        // Continue traversal (stay in TRAVERSE to process neighbors)
                    end else begin
                        // Queue empty, go back to FIND_COMPONENTS
                        state <= FIND_COMPONENTS;
                        node_idx <= node_idx + 4'd1;
                        cycle_count <= cycle_count + 11'd1;
                    end
                    // Check for cycle limit
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISHED;
                    end
                end

                // Special case: When we pop a node, we need to check its neighbors
                // We'll use neighbor_idx to iterate through all possible neighbors
                // This requires additional logic outside the case statement

                FINISHED: begin
                    result <= component_count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Additional combinational logic for processing neighbors
    // This runs when in TRAVERSE state and we have a current_node
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Handled in main always block
        end else if (state == TRAVERSE && queue_head != queue_tail) begin
            // We just popped a node, now check its neighbors in next cycle
            // Use neighbor_idx to iterate through all 16 possible neighbors
            if (neighbor_idx < 4'd16) begin
                // Check if there's an edge and neighbor not visited
                if (adjacency_matrix[current_node][neighbor_idx] && !visited[neighbor_idx]) begin
                    visited[neighbor_idx] <= 1'b1;
                    // Add to queue if not full
                    if (queue_tail < 5'd16) begin
                        queue[queue_tail] <= neighbor_idx;
                        queue_tail <= queue_tail + 5'd1;
                    end
                end
                neighbor_idx <= neighbor_idx + 4'd1;
            end
        end
    end

endmodule