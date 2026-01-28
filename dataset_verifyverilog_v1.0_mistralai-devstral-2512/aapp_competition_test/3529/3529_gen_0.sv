module spanning_tree_check(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [15:0] blue_adj [0:15],
    input [15:0] red_adj [0:15],
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_PARAMS = 3'd1;
    localparam [2:0] GENERATE_COMB = 3'd2;
    localparam [2:0] CHECK_CONNECTIVITY = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [3:0] node_count;
    reg [3:0] blue_edge_count;
    reg [15:0] current_edges;
    reg [3:0] current_node;
    reg [3:0] visited_count;
    reg [15:0] visited;
    reg [3:0] stack_ptr;
    reg [3:0] stack [0:15];
    reg found;

    // Constants
    localparam [7:0] MAX_CYCLES = 8'd256;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            node_count <= 4'd0;
            blue_edge_count <= 4'd0;
            current_edges <= 16'd0;
            current_node <= 4'd0;
            visited_count <= 4'd0;
            visited <= 16'd0;
            stack_ptr <= 4'd0;
            found <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CHECK_PARAMS;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_PARAMS: begin
                    node_count <= n - 4'd1;  // Convert to 0-indexed count
                    blue_edge_count <= k;
                    
                    // Check if k is valid
                    if (k >= n || k < 4'd0) begin
                        result <= 1'b0;
                        next_state <= FINISH;
                    end else begin
                        current_edges <= 16'd0;
                        next_state <= GENERATE_COMB;
                    end
                end

                GENERATE_COMB: begin
                    // Generate next combination of blue edges
                    // This is a simplified approach - in practice would need a more sophisticated
                    // combinatorial generator, but for synthesis we'll use a counter-based approach
                    
                    // Increment current_edges to try next combination
                    current_edges <= current_edges + 16'd1;
                    
                    // Check if we've tried all possible combinations
                    if (cycle_count >= MAX_CYCLES - 8'd1) begin
                        result <= 1'b0;
                        next_state <= FINISH;
                    end else begin
                        next_state <= CHECK_CONNECTIVITY;
                    end
                end

                CHECK_CONNECTIVITY: begin
                    // Check if current_edges forms a spanning tree with exactly k blue edges
                    // This is a simplified BFS implementation
                    
                    // Initialize visited array
                    visited <= 16'd0;
                    visited_count <= 4'd0;
                    stack_ptr <= 4'd0;
                    
                    // Start BFS from node 0
                    stack[0] <= 4'd0;
                    stack_ptr <= 4'd1;
                    visited[0] <= 1'b1;
                    visited_count <= 4'd1;
                    
                    // Count blue edges in current_edges
                    reg [3:0] temp_blue_count;
                    integer i, j;
                    temp_blue_count = 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            if (current_edges[i*16 + j] && blue_adj[i][j]) begin
                                temp_blue_count = temp_blue_count + 4'd1;
                            end
                        end
                    end
                    
                    // Check if blue edge count matches k
                    if (temp_blue_count == blue_edge_count) begin
                        // Perform BFS
                        reg [3:0] current;
                        reg [3:0] neighbor;
                        reg [3:0] edge_count;
                        
                        edge_count = 4'd0;
                        for (i = 0; i < stack_ptr; i = i + 1) begin
                            current = stack[i];
                            for (j = 0; j < 16; j = j + 1) begin
                                if (current_edges[current*16 + j] && !visited[j]) begin
                                    visited[j] = 1'b1;
                                    visited_count = visited_count + 4'd1;
                                    stack[stack_ptr] = j;
                                    stack_ptr = stack_ptr + 4'd1;
                                    edge_count = edge_count + 4'd1;
                                end
                            end
                        end
                        
                        // Check if it's a spanning tree
                        if (visited_count == node_count && edge_count == node_count - 4'd1) begin
                            found = 1'b1;
                            result <= 1'b1;
                            next_state <= FINISH;
                        end else begin
                            next_state <= GENERATE_COMB;
                        end
                    end else begin
                        next_state <= GENERATE_COMB;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
            
            // Update cycle count
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

endmodule