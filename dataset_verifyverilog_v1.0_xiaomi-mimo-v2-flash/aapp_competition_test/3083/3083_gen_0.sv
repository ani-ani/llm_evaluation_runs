module GraphPathFinder (
    input clk,
    input rst_n,
    input start,
    input [3:0] node_count,
    input [3:0] labels [0:15],
    input [15:0] adj_matrix [0:15],
    output reg [3:0] path [0:8],
    output reg done,
    output reg found
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CHECK_PATH = 3'd2;
    localparam [2:0] EXPAND = 3'd3;
    localparam [2:0] BACKTRACK = 3'd4;
    localparam [2:0] FINISH_SUCCESS = 3'd5;
    localparam [2:0] FINISH_FAIL = 3'd6;

    // Register declarations
    reg [2:0] state, next_state;
    reg [13:0] cycle_count;
    reg [3:0] current_depth;
    reg [3:0] path_reg [0:8];  // Current path being built
    reg [15:0] visited_labels;  // Bitmask of artist IDs used
    reg [3:0] current_node;     // Current node at current_depth
    reg [3:0] next_candidate;   // Next node to try
    reg search_success;
    reg cycle_limit_exceeded;

    // Local constants
    localparam [13:0] MAX_CYCLES = 14'd10000;
    localparam [3:0] TARGET_DEPTH = 4'd9;
    localparam [4:0] NUM_NODES = 5'd16;

    integer i;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 14'd0;
            current_depth <= 4'd0;
            visited_labels <= 16'd0;
            found <= 1'b0;
            done <= 1'b0;
            search_success <= 1'b0;
            cycle_limit_exceeded <= 1'b0;
            next_candidate <= 4'd0;
            for (i = 0; i < 9; i = i + 1) begin
                path_reg[i] <= 4'd0;
                path[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 14'd0;
                    current_depth <= 4'd0;
                    visited_labels <= 16'd0;
                    found <= 1'b0;
                    search_success <= 1'b0;
                    cycle_limit_exceeded <= 1'b0;
                    next_candidate <= 4'd0;
                end
                
                INIT: begin
                    // Initialize first node (try node 0)
                    if (start) begin
                        cycle_count <= cycle_count + 14'd1;
                        current_depth <= 4'd0;
                        path_reg[0] <= 4'd0;
                        visited_labels <= (1 << labels[0]);
                        next_candidate <= 4'd0;
                    end
                end
                
                CHECK_PATH: begin
                    cycle_count <= cycle_count + 14'd1;
                end
                
                EXPAND: begin
                    cycle_count <= cycle_count + 14'd1;
                    // Move to next depth
                    current_depth <= current_depth + 4'd1;
                    path_reg[current_depth + 1] <= next_candidate;
                    visited_labels <= visited_labels | (1 << labels[next_candidate]);
                    next_candidate <= 4'd0;
                end
                
                BACKTRACK: begin
                    cycle_count <= cycle_count + 14'd1;
                    // Remove current node from path
                    if (current_depth > 0) begin
                        current_depth <= current_depth - 4'd1;
                        visited_labels <= visited_labels & ~(1 << labels[path_reg[current_depth]]);
                    end
                    next_candidate <= path_reg[current_depth] + 4'd1;
                end
                
                FINISH_SUCCESS: begin
                    done <= 1'b1;
                    found <= 1'b1;
                    for (i = 0; i < 9; i = i + 1) begin
                        path[i] <= path_reg[i];
                    end
                end
                
                FINISH_FAIL: begin
                    done <= 1'b1;
                    found <= 1'b0;
                    for (i = 0; i < 9; i = i + 1) begin
                        path[i] <= 4'd0;
                    end
                end
            endcase
            
            // Check cycle limit
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH_SUCCESS && state != FINISH_FAIL) begin
                cycle_limit_exceeded <= 1'b1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            
            INIT: begin
                if (labels[0] < node_count) begin
                    next_state = CHECK_PATH;
                end else begin
                    next_state = FINISH_FAIL;
                end
            end
            
            CHECK_PATH: begin
                if (cycle_limit_exceeded) begin
                    next_state = FINISH_FAIL;
                end else if (current_depth == TARGET_DEPTH - 4'd1) begin
                    // Path is complete (9 nodes: 0 to 8)
                    next_state = FINISH_SUCCESS;
                end else begin
                    next_state = EXPAND;
                end
            end
            
            EXPAND: begin
                // Find next valid candidate
                // We need to find next_candidate that:
                // 1. Is adjacent from current node
                // 2. Has label not visited
                // 3. Label index < node_count
                // This is handled in combinational logic below
                // For now, check if we found a candidate
                next_state = CHECK_PATH;
            end
            
            BACKTRACK: begin
                if (current_depth == 4'd0 && next_candidate >= node_count) begin
                    next_state = FINISH_FAIL;
                end else if (next_candidate >= node_count) begin
                    next_state = BACKTRACK;
                end else begin
                    next_state = CHECK_PATH;
                end
            end
            
            FINISH_SUCCESS, FINISH_FAIL: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Combinational candidate finding logic
    // This runs continuously and finds the next valid node
    always @(*) begin
        reg [3:0] start_node;
        reg [3:0] idx;
        reg found_cand;
        
        // Find next valid candidate starting from next_candidate
        found_cand = 1'b0;
        next_candidate = 4'd0;
        
        if (state == EXPAND || state == CHECK_PATH || state == BACKTRACK) begin
            if (current_depth < TARGET_DEPTH) begin
                start_node = (state == EXPAND) ? path_reg[current_depth] : 
                           (state == BACKTRACK) ? path_reg[current_depth] : path_reg[current_depth];
                
                for (idx = next_candidate; idx < node_count; idx = idx + 1) begin
                    if (!found_cand) begin
                        // Check if edge exists
                        if (adj_matrix[start_node][idx]) begin
                            // Check if label is unique
                            if (!(visited_labels & (1 << labels[idx]))) begin
                                found_cand = 1'b1;
                                next_candidate = idx;
                            end
                        end
                    end
                end
            end
        end
        
        // Handle backtrack case where no candidate found
        if (state == EXPAND && !found_cand) begin
            next_candidate = node_count;
        end
    end

endmodule