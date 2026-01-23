module TabooStrings(
    input clk,
    input rst_n,
    input config_mode,
    input config_done,
    input [3:0] num_strings,
    input [2:0] str_len [0:7],
    input [7:0] str_data [0:7],
    input start,
    output reg result_valid,
    output reg result_infinite,
    output reg [15:0] result_string,
    output reg [4:0] result_length
);
    // Main states
    localparam [3:0] ST_RESET     = 4'd0;
    localparam [3:0] ST_CONFIG    = 4'd1;
    localparam [3:0] ST_BUILD_TRIE= 4'd2;
    localparam [3:0] ST_BFS       = 4'd3;
    localparam [3:0] ST_WAIT      = 4'd4;
    localparam [3:0] ST_CYCLE_CHK = 4'd5;
    localparam [3:0] ST_LONGEST   = 4'd6;
    localparam [3:0] ST_OUTPUT    = 4'd7;
    
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Trie structures (32 nodes max)
    reg [4:0] node_children [0:31][0:1];  // children for 0 and 1
    reg [4:0] node_failure [0:31];
    reg node_terminal [0:31];
    
    // BFS queue
    reg [4:0] queue [0:31];
    reg [5:0] queue_head, queue_tail;
    
    // DFS cycle detection
    reg [4:0] dfs_stack [0:31];
    reg [4:0] dfs_ptr;
    reg visited [0:31];
    reg in_stack [0:31];
    reg found_cycle;
    
    // Longest path DP
    reg [15:0] best_string [0:31];
    reg [4:0] max_length [0:31];
    reg [4:0] current_node;
    reg [15:0] temp_string;
    
    // Counters/indices
    reg [3:0] str_idx;
    reg [2:0] char_idx;
    reg [4:0] node_count;
    reg [4:0] current_node_idx;
    reg [4:0] bfs_node;
    reg [4:0] cycle_start_node;
    reg [7:0] cycle_counter;
    
    // Misc control
    reg config_done_synced;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_RESET;
            result_valid <= 1'b0;
            result_infinite <= 1'b0;
            result_string <= 16'd0;
            result_length <= 5'd0;
            config_done_synced <= 1'b0;
            
            // Initialize Trie nodes
            for (i = 0; i < 32; i = i + 1) begin
                node_children[i][0] <= 5'd0;
                node_children[i][1] <= 5'd0;
                node_failure[i] <= 5'd0;
                node_terminal[i] <= 1'b0;
                visited[i] <= 1'b0;
                in_stack[i] <= 1'b0;
                best_string[i] <= 16'd0;
                max_length[i] <= 5'd0;
            end
            
            // Initialize BFS queue
            for (i = 0; i < 32; i = i + 1)
                queue[i] <= 5'd0;
            queue_head <= 6'd0;
            queue_tail <= 6'd0;
            
            // Initialize DFS stack
            for (i = 0; i < 32; i = i + 1)
                dfs_stack[i] <= 5'd0;
            dfs_ptr <= 5'd0;
            
            str_idx <= 4'd0;
            char_idx <= 3'd0;
            node_count <= 5'd1; // root at 0 exists
            current_node <= 5'd0;
            bfs_node <= 5'd0;
            cycle_start_node <= 5'd0;
            cycle_counter <= 8'd0;
            temp_string <= 16'd0;
            found_cycle <= 1'b0;
            
        end else begin
            config_done_synced <= config_done;
            
            case (state)
                ST_RESET: begin
                    state <= ST_CONFIG;
                end
                
                ST_CONFIG: begin
                    result_valid <= 1'b0;
                    result_infinite <= 1'b0;
                    
                    if (config_done_synced) begin
                        state <= ST_BUILD_TRIE;
                        str_idx <= 4'd0;
                        current_node <= 5'd0;
                    end
                end
                
                ST_BUILD_TRIE: begin
                    if (str_idx < num_strings) begin
                        if (char_idx < str_len[str_idx]) begin
                            // Get current character
                            reg bit_val;
                            bit_val = str_data[str_idx][char_idx];
                            
                            // Check if child exists
                            if (node_children[current_node][bit_val] == 5'd0) begin
                                // Create new node
                                node_children[current_node][bit_val] <= node_count;
                                current_node <= node_count;
                                node_count <= node_count + 5'd1;
                            end else begin
                                current_node <= node_children[current_node][bit_val];
                            end
                            char_idx <= char_idx + 3'd1;
                        end else begin
                            // Mark terminal node
                            node_terminal[current_node] <= 1'b1;
                            str_idx <= str_idx + 4'd1;
                            char_idx <= 3'd0;
                            current_node <= 5'd0;
                        end
                    end else begin
                        state <= ST_BFS;
                        queue[0] <= 5'd0;
                        queue_tail <= 6'd1;
                        node_failure[0] <= 5'd0;
                        current_node_idx <= 5'd0;
                    end
                end
                
                ST_BFS: begin
                    if (queue_head < queue_tail) begin
                        bfs_node <= queue[queue_head];
                        queue_head <= queue_head + 6'd1;
                        
                        for (i = 0; i <= 1; i = i + 1) begin
                            reg [4:0] child, fails;
                            child = node_children[bfs_node][i];
                            if (child != 5'd0) begin
                                // Add to queue
                                queue[queue_tail] <= child;
                                queue_tail <= queue_tail + 6'd1;
                                
                                // Compute failure link
                                fails = node_failure[bfs_node];
                                while (fails != 0 && node_children[fails][i] == 5'd0)
                                    fails = node_failure[fails];
                                
                                if (bfs_node != 0)
                                    node_failure[child] <= node_children[fails][i];
                                else
                                    node_failure[child] <= (node_children[0][i] != 0) ? node_children[0][i] : 5'd0;
                                
                                // Update terminal flag
                                if (node_terminal[node_failure[child]])
                                    node_terminal[child] <= 1'b1;
                            end
                        end
                    end else begin
                        state <= ST_WAIT;
                    end
                end
                
                ST_WAIT: begin
                    if (start) begin
                        state <= ST_CYCLE_CHK;
                        current_node <= 5'd0;
                        dfs_ptr <= 5'd0;
                        found_cycle <= 1'b0;
                        cycle_counter <= 8'd0;
                        
                        // Clear visited and stack
                        for (i = 0; i < 32; i = i + 1) begin
                            visited[i] <= 1'b0;
                            in_stack[i] <= 1'b0;
                        end
                    end
                end
                
                ST_CYCLE_CHK: begin
                    if (cycle_counter >= 8'd200) begin
                        state <= ST_LONGEST;
                    end else if (!found_cycle) begin
                        // Simplified DFS cycle check logic
                        // Implement simplified iterative DFS here
                        // If cycle found, set found_cycle=1
                    end else begin
                        state <= ST_OUTPUT;
                        result_infinite <= 1'b1;
                    end
                    cycle_counter <= cycle_counter + 8'd1;
                end
                
                ST_LONGEST: begin
                    // Simplified DP longest path computation
                    // Placeholder logic
                    state <= ST_OUTPUT;
                    result_valid <= 1'b1;
                    result_string <= 16'd0;
                    result_length <= 3'd0;
                end
                
                ST_OUTPUT: begin
                    // Reset output signals after one cycle
                    result_valid <= 1'b0;
                    result_infinite <= 1'b0;
                    state <= ST_WAIT;
                end
                
                default: state <= ST_RESET;
            endcase
        end
    end
endmodule
