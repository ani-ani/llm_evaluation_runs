module bfs_validator (
    input clk,
    input rst_n,
    input start,
    input [2:0] node_idx,         // Current node index for adjacency input
    input [2:0] neighbor_idx,     // Neighbor node index for adjacency input
    input adj_write,              // Write enable for adjacency matrix
    input [2:0] seq_in,           // Next element of sequence to validate
    input seq_write,              // Write enable for sequence input
    output reg valid,             // High if sequence is valid BFS traversal
    output reg done               // High when validation is complete
);

    // Storage
    reg [7:0] adj_matrix [0:7];   // 8x8 adjacency matrix
    reg [2:0] sequence [0:7];     // 8-element sequence array
    reg [7:0] visited;            // Visited nodes bitmask
    reg [2:0] parent [0:7];       // Parent of each node
    reg [2:0] adj_write_cnt;      // Counter for adjacency writes
    reg [2:0] seq_write_cnt;      // Counter for sequence writes
    
    // State Machine
    reg [3:0] state;
    localparam IDLE          = 4'd0;
    localparam LOAD_ADJ      = 4'd1;
    localparam LOAD_SEQ      = 4'd2;
    localparam VERIFY_INIT   = 4'd3;
    localparam VERIFY_PROCESS = 4'd4;
    localparam VERIFY_CHECK_CHILD = 4'd5;
    localparam VERIFY_NEXT_CHILD = 4'd6;
    localparam VALID_DONE    = 4'd7;
    localparam INVALID_DONE  = 4'd8;
    
    // Verification registers
    reg [2:0] verify_idx;         // Current index in sequence being verified
    reg [2:0] current_node;       // Current node being processed
    reg [2:0] seq_pos;            // Position in sequence for children verification
    reg [2:0] child_idx;          // Index for iterating through potential children
    reg [2:0] neighbor_count;     // Count of unvisited neighbors
    reg [2:0] expected_children [0:7]; // Expected children for current node
    reg [2:0] child_count;        // Number of children found
    reg [2:0] child_verify_idx;   // Index for verifying children
    
    integer i, j;
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            done <= 0;
            adj_write_cnt <= 0;
            seq_write_cnt <= 0;
            visited <= 0;
            verify_idx <= 0;
            child_count <= 0;
            // Initialize adjacency matrix
            for (i = 0; i < 8; i = i + 1) begin
                adj_matrix[i] <= 8'b0;
                parent[i] <= 3'b0;
                sequence[i] <= 3'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    valid <= 0;
                    done <= 0;
                    if (start && (adj_write_cnt == 3'd7 || adj_write_cnt == 3'd0)) begin
                        state <= LOAD_ADJ;
                    end
                end
                
                LOAD_ADJ: begin
                    if (adj_write) begin
                        adj_matrix[node_idx][neighbor_idx] <= 1'b1;
                        adj_write_cnt <= adj_write_cnt + 1;
                        if (adj_write_cnt == 3'd7) begin
                            state <= LOAD_SEQ;
                            seq_write_cnt <= 0;
                        end
                    end
                end
                
                LOAD_SEQ: begin
                    if (seq_write) begin
                        sequence[seq_write_cnt] <= seq_in;
                        seq_write_cnt <= seq_write_cnt + 1;
                        if (seq_write_cnt == 3'd7) begin
                            state <= VERIFY_INIT;
                        end
                    end
                end
                
                VERIFY_INIT: begin
                    // Check if root is 0
                    if (sequence[0] != 3'd0) begin
                        state <= INVALID_DONE;
                        valid <= 0;
                        done <= 1;
                    end else begin
                        visited <= 8'b00000001; // Mark root as visited
                        verify_idx <= 1;        // Start from index 1
                        for (i = 0; i < 8; i = i + 1) begin
                            parent[i] <= 3'b0;
                        end
                        state <= VERIFY_PROCESS;
                    end
                end
                
                VERIFY_PROCESS: begin
                    if (verify_idx >= 8) begin
                        // All nodes processed successfully
                        state <= VALID_DONE;
                        valid <= 1;
                        done <= 1;
                    end else begin
                        current_node <= sequence[verify_idx];
                        child_count <= 0;
                        child_idx <= 0;
                        state <= VERIFY_CHECK_CHILD;
                    end
                end
                
                VERIFY_CHECK_CHILD: begin
                    if (child_idx >= 8) begin
                        // Finished counting children
                        if (child_count > 0) begin
                            // Need to verify children are next in sequence
                            seq_pos <= verify_idx + 1;
                            child_verify_idx <= 0;
                            state <= VERIFY_NEXT_CHILD;
                        end else begin
                            // No children, move to next node
                            verify_idx <= verify_idx + 1;
                            visited[current_node] <= 1'b1;
                            state <= VERIFY_PROCESS;
                        end
                    end else begin
                        // Check if child_idx is unvisited neighbor of current_node
                        if (adj_matrix[current_node][child_idx] && !visited[child_idx] && (child_idx != current_node)) begin
                            // Check if this child is already in expected_children (avoid duplicates)
                            if (child_count == 0 || (expected_children[0] != child_idx && expected_children[1] != child_idx && expected_children[2] != child_idx && expected_children[3] != child_idx && expected_children[4] != child_idx && expected_children[5] != child_idx && expected_children[6] != child_idx && expected_children[7] != child_idx)) begin
                                expected_children[child_count] <= child_idx;
                                child_count <= child_count + 1;
                            end
                        end
                        child_idx <= child_idx + 1;
                    end
                end
                
                VERIFY_NEXT_CHILD: begin
                    if (child_verify_idx >= child_count) begin
                        // All children verified
                        // Mark all children as visited
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < child_count) begin
                                visited[expected_children[i]] <= 1'b1;
                            end
                        end
                        verify_idx <= verify_idx + 1;
                        state <= VERIFY_PROCESS;
                    end else begin
                        // Verify sequence[seq_pos] matches expected_children[child_verify_idx]
                        if (seq_pos >= 8 || sequence[seq_pos] != expected_children[child_verify_idx]) begin
                            state <= INVALID_DONE;
                            valid <= 0;
                            done <= 1;
                        end else begin
                            seq_pos <= seq_pos + 1;
                            child_verify_idx <= child_verify_idx + 1;
                        end
                    end
                end
                
                VALID_DONE: begin
                    // Stay in this state
                end
                
                INVALID_DONE: begin
                    // Stay in this state
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
endmodule