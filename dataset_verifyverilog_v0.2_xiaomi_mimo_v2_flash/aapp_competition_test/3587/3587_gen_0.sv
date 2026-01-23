module taboo_solver(
    input clk,
    input rst_n,
    input start,
    input [2:0] n_valid,
    input [7:0] str_len [0:7],
    input [7:0] taboo_str [0:63],
    output reg [2:0] result_len,
    output reg [255:0] result_str,
    output reg infinite,
    output reg done
);

    // Parameters
    localparam MAX_NODES = 64;
    localparam MAX_TABOO = 8;
    localparam MAX_LEN = 8;
    
    // States
    localparam IDLE = 4'd0;
    localparam BUILD_TRIE_INIT = 4'd1;
    localparam BUILD_TRIE_LOAD = 4'd2;
    localparam BUILD_TRIE_INSERT = 4'd3;
    localparam FIND_CYCLES = 4'd4;
    localparam FIND_LONGEST_INIT = 4'd5;
    localparam FIND_LONGEST_SEARCH = 4'd6;
    localparam DONE = 4'd7;
    localparam ERROR = 4'd8;

    // FSM registers
    reg [3:0] state, next_state;
    
    // Trie structure
    reg [5:0] node_count; // 0-63
    reg [1:0] trie_child [0:63]; // 0 or 1, 2'b11 means no child
    reg trie_terminal [0:63];
    reg [5:0] parent_node [0:63];
    reg [1:0] edge_char [0:63];
    
    // Build state registers
    reg [2:0] str_idx; // current string index (0-7)
    reg [7:0] char_idx; // current char index in string
    reg [5:0] current_node;
    reg [7:0] temp_char;
    reg [2:0] strings_processed;
    
    // DFS stack for cycle detection
    reg [5:0] stack_nodes [0:63];
    reg [5:0] stack_ptr;
    reg [63:0] visited_mask;
    reg [63:0] path_mask;
    reg [5:0] search_node;
    reg [1:0] search_child;
    reg cycle_found;
    
    // DFS for longest path
    reg [5:0] best_depth;
    reg [5:0] best_node;
    reg [255:0] best_str;
    reg [5:0] cur_depth;
    reg [255:0] cur_str;
    reg [5:0] longest_stack_nodes [0:63];
    reg [255:0] longest_stack_str [0:63];
    reg [5:0] longest_stack_ptr;
    reg [1:0] longest_child_idx;
    reg [5:0] next_node;
    
    // Helper registers
    integer i, j;
    reg [7:0] len_temp;
    reg [255:0] temp_str;
    reg [5:0] temp_node;
    
    // Sequential state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = BUILD_TRIE_INIT;
            end
            BUILD_TRIE_INIT: begin
                next_state = BUILD_TRIE_LOAD;
            end
            BUILD_TRIE_LOAD: begin
                if (strings_processed >= n_valid) begin
                    next_state = FIND_CYCLES;
                end else if (char_idx >= str_len[str_idx]) begin
                    next_state = BUILD_TRIE_INSERT;
                end else begin
                    next_state = BUILD_TRIE_LOAD;
                end
            end
            BUILD_TRIE_INSERT: begin
                if (char_idx >= str_len[str_idx]) begin
                    next_state = BUILD_TRIE_LOAD;
                end else begin
                    next_state = BUILD_TRIE_INSERT;
                end
            end
            FIND_CYCLES: begin
                if (cycle_found || (stack_ptr == 0 && search_node == 0 && search_child == 2)) begin
                    if (cycle_found) next_state = DONE;
                    else next_state = FIND_LONGEST_INIT;
                end else begin
                    next_state = FIND_CYCLES;
                end
            end
            FIND_LONGEST_INIT: begin
                next_state = FIND_LONGEST_SEARCH;
            end
            FIND_LONGEST_SEARCH: begin
                if (longest_stack_ptr == 0 && longest_child_idx == 2) begin
                    next_state = DONE;
                end else begin
                    next_state = FIND_LONGEST_SEARCH;
                end
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end
    
    // Output and datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            result_len <= 3'd0;
            result_str <= 256'd0;
            infinite <= 1'b0;
            done <= 1'b0;
            node_count <= 6'd0;
            str_idx <= 3'd0;
            char_idx <= 8'd0;
            current_node <= 6'd0;
            strings_processed <= 3'd0;
            stack_ptr <= 6'd0;
            visited_mask <= 64'd0;
            path_mask <= 64'd0;
            search_node <= 6'd0;
            search_child <= 2'd0;
            cycle_found <= 1'b0;
            best_depth <= 6'd0;
            cur_depth <= 6'd0;
            longest_stack_ptr <= 6'd0;
            longest_child_idx <= 2'd0;
            
            // Reset arrays
            for (i = 0; i < 64; i = i + 1) begin
                trie_child[i] <= 2'b11;
                trie_terminal[i] <= 1'b0;
                parent_node[i] <= 6'd0;
                edge_char[i] <= 2'd0;
                stack_nodes[i] <= 6'd0;
                longest_stack_nodes[i] <= 6'd0;
                longest_stack_str[i] <= 256'd0;
            end
            best_str <= 256'd0;
            cur_str <= 256'd0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        node_count <= 6'd0;
                        str_idx <= 3'd0;
                        char_idx <= 8'd0;
                        current_node <= 6'd0;
                        strings_processed <= 3'd0;
                    end
                end
                
                BUILD_TRIE_INIT: begin
                    // Initialize root node
                    node_count <= 6'd1;
                    trie_child[0] <= 2'b11;
                    trie_terminal[0] <= 1'b0;
                    current_node <= 6'd0;
                end
                
                BUILD_TRIE_LOAD: begin
                    // Load current character and find/create next node
                    if (strings_processed < n_valid && char_idx < str_len[str_idx]) begin
                        temp_char <= taboo_str[str_idx * 8 + char_idx];
                        // Search for existing child
                        if (trie_child[current_node] != 2'b11 && trie_child[current_node] == taboo_str[str_idx * 8 + char_idx]) begin
                            // Child exists, follow it
                            current_node <= parent_node[current_node] + 1; // This is wrong, need to find child
                        end
                    end
                end
                
                BUILD_TRIE_INSERT: begin
                    // Insert character into trie
                    if (strings_processed < n_valid && char_idx < str_len[str_idx]) begin
                        // Get the character (0 or 1)
                        temp_char = taboo_str[str_idx * 8 + char_idx];
                        
                        // Check if child exists
                        if (trie_child[current_node] == 2'b11 || trie_child[current_node] != temp_char) begin
                            // Create new node
                            if (node_count < 64) begin
                                trie_child[current_node] <= temp_char;
                                parent_node[node_count] <= current_node;
                                edge_char[node_count] <= temp_char;
                                trie_child[node_count] <= 2'b11;
                                trie_terminal[node_count] <= 1'b0;
                                current_node <= node_count;
                                node_count <= node_count + 1;
                            end
                        end else begin
                            // Child exists, find it (simplified - assuming sequential search)
                            // In real implementation, we'd need a lookup table
                            // For now, we'll create a helper to find child
                            // This is complex in combinational logic
                            // We'll use a different approach
                        end
                        char_idx <= char_idx + 1;
                    end else if (strings_processed < n_valid) begin
                        // Mark terminal
                        trie_terminal[current_node] <= 1'b1;
                        strings_processed <= strings_processed + 1;
                        str_idx <= str_idx + 1;
                        char_idx <= 8'd0;
                        current_node <= 6'd0; // Back to root
                    end
                end
                
                FIND_CYCLES: begin
                    if (stack_ptr == 0 && search_node == 6'd0 && search_child == 2'd0) begin
                        // Initialize DFS
                        visited_mask <= 64'd0;
                        path_mask <= 64'd0;
                        stack_ptr <= 6'd1;
                        stack_nodes[0] <= 6'd0;
                        cycle_found <= 1'b0;
                        search_child <= 2'd0;
                        search_node <= 6'd0;
                    end else if (!cycle_found) begin
                        // Iterative DFS for cycle detection
                        if (stack_ptr > 0) begin
                            reg [5:0] curr = stack_nodes[stack_ptr - 1];
                            
                            if (search_child == 2'd0) begin
                                // First time visiting this node
                                if (path_mask[curr] && curr != 6'd0) begin
                                    // Cycle detected
                                    cycle_found <= 1'b1;
                                end else begin
                                    path_mask[curr] <= 1'b1;
                                    visited_mask[curr] <= 1'b1;
                                end
                            end
                            
                            // Find next unvisited child
                            if (search_child < 2'd2 && !cycle_found) begin
                                reg [5:0] child_node = 6'd0;
                                reg found = 1'b0;
                                // We need to find the actual child node number
                                // This is tricky without a reverse lookup
                                // For now, we'll use a different strategy:
                                // Assume trie_child stores which child exists
                                // But we need to know the node ID
                                // This requires a data structure that maps (parent, char) -> child
                                // We'll implement a simple linear search for children
                                
                                // Search through all nodes to find children of curr
                                for (i = 0; i < 64; i = i + 1) begin
                                    if (parent_node[i] == curr && edge_char[i] == search_child && !found) begin
                                        child_node = i;
                                        found = 1'b1;
                                    end
                                end
                                
                                if (found && !visited_mask[child_node]) begin
                                    // Push child onto stack
                                    stack_nodes[stack_ptr] <= child_node;
                                    stack_ptr <= stack_ptr + 1;
                                    search_child <= 2'd0;
                                    search_node <= child_node;
                                end else begin
                                    search_child <= search_child + 1;
                                end
                            end else if (!cycle_found) begin
                                // Backtrack
                                path_mask[stack_nodes[stack_ptr - 1]] <= 1'b0;
                                stack_ptr <= stack_ptr - 1;
                                if (stack_ptr > 1) begin
                                    search_node <= stack_nodes[stack_ptr - 2];
                                    // Need to restore search_child to next after current
                                    // This is complex, we'll need to store it
                                    // Simplified: reset to 0 and recheck
                                    search_child <= 2'd0;
                                end else begin
                                    search_child <= 2'd0;
                                    search_node <= 6'd0;
                                end
                            end
                        end
                    end
                end
                
                FIND_LONGEST_INIT: begin
                    best_depth <= 6'd0;
                    best_str <= 256'd0;
                    best_node <= 6'd0;
                    longest_stack_ptr <= 6'd1;
                    longest_stack_nodes[0] <= 6'd0;
                    longest_stack_str[0] <= 256'd0;
                    longest_child_idx <= 2'd0;
                    cur_depth <= 6'd0;
                    cur_str <= 256'd0;
                end
                
                FIND_LONGEST_SEARCH: begin
                    if (longest_stack_ptr > 0) begin
                        reg [5:0] curr = longest_stack_nodes[longest_stack_ptr - 1];
                        reg [255:0] curr_str = longest_stack_str[longest_stack_ptr - 1];
                        reg [5:0] curr_depth = longest_stack_ptr - 1;
                        
                        // Update best result (non-terminal nodes only for path length)
                        // Actually, we want longest path to any node
                        if (curr_depth > best_depth || 
                           (curr_depth == best_depth && curr_str < best_str)) begin
                            best_depth <= curr_depth;
                            best_str <= curr_str;
                            best_node <= curr;
                        end
                        
                        // Find next child
                        if (longest_child_idx < 2'd2) begin
                            reg [5:0] child_node = 6'd0;
                            reg found = 1'b0;
                            
                            // Search for child
                            for (i = 0; i < 64; i = i + 1) begin
                                if (parent_node[i] == curr && edge_char[i] == longest_child_idx) begin
                                    child_node = i;
                                    found = 1'b1;
                                end
                            end
                            
                            if (found) begin
                                // Create new string
                                reg [255:0] new_str;
                                new_str = curr_str;
                                // Append character
                                new_str = (new_str << 1) | longest_child_idx;
                                
                                // Push to stack
                                longest_stack_nodes[longest_stack_ptr] <= child_node;
                                longest_stack_str[longest_stack_ptr] <= new_str;
                                longest_stack_ptr <= longest_stack_ptr + 1;
                                longest_child_idx <= 2'd0;
                            end else begin
                                longest_child_idx <= longest_child_idx + 1;
                            end
                        end else begin
                            // Backtrack
                            longest_stack_ptr <= longest_stack_ptr - 1;
                            if (longest_stack_ptr > 1) begin
                                longest_child_idx <= 2'd0;
                            end else begin
                                longest_child_idx <= 2'd0;
                            end
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (cycle_found) begin
                        infinite <= 1'b1;
                        result_len <= 3'd0;
                        result_str <= 256'd0;
                    end else begin
                        infinite <= 1'b0;
                        result_len <= best_depth[2:0];
                        result_str <= best_str;
                    end
                end
            endcase
        end
    end

endmodule

module taboo_solver_v2(
    input clk,
    input rst_n,
    input start,
    input [2:0] n_valid,
    input [7:0] str_len [0:7],
    input [7:0] taboo_str [0:63],
    output reg [2:0] result_len,
    output reg [255:0] result_str,
    output reg infinite,
    output reg done
);

    // Constants
    localparam MAX_NODES = 64;
    localparam MAX_TABOO = 8;
    
    // States
    localparam IDLE = 5'd0;
    localparam BUILD_INIT = 5'd1;
    localparam BUILD_GET_CHAR = 5'd2;
    localparam BUILD_FIND_CHILD = 5'd3;
    localparam BUILD_CREATE_NODE = 5'd4;
    localparam BUILD_NEXT_CHAR = 5'd5;
    localparam BUILD_END_STRING = 5'd6;
    localparam FIND_CYCLES_INIT = 5'd7;
    localparam FIND_CYCLES_SEARCH = 5'd8;
    localparam FIND_LONGEST_INIT = 5'd9;
    localparam FIND_LONGEST_SEARCH = 5'd10;
    localparam DONE_STATE = 5'd11;
    
    reg [4:0] state, next_state;
    
    // Trie storage - use explicit child pointers
    reg [5:0] child0 [0:63]; // child for '0'
    reg [5:0] child1 [0:63]; // child for '1'
    reg terminal [0:63];
    reg [5:0] node_count;
    
    // Build process registers
    reg [2:0] current_str_idx;
    reg [7:0] current_char_idx;
    reg [5:0] current_node;
    reg [7:0] char_value;
    reg [2:0] processed_count;
    
    // Cycle detection registers
    reg [5:0] cycle_stack [0:63];
    reg [5:0] cycle_sp;
    reg [63:0] cycle_visited;
    reg [63:0] cycle_path;
    reg cycle_found_flag;
    reg [5:0] cycle_search_child;
    reg [5:0] cycle_current;
    
    // Longest path registers
    reg [5:0] longest_stack [0:63];
    reg [255:0] longest_str_stack [0:63];
    reg [5:0] longest_sp;
    reg [5:0] best_len;
    reg [255:0] best_str;
    reg [5:0] longest_search_child;
    
    // Temporary variables
    integer i;
    reg [255:0] temp_str;
    reg [5:0] found_child;
    reg child_exists;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = BUILD_INIT;
            
            BUILD_INIT: next_state = BUILD_GET_CHAR;
            
            BUILD_GET_CHAR: begin
                if (processed_count >= n_valid) next_state = FIND_CYCLES_INIT;
                else if (current_char_idx >= str_len[current_str_idx]) next_state = BUILD_END_STRING;
                else next_state = BUILD_FIND_CHILD;
            end
            
            BUILD_FIND_CHILD: begin
                if (child_exists) next_state = BUILD_NEXT_CHAR;
                else next_state = BUILD_CREATE_NODE;
            end
            
            BUILD_CREATE_NODE: next_state = BUILD_NEXT_CHAR;
            
            BUILD_NEXT_CHAR: next_state = BUILD_GET_CHAR;
            
            BUILD_END_STRING: next_state = BUILD_GET_CHAR;
            
            FIND_CYCLES_INIT: next_state = FIND_CYCLES_SEARCH;
            
            FIND_CYCLES_SEARCH: begin
                if (cycle_found_flag) next_state = DONE_STATE;
                else if (cycle_sp == 0 && cycle_search_child > 1) next_state = FIND_LONGEST_INIT;
                else next_state = FIND_CYCLES_SEARCH;
            end
            
            FIND_LONGEST_INIT: next_state = FIND_LONGEST_SEARCH;
            
            FIND_LONGEST_SEARCH: begin
                if (longest_sp == 0 && longest_search_child > 1) next_state = DONE_STATE;
                else next_state = FIND_LONGEST_SEARCH;
            end
            
            DONE_STATE: if (!start) next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end
    
    // Main datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
            node_count <= 6'd1; // Root is 0
            for (i = 0; i < 64; i = i + 1) begin
                child0[i] <= 6'd0;
                child1[i] <= 6'd0;
                terminal[i] <= 1'b0;
            end
            current_str_idx <= 3'd0;
            current_char_idx <= 8'd0;
            current_node <= 6'd0;
            processed_count <= 3'd0;
            
            cycle_sp <= 6'd0;
            cycle_visited <= 64'd0;
            cycle_path <= 64'd0;
            cycle_found_flag <= 1'b0;
            cycle_search_child <= 6'd0;
            cycle_current <= 6'd0;
            
            longest_sp <= 6'd0;
            best_len <= 6'd0;
            best_str <= 256'd0;
            longest_search_child <= 6'd0;
            
            result_len <= 3'd0;
            result_str <= 256'd0;
            infinite <= 1'b0;
            done <= 1'b0;
            
        end else begin
            case (state)
                BUILD_INIT: begin
                    node_count <= 6'd1;
                    current_str_idx <= 3'd0;
                    current_char_idx <= 8'd0;
                    current_node <= 6'd0;
                    processed_count <= 3'd0;
                end
                
                BUILD_GET_CHAR: begin
                    if (processed_count < n_valid && current_char_idx < str_len[current_str_idx]) begin
                        char_value <= taboo_str[current_str_idx * 8 + current_char_idx];
                    end
                end
                
                BUILD_FIND_CHILD: begin
                    if (processed_count < n_valid && current_char_idx < str_len[current_str_idx]) begin
                        if (char_value == 8'd0) begin
                            child_exists <= (child0[current_node] != 6'd0) || (current_node == 6'd0 && child0[current_node] == 6'd0);
                            found_child <= child0[current_node];
                        end else begin
                            child_exists <= (child1[current_node] != 6'd0) || (current_node == 6'd0 && child1[current_node] == 6'd0);
                            found_child <= child1[current_node];
                        end
                    end
                end
                
                BUILD_CREATE_NODE: begin
                    if (processed_count < n_valid && current_char_idx < str_len[current_str_idx]) begin
                        if (node_count < 64) begin
                            if (char_value == 8'd0) begin
                                child0[current_node] <= node_count;
                            end else begin
                                child1[current_node] <= node_count;
                            end
                            // Clear new node's children
                            child0[node_count] <= 6'd0;
                            child1[node_count] <= 6'd0;
                            terminal[node_count] <= 1'b0;
                            current_node <= node_count;
                            node_count <= node_count + 1;
                        end
                    end
                end
                
                BUILD_NEXT_CHAR: begin
                    if (processed_count < n_valid && current_char_idx < str_len[current_str_idx]) begin
                        if (child_exists) begin
                            current_node <= found_child;
                        end
                        current_char_idx <= current_char_idx + 1;
                    end
                end
                
                BUILD_END_STRING: begin
                    if (processed_count < n_valid) begin
                        terminal[current_node] <= 1'b1;
                        processed_count <= processed_count + 1;
                        current_str_idx <= current_str_idx + 1;
                        current_char_idx <= 8'd0;
                        current_node <= 6'd0;
                    end
                end
                
                FIND_CYCLES_INIT: begin
                    cycle_sp <= 6'd1;
                    cycle_stack[0] <= 6'd0;
                    cycle_visited <= 64'd0;
                    cycle_path <= 64'd0;
                    cycle_found_flag <= 1'b0;
                    cycle_search_child <= 6'd0;
                    cycle_current <= 6'd0;
                end
                
                FIND_CYCLES_SEARCH: begin
                    if (cycle_sp > 0 && !cycle_found_flag) begin
                        reg [5:0] curr = cycle_stack[cycle_sp - 1];
                        
                        // Check for cycle (back edge)
                        if (cycle_path[curr] && curr != 6'd0) begin
                            cycle_found_flag <= 1'b1;
                        end else if (!cycle_visited[curr]) begin
                            cycle_visited[curr] <= 1'b1;
                            cycle_path[curr] <= 1'b1;
                        end
                        
                        // Search for next unvisited child
                        if (cycle_search_child < 6'd2 && !cycle_found_flag) begin
                            reg [5:0] next_node = 6'd0;
                            if (cycle_search_child == 0) next_node = child0[curr];
                            else if (cycle_search_child == 1) next_node = child1[curr];
                            
                            if (next_node != 6'd0 && !cycle_visited[next_node]) begin
                                cycle_stack[cycle_sp] <= next_node;
                                cycle_sp <= cycle_sp + 1;
                                cycle_search_child <= 6'd0;
                            end else begin
                                cycle_search_child <= cycle_search_child + 1;
                            end
                        end else if (!cycle_found_flag) begin
                            // Backtrack
                            cycle_path[cycle_stack[cycle_sp - 1]] <= 1'b0;
                            cycle_sp <= cycle_sp - 1;
                            if (cycle_sp > 1) begin
                                cycle_search_child <= 6'd0;
                            end else begin
                                cycle_search_child <= 6'd2; // Signal end
                            end
                        end
                    end else if (cycle_sp == 0) begin
                        cycle_search_child <= 6'd2;
                    end
                end
                
                FIND_LONGEST_INIT: begin
                    longest_sp <= 6'd1;
                    longest_stack[0] <= 6'd0;
                    longest_str_stack[0] <= 256'd0;
                    best_len <= 6'd0;
                    best_str <= 256'd0;
                    longest_search_child <= 6'd0;
                end
                
                FIND_LONGEST_SEARCH: begin
                    if (longest_sp > 0) begin
                        reg [5:0] curr = longest_stack[longest_sp - 1];
                        reg [255:0] curr_str = longest_str_stack[longest_sp - 1];
                        reg [5:0] depth = longest_sp - 1;
                        
                        // Update best (track non-zero length paths)
                        if (depth > best_len || (depth == best_len && depth > 0 && curr_str < best_str)) begin
                            best_len <= depth;
                            best_str <= curr_str;
                        end
                        
                        // Search children
                        if (longest_search_child < 6'd2) begin
                            reg [5:0] next_node = 6'd0;
                            if (longest_search_child == 0) next_node = child0[curr];
                            else if (longest_search_child == 1) next_node = child1[curr];
                            
                            if (next_node != 6'd0) begin
                                // Create new string
                                reg [255:0] new_str;
                                new_str = (curr_str << 1) | longest_search_child;
                                
                                longest_stack[longest_sp] <= next_node;
                                longest_str_stack[longest_sp] <= new_str;
                                longest_sp <= longest_sp + 1;
                                longest_search_child <= 6'd0;
                            end else begin
                                longest_search_child <= longest_search_child + 1;
                            end
                        end else begin
                            // Backtrack
                            longest_sp <= longest_sp - 1;
                            if (longest_sp > 1) longest_search_child <= 6'd0;
                            else longest_search_child <= 6'd2; // Signal end
                        end
                    end else begin
                        longest_search_child <= 6'd2;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (cycle_found_flag) begin
                        infinite <= 1'b1;
                        result_len <= 3'd0;
                        result_str <= 256'd0;
                    end else begin
                        infinite <= 1'b0;
                        result_len <= best_len[2:0];
                        result_str <= best_str;
                    end
                end
            endcase
        end
    end

endmodule

module TopModule(
    input clk,
    input rst_n,
    input start,
    input [2:0] n_valid,
    input [7:0] str_len [0:7],
    input [7:0] taboo_str [0:63],
    output reg [2:0] result_len,
    output reg [255:0] result_str,
    output reg infinite,
    output reg done
);

    // Instantiate the v2 implementation
    taboo_solver_v2 u_solver (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .n_valid(n_valid),
        .str_len(str_len),
        .taboo_str(taboo_str),
        .result_len(result_len),
        .result_str(result_str),
        .infinite(infinite),
        .done(done)
    );

endmodule

module taboo_solver(
    input clk,
    input rst_n,
    input start,
    input [2:0] n_valid,
    input [7:0] str_len [0:7],
    input [7:0] taboo_str [0:63],
    output reg [2:0] result_len,
    output reg [255:0] result_str,
    output reg infinite,
    output reg done
);

    taboo_solver_v2 u_core (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .n_valid(n_valid),
        .str_len(str_len),
        .taboo_str(taboo_str),
        .result_len(result_len),
        .result_str(result_str),
        .infinite(infinite),
        .done(done)
    );

endmodule