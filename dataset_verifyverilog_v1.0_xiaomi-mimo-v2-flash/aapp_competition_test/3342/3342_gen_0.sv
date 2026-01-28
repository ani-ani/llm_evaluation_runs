module OnionThief(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire config_valid,
    input wire signed [15:0] onion_x,
    input wire signed [15:0] onion_y,
    input wire signed [15:0] post_x,
    input wire signed [15:0] post_y,
    output reg signed [15:0] result,
    output reg done
);

    // Configuration constants
    localparam [3:0] MAX_POSTS = 4'd16;
    localparam [3:0] MAX_ONIONS = 4'd16;
    localparam [7:0] MAX_CYCLES = 8'd128; // Safety limit
    
    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] LOAD          = 3'd1;
    localparam [2:0] ITERATE       = 3'd2;
    localparam [2:0] CHECK_POINT   = 3'd3;
    localparam [2:0] UPDATE_MAX    = 3'd4;
    localparam [2:0] FINISH        = 3'd5;
    
    // Registers for configuration
    reg [3:0] M; // Number of posts
    reg [3:0] N; // Number of onions
    reg [3:0] K; // Posts to select
    reg [3:0] input_idx;
    reg [1:0] config_state; // 0=init M, 1=load posts, 2=init N, 3=load onions, 4=init K
    
    // Storage arrays (16 entries x 32 bits: X[15:0] | Y[15:0])
    reg signed [15:0] onions_x [0:15];
    reg signed [15:0] onions_y [0:15];
    reg signed [15:0] posts_x [0:15];
    reg signed [15:0] posts_y [0:15];
    
    // Subset generation registers
    reg [15:0] subset_mask; // Bitmask of selected posts
    reg [3:0] subset_count; // Number of bits set in mask
    reg [15:0] max_subset_mask; // Stores the best subset found
    
    // Point checking registers
    reg [3:0] onion_idx;
    reg [3:0] subset_post_idx;
    reg inside_current;
    reg signed [15:0] current_onion_x;
    reg signed [15:0] current_onion_y;
    reg signed [15:0] current_post_x;
    reg signed [15:0] current_post_y;
    reg signed [15:0] next_post_x;
    reg signed [15:0] next_post_y;
    
    // Cross product calculation registers
    // (X2-X1)*(Y3-Y1) - (Y2-Y1)*(X3-X1)
    // Expand to 32 bits to prevent overflow
    reg signed [31:0] cross_result;
    reg signed [31:0] dx1, dy1, dx2, dy2;
    reg cross_positive;
    
    // FSM registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [3:0] onions_protected; // Counter for current subset
    reg [3:0] max_onions_protected;
    
    // Helper to count bits in subset_mask (combinational logic)
    function [3:0] count_set_bits;
        input [15:0] mask;
        begin
            count_set_bits = 
                (mask[0] + mask[1]) + (mask[2] + mask[3]) +
                (mask[4] + mask[5]) + (mask[6] + mask[7]) +
                (mask[8] + mask[9]) + (mask[10] + mask[11]) +
                (mask[12] + mask[13]) + (mask[14] + mask[15]);
        end
    endfunction
    
    // Helper to get next polygon vertex index
    reg [3:0] next_v_idx;
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            cycle_count <= 8'd0;
            
            M <= 4'd0;
            N <= 4'd0;
            K <= 4'd0;
            input_idx <= 4'd0;
            config_state <= 2'd0;
            
            subset_mask <= 16'h0001;
            max_subset_mask <= 16'h0000;
            
            onion_idx <= 4'd0;
            subset_post_idx <= 4'd0;
            inside_current <= 1'b1;
            onions_protected <= 4'd0;
            max_onions_protected <= 4'd0;
            
            // Initialize arrays to 0
            onions_x[0] <= 16'd0; onions_y[0] <= 16'd0;
            onions_x[1] <= 16'd0; onions_y[1] <= 16'd0;
            onions_x[2] <= 16'd0; onions_y[2] <= 16'd0;
            onions_x[3] <= 16'd0; onions_y[3] <= 16'd0;
            onions_x[4] <= 16'd0; onions_y[4] <= 16'd0;
            onions_x[5] <= 16'd0; onions_y[5] <= 16'd0;
            onions_x[6] <= 16'd0; onions_y[6] <= 16'd0;
            onions_x[7] <= 16'd0; onions_y[7] <= 16'd0;
            onions_x[8] <= 16'd0; onions_y[8] <= 16'd0;
            onions_x[9] <= 16'd0; onions_y[9] <= 16'd0;
            onions_x[10] <= 16'd0; onions_y[10] <= 16'd0;
            onions_x[11] <= 16'd0; onions_y[11] <= 16'd0;
            onions_x[12] <= 16'd0; onions_y[12] <= 16'd0;
            onions_x[13] <= 16'd0; onions_y[13] <= 16'd0;
            onions_x[14] <= 16'd0; onions_y[14] <= 16'd0;
            onions_x[15] <= 16'd0; onions_y[15] <= 16'd0;
            posts_x[0] <= 16'd0; posts_y[0] <= 16'd0;
            posts_x[1] <= 16'd0; posts_y[1] <= 16'd0;
            posts_x[2] <= 16'd0; posts_y[2] <= 16'd0;
            posts_x[3] <= 16'd0; posts_y[3] <= 16'd0;
            posts_x[4] <= 16'd0; posts_y[4] <= 16'd0;
            posts_x[5] <= 16'd0; posts_y[5] <= 16'd0;
            posts_x[6] <= 16'd0; posts_y[6] <= 16'd0;
            posts_x[7] <= 16'd0; posts_y[7] <= 16'd0;
            posts_x[8] <= 16'd0; posts_y[8] <= 16'd0;
            posts_x[9] <= 16'd0; posts_y[9] <= 16'd0;
            posts_x[10] <= 16'd0; posts_y[10] <= 16'd0;
            posts_x[11] <= 16'd0; posts_y[11] <= 16'd0;
            posts_x[12] <= 16'd0; posts_y[12] <= 16'd0;
            posts_x[13] <= 16'd0; posts_y[13] <= 16'd0;
            posts_x[14] <= 16'd0; posts_y[14] <= 16'd0;
            posts_x[15] <= 16'd0; posts_y[15] <= 16'd0;
            
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        state <= LOAD;
                        config_state <= 2'd0;
                        input_idx <= 4'd0;
                    end
                end
                
                LOAD: begin
                    // Handle config_valid for input loading
                    if (config_valid) begin
                        case (config_state)
                            2'd0: begin // Load M
                                M <= onion_x[3:0]; // Re-use inputs
                                config_state <= 2'd1;
                            end
                            2'd1: begin // Load Posts
                                if (input_idx < M) begin
                                    posts_x[input_idx] <= post_x;
                                    posts_y[input_idx] <= post_y;
                                    input_idx <= input_idx + 4'd1;
                                end
                                if (input_idx == M - 4'd1) begin
                                    config_state <= 2'd2;
                                    input_idx <= 4'd0;
                                end
                            end
                            2'd2: begin // Load N
                                N <= onion_x[3:0];
                                config_state <= 2'd3;
                            end
                            2'd3: begin // Load Onions
                                if (input_idx < N) begin
                                    onions_x[input_idx] <= post_x;
                                    onions_y[input_idx] <= post_y;
                                    input_idx <= input_idx + 4'd1;
                                end
                                if (input_idx == N - 4'd1) begin
                                    config_state <= 2'd4;
                                    input_idx <= 4'd0;
                                end
                            end
                            2'd4: begin // Load K
                                K <= onion_x[3:0];
                                if (start) begin // Start processing after K loaded
                                    state <= ITERATE;
                                    subset_mask <= 16'h0001;
                                    max_onions_protected <= 4'd0;
                                    max_subset_mask <= 16'h0000;
                                end else begin
                                    state <= IDLE;
                                end
                            end
                        endcase
                    end
                end
                
                ITERATE: begin
                    // Generate next subset mask
                    if (count_set_bits(subset_mask) == K) begin
                        // Valid subset found, check it
                        subset_count <= K;
                        onions_protected <= 4'd0;
                        onion_idx <= 4'd0;
                        subset_post_idx <= 4'd0;
                        inside_current <= 1'b1;
                        state <= CHECK_POINT;
                    end else begin
                        // Generate next subset
                        if (subset_mask != 16'hFFFF) begin
                            // Simple increment to find next valid mask
                            // This is a slow combinatorial search, but bounded by K
                            subset_mask <= subset_mask + 16'd1;
                        end else begin
                            // Finished all subsets
                            state <= UPDATE_MAX;
                        end
                    end
                end
                
                CHECK_POINT: begin
                    // Check if current onion is inside current subset polygon
                    if (inside_current && (subset_post_idx < subset_count)) begin
                        // Get current post
                        current_post_x <= posts_x[subset_post_idx];
                        current_post_y <= posts_y[subset_post_idx];
                        
                        // Get next post (wrap around)
                        if (subset_post_idx == subset_count - 4'd1) begin
                            next_post_x <= posts_x[0];
                            next_post_y <= posts_y[0];
                        end else begin
                            // Find next active post in mask
                            // We need to find the post at subset_post_idx + 1 in the set bits
                            // This is tricky in Verilog without dynamic loops. 
                            // Since K <= 16, we can use a helper or check sequentially.
                            // Optimization: We iterate the mask to find the N-th set bit.
                            next_post_x <= posts_x[0]; // Placeholder, logic below
                            next_post_y <= posts_y[0];
                        end
                        
                        // Logic to find next active post index from mask
                        // We will compute next_v_idx in a separate combinational block
                        
                        state <= UPDATE_MAX; // Move logic to separate state or combinational
                    end else if (!inside_current) begin
                        // Onion is outside, skip to next onion
                        onion_idx <= onion_idx + 4'd1;
                        subset_post_idx <= 4'd0;
                        inside_current <= 1'b1;
                        if (onion_idx == N - 4'd1) begin
                            state <= ITERATE;
                            // Go to next subset
                            if (subset_mask != 16'hFFFF) begin
                                subset_mask <= subset_mask + 16'd1;
                            end else begin
                                state <= UPDATE_MAX;
                            end
                        end
                    end else begin
                        // Finished checking all posts for this onion
                        if (inside_current) begin
                            onions_protected <= onions_protected + 4'd1;
                        end
                        onion_idx <= onion_idx + 4'd1;
                        subset_post_idx <= 4'd0;
                        inside_current <= 1'b1;
                        
                        if (onion_idx == N - 4'd1) begin
                            state <= ITERATE;
                            // Go to next subset
                            if (subset_mask != 16'hFFFF) begin
                                subset_mask <= subset_mask + 16'd1;
                            end else begin
                                state <= UPDATE_MAX;
                            end
                        end
                    end
                end
                
                UPDATE_MAX: begin
                    // Update max if current subset count > max
                    // This state handles the cross product logic mostly
                    if (subset_post_idx < subset_count) begin
                        // Perform cross product check
                        // Check if onion is on left side of edge (P1->P2)
                        // Assuming CCW order (subset order)
                        // (P2.x - P1.x) * (O.y - P1.y) - (P2.y - P1.y) * (O.x - P1.x)
                        
                        dx1 <= next_post_x - current_post_x;
                        dy1 <= next_post_y - current_post_y;
                        dx2 <= current_onion_x - current_post_x;
                        dy2 <= current_onion_y - current_post_y;
                        
                        cross_result <= (next_post_x - current_post_x) * (current_onion_y - current_post_y) - 
                                       (next_post_y - current_post_y) * (current_onion_x - current_post_x);
                        
                        if (cross_result > 32'd0) begin
                            subset_post_idx <= subset_post_idx + 4'd1;
                            // Need to update current_post and next_post for next iteration
                            // This requires finding indices in the mask. 
                            // Simplified approach: iterate index i from 0 to M-1, checking if bit i is set.
                        end else begin
                            inside_current <= 1'b0;
                            state <= CHECK_POINT;
                        end
                    end
                    
                    // Check if we need to update max onions_protected
                    if (onions_protected > max_onions_protected) begin
                        max_onions_protected <= onions_protected;
                        max_subset_mask <= subset_mask;
                    end
                    
                    state <= ITERATE;
                end
                
                FINISH: begin
                    result <= {12'd0, max_onions_protected};
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Check cycle limit
            if (cycle_count >= MAX_CYCLES) begin
                state <= FINISH;
            end
        end
    end
    
    // Combinational logic for finding next active post in subset
    integer i;
    always @(*) begin
        next_v_idx = 4'd0;
        if (subset_post_idx < subset_count) begin
            // Find the (subset_post_idx + 1)-th set bit
            // We need to scan the mask
            reg [3:0] current_bit;
            current_bit = 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                if (subset_mask[i]) begin
                    if (current_bit == subset_post_idx) begin
                        next_v_idx = i[3:0];
                    end
                    current_bit = current_bit + 4'd1;
                end
            end
            // If we are looking for the edge from idx to next, 
            // and subset_post_idx points to current vertex,
            // we need the vertex at subset_post_idx + 1.
            // The logic above finds index for current_bit == subset_post_idx.
            // We need index for current_bit == subset_post_idx + 1.
        end
    end
    
    // Update current_onion and next_post assignment in CHECK_POINT state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_onion_x <= 16'd0;
            current_onion_y <= 16'd0;
        end else begin
            if (state == CHECK_POINT && subset_post_idx == 4'd0 && onion_idx < N) begin
                current_onion_x <= onions_x[onion_idx];
                current_onion_y <= onions_y[onion_idx];
            end
        end
    end
    
    // Logic to get next vertex index from mask
    reg [3:0] v_idx;
    reg [3:0] next_idx;
    always @(*) begin
        next_idx = 4'd0;
        // Find next set bit after v_idx
        for (i = 0; i < 16; i = i + 1) begin
            if (subset_mask[i] && i[3:0] > v_idx) begin
                next_idx = i[3:0];
                break; // No break allowed, use flag
            end
        end
    end

endmodule
