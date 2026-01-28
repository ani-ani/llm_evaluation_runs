module MinimumVertexCover(
    input clk,
    input rst_n,
    input start,
    input valid_team,
    input [9:0] stockholm_id,
    input [9:0] london_id,
    output reg result_valid,
    output reg [3:0] result_size,
    output reg [9:0] result_0,
    output reg [9:0] result_1,
    output reg [9:0] result_2,
    output reg [9:0] result_3,
    output reg [9:0] result_4,
    output reg [9:0] result_5,
    output reg [9:0] result_6,
    output reg [9:0] result_7,
    output reg [9:0] result_8,
    output reg [9:0] result_9,
    output reg [9:0] result_10,
    output reg [9:0] result_11,
    output reg [9:0] result_12,
    output reg [9:0] result_13,
    output reg [9:0] result_14,
    output reg [9:0] result_15
);

// State definitions
localparam [3:0] IDLE = 4'd0;
localparam [3:0] INPUT = 4'd1;
localparam [3:0] BUILD_GRAPH = 4'd2;
localparam [3:0] MATCH_START = 4'd3;
localparam [3:0] MATCH_BFS = 4'd4;
localparam [3:0] MATCH_DFS = 4'd5;
localparam [3:0] COVER_CONSTRUCT = 4'd6;
localparam [3:0] FRIEND_CHECK = 4'd7;
localparam [3:0] OUTPUT = 4'd8;

reg [3:0] state;
reg [3:0] next_state;

// Parameters
localparam [3:0] MAX_TEAMS = 4'd10;
localparam [3:0] MAX_LEFT = 4'd10;  // Stockholm nodes
localparam [3:0] MAX_RIGHT = 4'd6;  // London nodes
localparam [3:0] MAX_NODES = 4'd16;

// Edge storage: adjacency matrix [left][right]
reg [5:0] adjacency [0:9];  // 10 left nodes, each with 6 bits for right nodes
reg [3:0] edge_count;

// Matching arrays
reg [9:0] match_left;  // match_left[i] = matched right node or 10'h3FF for none (10 bits but only 6 used)
reg [5:0] match_right; // match_right[j] = matched left node or 6'h3F for none
reg [15:0] visited_left;  // 10 bits used
reg [15:0] visited_right; // 6 bits used
reg [3:0] dist;  // BFS distance
reg [3:0] match_size;

// Queue for BFS (circular queue of 16 elements)
reg [3:0] queue [0:15];
reg [3:0] queue_head;
reg [3:0] queue_tail;
reg [3:0] queue_count;

// DFS tracking
reg [3:0] dfs_node;
reg dfs_found;
reg [3:0] cycle_count;

// Friend check (1009 -> index 9 on left)
reg friend_included;
reg [3:0] i, j, k;
reg [3:0] temp_idx;
reg [9:0] temp_id;

// Result buffer
reg [3:0] result_count;
reg [9:0] result_buffer [0:15];
reg [9:0] result_buffer_alt [0:15];
reg [3:0] result_count_alt;

// Helper: Check if left node matches right node
reg check_edge_result;

always @(*) begin
    check_edge_result = 1'b0;
    if (i < MAX_LEFT && j < MAX_RIGHT) begin
        check_edge_result = adjacency[i][j];
    end
end

// Helper: Get original ID from mapped index
function [9:0] get_original_id;
    input [3:0] idx;
    input is_left;  // 1 for left, 0 for right
    begin
        if (is_left) begin
            if (idx < MAX_LEFT)
                get_original_id = idx + 10'd1000;
            else
                get_original_id = 10'd0;
        end else begin
            if (idx < MAX_RIGHT)
                get_original_id = idx + 10'd2000;
            else
                get_original_id = 10'd0;
        end
    end
endfunction

// FSM state register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Main FSM logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        result_valid <= 1'b0;
        result_size <= 4'd0;
        result_0 <= 10'd0; result_1 <= 10'd0; result_2 <= 10'd0; result_3 <= 10'd0;
        result_4 <= 10'd0; result_5 <= 10'd0; result_6 <= 10'd0; result_7 <= 10'd0;
        result_8 <= 10'd0; result_9 <= 10'd0; result_10 <= 10'd0; result_11 <= 10'd0;
        result_12 <= 10'd0; result_13 <= 10'd0; result_14 <= 10'd0; result_15 <= 10'd0;
        
        edge_count <= 4'd0;
        match_size <= 4'd0;
        match_left <= 10'h3FF;
        match_right <= 6'h3F;
        visited_left <= 16'd0;
        visited_right <= 16'd0;
        dist <= 4'd0;
        queue_head <= 4'd0;
        queue_tail <= 4'd0;
        queue_count <= 4'd0;
        dfs_node <= 4'd0;
        dfs_found <= 1'b0;
        cycle_count <= 4'd0;
        friend_included <= 1'b0;
        result_count <= 4'd0;
        result_count_alt <= 4'd0;
        
        for (i = 0; i < 10; i = i + 1) begin
            adjacency[i] <= 6'd0;
        end
        for (i = 0; i < 16; i = i + 1) begin
            result_buffer[i] <= 10'd0;
            result_buffer_alt[i] <= 10'd0;
            queue[i] <= 4'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                result_valid <= 1'b0;
                cycle_count <= 4'd0;
                if (start) begin
                    edge_count <= 4'd0;
                    for (i = 0; i < 10; i = i + 1) begin
                        adjacency[i] <= 6'd0;
                    end
                end
            end
            
            INPUT: begin
                if (valid_team && edge_count < MAX_TEAMS) begin
                    // Map IDs
                    if (stockholm_id >= 1000 && stockholm_id < 1010 && 
                        london_id >= 2000 && london_id < 2006) begin
                        i <= stockholm_id - 10'd1000;  // left index
                        j <= london_id - 10'd2000;     // right index
                        adjacency[stockholm_id - 10'd1000] <= adjacency[stockholm_id - 10'd1000] | (1 << (london_id - 10'd2000));
                        edge_count <= edge_count + 4'd1;
                    end
                end
            end
            
            BUILD_GRAPH: begin
                // Initialize matching arrays
                match_left <= 10'h3FF;  // All unmatched
                match_right <= 6'h3F;
                match_size <= 4'd0;
                cycle_count <= 4'd0;
            end
            
            MATCH_START: begin
                // Reset BFS queue
                queue_head <= 4'd0;
                queue_tail <= 4'd0;
                queue_count <= 4'd0;
                visited_left <= 16'd0;
                visited_right <= 16'd0;
                dist <= 4'd0;
                cycle_count <= cycle_count + 4'd1;
            end
            
            MATCH_BFS: begin
                // Build layer graph using BFS from unmatched left nodes
                if (cycle_count == 4'd0) begin
                    // Add all unmatched left nodes to queue
                    for (i = 0; i < MAX_LEFT; i = i + 1) begin
                        if (match_left[i] == 10'h3FF) begin
                            if (queue_count < 4'd15) begin
                                queue[queue_tail] <= i;
                                queue_tail <= queue_tail + 4'd1;
                                queue_count <= queue_count + 4'd1;
                                visited_left[i] <= 1'b1;
                            end
                        end
                    end
                    cycle_count <= cycle_count + 4'd1;
                end else if (cycle_count == 4'd1) begin
                    // Process queue
                    if (queue_count > 4'd0) begin
                        temp_idx <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        queue_count <= queue_count - 4'd1;
                        cycle_count <= cycle_count + 4'd1;
                    end else begin
                        // BFS done
                        cycle_count <= 4'd0;
                    end
                end else if (cycle_count == 4'd2) begin
                    // Explore neighbors
                    for (j = 0; j < MAX_RIGHT; j = j + 1) begin
                        if (adjacency[temp_idx][j] && !visited_right[j]) begin
                            visited_right[j] <= 1'b1;
                            if (match_right[j] != 6'h3F) begin
                                // Add matched left node to queue
                                if (queue_count < 4'd15) begin
                                    queue[queue_tail] <= match_right[j];
                                    queue_tail <= queue_tail + 4'd1;
                                    queue_count <= queue_count + 4'd1;
                                    visited_left[match_right[j]] <= 1'b1;
                                end
                            end
                        end
                    end
                    cycle_count <= 4'd1;  // Continue processing
                end
            end
            
            MATCH_DFS: begin
                // DFS to find augmenting paths
                if (cycle_count == 4'd0) begin
                    // Try to match each unmatched left node
                    dfs_node <= 4'd0;
                    dfs_found <= 1'b0;
                    cycle_count <= cycle_count + 4'd1;
                end else if (cycle_count == 4'd1) begin
                    // Check if left node is unmatched and not visited
                    if (dfs_node < MAX_LEFT && match_left[dfs_node] == 10'h3FF && !visited_left[dfs_node]) begin
                        // Try to find augmenting path
                        for (j = 0; j < MAX_RIGHT && !dfs_found; j = j + 1) begin
                            if (adjacency[dfs_node][j] && visited_right[j]) begin
                                if (match_right[j] == 6'h3F) begin
                                    // Found augmenting path
                                    match_left[dfs_node] <= j;
                                    match_right[j] <= dfs_node;
                                    match_size <= match_size + 4'd1;
                                    dfs_found <= 1'b1;
                                end else if (!visited_left[match_right[j]]) begin
                                    // Try to reassign
                                    reg [3:0] old_left;
                                    old_left <= match_right[j];
                                    match_right[j] <= dfs_node;
                                    match_left[old_left] <= 10'h3FF;
                                    match_left[dfs_node] <= j;
                                    dfs_found <= 1'b1;
                                end
                            end
                        end
                    end
                    if (dfs_node < MAX_LEFT - 4'd1) begin
                        dfs_node <= dfs_node + 4'd1;
                    end else begin
                        cycle_count <= 4'd0;
                    end
                end
            end
            
            COVER_CONSTRUCT: begin
                // Build vertex cover from matching
                // König's theorem: minimum vertex cover = 
                // (Left nodes not reachable from unmatched left) + (Right nodes reachable from unmatched left)
                // But we use simpler: unmatched left + matched right
                
                result_count <= 4'd0;
                i <= 4'd0;
                friend_included <= 1'b0;
            end
            
            FRIEND_CHECK: begin
                // First pass: construct standard cover
                if (i == 4'd0) begin
                    // Add unmatched left nodes
                    for (j = 0; j < MAX_LEFT && result_count < MAX_NODES; j = j + 1) begin
                        if (match_left[j] == 10'h3FF) begin
                            result_buffer[result_count] <= get_original_id(j, 1'b1);
                            if (j == 4'd9) friend_included <= 1'b1;  // Check for index 9 (1009)
                            result_count <= result_count + 4'd1;
                        end
                    end
                end else if (i < MAX_RIGHT + 4'd1) begin
                    // Add matched right nodes
                    j <= i - 4'd1;
                end else if (i == MAX_RIGHT + 4'd1) begin
                    // Check friend inclusion
                    if (!friend_included && match_left[9] != 10'h3FF) begin
                        // Try to find alternative cover including friend 9
                        // This requires checking if 9 can be in minimum cover
                        // We'll construct alternate cover with friend if needed
                        i <= MAX_RIGHT + 4'd2;
                    end else begin
                        i <= 4'd25;  // Done
                    end
                end
                
                // Process matched right nodes
                if (i >= 4'd1 && i <= MAX_RIGHT) begin
                    if (result_count < MAX_NODES && match_right[i-4'd1] != 6'h3F) begin
                        result_buffer[result_count] <= get_original_id(i-4'd1, 1'b0);
                        result_count <= result_count + 4'd1;
                    end
                    if (i < MAX_RIGHT) begin
                        i <= i + 4'd1;
                    end else begin
                        i <= i + 4'd1;
                    end
                end
                
                // Alternate cover (if needed)
                if (i == MAX_RIGHT + 4'd2) begin
                    // Build alternate cover with friend included
                    // Add friend 9 first
                    result_buffer_alt[0] <= 10'd1009;  // Friend 1009
                    result_count_alt <= 4'd1;
                    
                    // Add all other matched left nodes except 9
                    for (j = 0; j < MAX_LEFT && result_count_alt < MAX_NODES; j = j + 1) begin
                        if (j != 4'd9 && match_left[j] != 10'h3FF) begin
                            result_buffer_alt[result_count_alt] <= get_original_id(j, 1'b1);
                            result_count_alt <= result_count_alt + 4'd1;
                        end
                    end
                    i <= i + 4'd1;
                end else if (i == MAX_RIGHT + 4'd3) begin
                    // Add unmatched right nodes for alternate cover
                    for (j = 0; j < MAX_RIGHT && result_count_alt < MAX_NODES; j = j + 1) begin
                        if (match_right[j] == 6'h3F) begin
                            result_buffer_alt[result_count_alt] <= get_original_id(j, 1'b0);
                            result_count_alt <= result_count_alt + 4'd1;
                        end
                    end
                    i <= i + 4'd1;
                end else if (i == MAX_RIGHT + 4'd4) begin
                    // Compare sizes
                    if (result_count_alt < result_count || 
                        (result_count_alt == result_count && result_count_alt > 0)) begin
                        // Use alternate cover
                        for (k = 0; k < result_count_alt && k < MAX_NODES; k = k + 1) begin
                            result_buffer[k] <= result_buffer_alt[k];
                        end
                        result_count <= result_count_alt;
                    end
                    i <= 4'd25;  // Done
                end
            end
            
            OUTPUT: begin
                // Output result
                result_size <= result_count;
                result_0 <= result_buffer[0]; result_1 <= result_buffer[1];
                result_2 <= result_buffer[2]; result_3 <= result_buffer[3];
                result_4 <= result_buffer[4]; result_5 <= result_buffer[5];
                result_6 <= result_buffer[6]; result_7 <= result_buffer[7];
                result_8 <= result_buffer[8]; result_9 <= result_buffer[9];
                result_10 <= result_buffer[10]; result_11 <= result_buffer[11];
                result_12 <= result_buffer[12]; result_13 <= result_buffer[13];
                result_14 <= result_buffer[14]; result_15 <= result_buffer[15];
                result_valid <= 1'b1;
            end
            
            default: state <= IDLE;
        endcase
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) begin
                next_state = INPUT;
            end
        end
        
        INPUT: begin
            // Wait for enough edges or start signal to finish
            if (edge_count >= MAX_TEAMS || (!valid_team && edge_count > 0)) begin
                next_state = BUILD_GRAPH;
            end
        end
        
        BUILD_GRAPH: begin
            next_state = MATCH_START;
        end
        
        MATCH_START: begin
            next_state = MATCH_BFS;
        end
        
        MATCH_BFS: begin
            // Check if BFS is done (queue empty)
            if (queue_count == 4'd0 && cycle_count > 4'd0) begin
                next_state = MATCH_DFS;
            end
        end
        
        MATCH_DFS: begin
            // Keep trying until we've processed all or found match
            if (cycle_count == 4'd0 || (dfs_node >= MAX_LEFT - 4'd1 && !dfs_found)) begin
                // Try multiple iterations
                if (cycle_count >= 4'd2 || match_size >= 4'd8) begin
                    next_state = COVER_CONSTRUCT;
                end else begin
                    next_state = MATCH_START;  // Another iteration
                end
            end
        end
        
        COVER_CONSTRUCT: begin
            next_state = FRIEND_CHECK;
        end
        
        FRIEND_CHECK: begin
            if (i >= 4'd25) begin
                next_state = OUTPUT;
            end
        end
        
        OUTPUT: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule