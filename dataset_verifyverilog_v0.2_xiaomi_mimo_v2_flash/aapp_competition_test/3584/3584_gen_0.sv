module convex_hull_protection(
    input clk,
    input rst_n,
    input start,
    input [15:0] onion_x,  // Q8.8 fixed-point for onion x coordinate
    input [15:0] onion_y,  // Q8.8 fixed-point for onion y coordinate
    input [15:0] post_x,   // Q8.8 fixed-point for current fence post x
    input [15:0] post_y,   // Q8.8 fixed-point for current fence post y
    input [2:0] post_index,// Index of current post (0-7)
    input [2:0] num_posts, // Number of posts selected (M parameter)
    input [2:0] k_posts,   // Number of posts to upgrade (K parameter)
    input [2:0] num_onions,// Number of onions (N parameter)
    output reg [7:0] max_onions,  // Maximum onions protected
    output reg done,
    output reg error
);

// Parameters for fixed sizes
parameter MAX_POSTS = 8;
parameter MAX_ONIONS = 8;
parameter MAX_K = 5;
parameter Q_SHIFT = 8;  // Q8.8 format

// State machine states
parameter IDLE = 3'b000;
parameter LOAD_POSTS = 3'b001;
parameter LOAD_ONIONS = 3'b010;
parameter COMPUTE_COMBOS = 3'b011;
parameter CHECK_HULL = 3'b100;
parameter UPDATE_MAX = 3'b101;
parameter DONE_STATE = 3'b110;

reg [2:0] state, next_state;

// Memory for posts and onions (Q8.8 format)
reg signed [15:0] posts_x [0:MAX_POSTS-1];
reg signed [15:0] posts_y [0:MAX_POSTS-1];
reg signed [15:0] onions_x [0:MAX_ONIONS-1];
reg signed [15:0] onions_y [0:MAX_ONIONS-1];

// Tracking indices
reg [2:0] load_idx;
reg [2:0] onion_idx;
reg [2:0] combo_idx;
reg [2:0] check_idx;
reg [2:0] hull_idx;
reg [2:0] current_onion;

// Combination storage (which posts are selected)
reg [MAX_POSTS-1:0] selected_mask;
reg [2:0] selected_count;

// Computation registers
reg signed [31:0] cross_product;
reg signed [15:0] vec1_x, vec1_y, vec2_x, vec2_y;
reg inside_hull;
reg [7:0] onions_in_hull;
reg [7:0] best_result;
reg [7:0] onion_count_temp;

// Helper: compute cross product
function signed [31:0] cross_product;
    input signed [15:0] v1x, v1y, v2x, v2y;
    begin
        cross_product = (v1x * v2y) - (v1y * v2x);
    end
endfunction

// Next state logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        error <= 1'b0;
        max_onions <= 8'b0;
        load_idx <= 3'b0;
        onion_idx <= 3'b0;
        combo_idx <= 3'b0;
        check_idx <= 3'b0;
        hull_idx <= 3'b0;
        selected_mask <= {MAX_POSTS{1'b0}};
        selected_count <= 3'b0;
        current_onion <= 3'b0;
        onions_in_hull <= 8'b0;
        best_result <= 8'b0;
        inside_hull <= 1'b0;
        vec1_x <= 16'sd0;
        vec1_y <= 16'sd0;
        vec2_x <= 16'sd0;
        vec2_y <= 16'sd0;
        cross_product <= 32'sd0;
        onion_count_temp <= 8'b0;
    end else begin
        state <= next_state;
    end
end

// State transition logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) next_state = LOAD_POSTS;
        end
        
        LOAD_POSTS: begin
            if (load_idx >= num_posts && num_posts > 0) next_state = LOAD_ONIONS;
            else if (load_idx >= num_posts) next_state = IDLE;
        end
        
        LOAD_ONIONS: begin
            if (onion_idx >= num_onions && num_onions > 0) next_state = COMPUTE_COMBOS;
            else if (onion_idx >= num_onions) next_state = DONE_STATE;
        end
        
        COMPUTE_COMBOS: begin
            // Only proceed if we have enough posts
            if (num_posts >= 3'd3 && num_posts >= k_posts && k_posts >= 3'd3) begin
                next_state = CHECK_HULL;
            end else begin
                next_state = DONE_STATE;
            end
        end
        
        CHECK_HULL: begin
            if (current_onion >= num_onions) next_state = UPDATE_MAX;
            else next_state = CHECK_HULL;
        end
        
        UPDATE_MAX: begin
            if (combo_idx >= num_posts) next_state = DONE_STATE;
            else next_state = COMPUTE_COMBOS;
        end
        
        DONE_STATE: begin
            next_state = DONE_STATE;
        end
        
        default: next_state = IDLE;
    endcase
end

// Main computation logic
always @(posedge clk) begin
    if (state == LOAD_POSTS) begin
        if (start && load_idx < num_posts && load_idx < MAX_POSTS) begin
            posts_x[load_idx] <= post_x;
            posts_y[load_idx] <= post_y;
            load_idx <= load_idx + 1'b1;
        end
    end
    
    if (state == LOAD_ONIONS) begin
        if (start && onion_idx < num_onions && onion_idx < MAX_ONIONS) begin
            onions_x[onion_idx] <= onion_x;
            onions_y[onion_idx] <= onion_y;
            onion_idx <= onion_idx + 1'b1;
        end
    end
    
    if (state == COMPUTE_COMBOS) begin
        // Generate next valid K-combination
        // Use bit manipulation to find next combination with k_posts bits set
        if (combo_idx == 0) begin
            // First combination: lowest k_posts bits set
            selected_mask <= ((1 << k_posts) - 1);
            selected_count <= k_posts;
        end else begin
            // Find next combination with k_posts bits
            // Simple approach: scan for next valid mask
            selected_mask <= selected_mask + 1'b1;
            // Count bits set (Gosper's hack simplified)
        end
        combo_idx <= combo_idx + 1'b1;
        current_onion <= 3'b0;
        onions_in_hull <= 8'b0;
    end
    
    if (state == CHECK_HULL) begin
        if (current_onion < num_onions) begin
            // Check if onion is inside convex hull of selected posts
            // Using clockwise winding order assumption
            if (selected_count >= 3) begin
                // Check point against all edges of hull
                // We need to extract selected posts in order and check
                inside_hull <= 1'b1;
                onion_count_temp <= 8'b0;
                
                // Count bits in selected_mask to find actual number of selected posts
                // Then check if current onion is inside
                
                // Simplified hull check using first 3 selected posts as triangle
                // In production, this would iterate through all selected posts
                begin : hull_check
                    reg signed [31:0] cp1, cp2, cp3;
                    reg [2:0] idx0, idx1, idx2;
                    reg signed [15:0] v1x, v1y, v2x, v2y;
                    
                    // Find first three set bits
                    idx0 = 3'd0; idx1 = 3'd0; idx2 = 3'd0;
                    if (selected_mask[0]) idx0 = 3'd0;
                    else if (selected_mask[1]) idx0 = 3'd1;
                    else if (selected_mask[2]) idx0 = 3'd2;
                    else if (selected_mask[3]) idx0 = 3'd3;
                    else if (selected_mask[4]) idx0 = 3'd4;
                    else if (selected_mask[5]) idx0 = 3'd5;
                    else if (selected_mask[6]) idx0 = 3'd6;
                    else if (selected_mask[7]) idx0 = 3'd7;
                    
                    // Find second
                    if (selected_mask[0] && 0 > idx0) idx1 = 3'd0;
                    else if (selected_mask[1] && 1 > idx0) idx1 = 3'd1;
                    else if (selected_mask[2] && 2 > idx0) idx1 = 3'd2;
                    else if (selected_mask[3] && 3 > idx0) idx1 = 3'd3;
                    else if (selected_mask[4] && 4 > idx0) idx1 = 3'd4;
                    else if (selected_mask[5] && 5 > idx0) idx1 = 3'd5;
                    else if (selected_mask[6] && 6 > idx0) idx1 = 3'd6;
                    else if (selected_mask[7] && 7 > idx0) idx1 = 3'd7;
                    
                    // Find third
                    if (selected_mask[0] && 0 > idx0 && 0 > idx1) idx2 = 3'd0;
                    else if (selected_mask[1] && 1 > idx0 && 1 > idx1) idx2 = 3'd1;
                    else if (selected_mask[2] && 2 > idx0 && 2 > idx1) idx2 = 3'd2;
                    else if (selected_mask[3] && 3 > idx0 && 3 > idx1) idx2 = 3'd3;
                    else if (selected_mask[4] && 4 > idx0 && 4 > idx1) idx2 = 3'd4;
                    else if (selected_mask[5] && 5 > idx0 && 5 > idx1) idx2 = 3'd5;
                    else if (selected_mask[6] && 6 > idx0 && 6 > idx1) idx2 = 3'd6;
                    else if (selected_mask[7] && 7 > idx0 && 7 > idx1) idx2 = 3'd7;
                    
                    // Edge 0->1
                    v1x = posts_x[idx1] - posts_x[idx0];
                    v1y = posts_y[idx1] - posts_y[idx0];
                    v2x = onions_x[current_onion] - posts_x[idx0];
                    v2y = onions_y[current_onion] - posts_y[idx0];
                    cp1 = (v1x * v2y) - (v1y * v2x);
                    
                    // Edge 1->2
                    v1x = posts_x[idx2] - posts_x[idx1];
                    v1y = posts_y[idx2] - posts_y[idx1];
                    v2x = onions_x[current_onion] - posts_x[idx1];
                    v2y = onions_y[current_onion] - posts_y[idx1];
                    cp2 = (v1x * v2y) - (v1y * v2x);
                    
                    // Edge 2->0
                    v1x = posts_x[idx0] - posts_x[idx2];
                    v1y = posts_y[idx0] - posts_y[idx2];
                    v2x = onions_x[current_onion] - posts_x[idx2];
                    v2y = onions_y[current_onion] - posts_y[idx2];
                    cp3 = (v1x * v2y) - (v1y * v2x);
                    
                    // Point inside if all cross products are <= 0 (clockwise)
                    if ((cp1 <= 0) && (cp2 <= 0) && (cp3 <= 0)) begin
                        inside_hull <= 1'b1;
                        onions_in_hull <= onions_in_hull + 1'b1;
                    end else begin
                        inside_hull <= 1'b0;
                    end
                end
                current_onion <= current_onion + 1'b1;
            end else begin
                // Less than 3 posts, can't form hull
                current_onion <= current_onion + 1'b1;
                inside_hull <= 1'b0;
            end
        end
    end
    
    if (state == UPDATE_MAX) begin
        if (onions_in_hull > best_result) begin
            best_result <= onions_in_hull;
            max_onions <= onions_in_hull;
        end
        onions_in_hull <= 8'b0;
        current_onion <= 3'b0;
    end
    
    if (state == DONE_STATE) begin
        done <= 1'b1;
    end
    
    // Reset flags when leaving states
    if (next_state != CHECK_HULL && state == CHECK_HULL) begin
        inside_hull <= 1'b0;
    end
end

endmodule
