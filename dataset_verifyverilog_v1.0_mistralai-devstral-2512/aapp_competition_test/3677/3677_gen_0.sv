module max_clique_approx(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] adj_matrix [15:0],
    input wire [3:0] n_nodes,
    input wire [3:0] max_k,
    output reg [3:0] result,
    output reg done,
    output wire valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_CANDIDATE = 3'd1;
    localparam [2:0] ADD_NODE = 3'd2;
    localparam [2:0] BACKTRACK = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    // State machine registers
    reg [2:0] state, next_state;
    reg [3:0] current_size;
    reg [3:0] best_size;
    reg [15:0] current_clique;
    reg [15:0] candidate_set;
    reg [3:0] current_node;
    reg [3:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Internal signals
    reg node_valid;
    reg can_add;
    reg all_checked;
    reg [3:0] next_node;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_size <= 4'd0;
            best_size <= 4'd0;
            current_clique <= 16'd0;
            candidate_set <= 16'd0;
            current_node <= 4'd0;
            cycle_count <= 10'd0;
            result <= 4'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize for new search
                        current_size <= 4'd0;
                        best_size <= 4'd0;
                        current_clique <= 16'd0;
                        candidate_set <= {16{n_nodes[3:0]}};
                        current_node <= 4'd0;
                        cycle_count <= 10'd0;
                        next_state <= CHECK_CANDIDATE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_CANDIDATE: begin
                    // Check if current node is valid
                    node_valid = (current_node < n_nodes) && (candidate_set[current_node]);
                    
                    if (node_valid) begin
                        // Check if node can be added to current clique
                        can_add = 1'b1;
                        for (integer i = 0; i < 16; i = i + 1) begin
                            if (current_clique[i] && !adj_matrix[current_node][i]) begin
                                can_add = 1'b0;
                            end
                        end
                        
                        if (can_add) begin
                            next_state <= ADD_NODE;
                        end else begin
                            next_state <= BACKTRACK;
                        end
                    end else begin
                        // No more candidates at this level
                        next_state <= BACKTRACK;
                    end
                end

                ADD_NODE: begin
                    // Add node to current clique
                    current_clique[current_node] <= 1'b1;
                    current_size <= current_size + 4'd1;
                    
                    // Update best size if needed
                    if (current_size > best_size) begin
                        best_size <= current_size;
                    end
                    
                    // Update candidate set (remove non-neighbors)
                    for (integer i = 0; i < 16; i = i + 1) begin
                        if (!adj_matrix[current_node][i]) begin
                            candidate_set[i] <= 1'b0;
                        end
                    end
                    
                    // Move to next node
                    current_node <= current_node + 4'd1;
                    next_state <= CHECK_CANDIDATE;
                end

                BACKTRACK: begin
                    // Check if we've reached the end
                    all_checked = (current_node >= n_nodes) || (current_size == 4'd0);
                    
                    if (all_checked) begin
                        // Backtrack to previous level
                        if (current_size > 4'd0) begin
                            // Find last added node
                            for (integer i = 15; i >= 0; i = i - 1) begin
                                if (current_clique[i]) begin
                                    next_node = i;
                                    break;
                                end
                            end
                            
                            // Remove node from clique
                            current_clique[next_node] <= 1'b0;
                            current_size <= current_size - 4'd1;
                            
                            // Restore candidate set
                            for (integer i = 0; i < 16; i = i + 1) begin
                                if (adj_matrix[next_node][i]) begin
                                    candidate_set[i] <= 1'b1;
                                end
                            end
                            
                            // Move to next node after the removed one
                            current_node <= next_node + 4'd1;
                            next_state <= CHECK_CANDIDATE;
                        end else begin
                            // Search complete
                            next_state <= COMPLETE;
                        end
                    end else begin
                        // Continue checking next node
                        current_node <= current_node + 4'd1;
                        next_state <= CHECK_CANDIDATE;
                    end
                end

                COMPLETE: begin
                    result <= best_size;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
            
            // Cycle counter for safety
            if (state != IDLE && state != COMPLETE) begin
                cycle_count <= cycle_count + 10'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state <= COMPLETE;
                end
            end
        end
    end

    // Valid signal (combinatorial)
    assign valid = (state == COMPLETE) || (state == IDLE && done);

endmodule