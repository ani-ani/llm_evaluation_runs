module tree_marking (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,           // Number of nodes (1-15)
    input [3:0] D,           // Minimum distance (1-15)
    input [14:0] edges,      // Packed edge info: edge[i] = parent of node i+1, stored as 15*4-bit values
    output reg [3:0] result, // Maximum number of marked nodes
    output reg done          // Computation complete
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam ENUMERATE = 3'b010;
    localparam VALIDATE = 3'b011;
    localparam UPDATE_MAX = 3'b100;
    localparam DONE = 3'b101;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [14:0] current_mask;
    reg [3:0] max_count;
    reg [3:0] current_count;
    reg [3:0] node_a;
    reg [3:0] node_b;
    reg valid_flag;
    
    // Storage for tree structure
    reg [3:0] parent [14:0]; // parent of node i
    reg [3:0] depth [14:0];  // depth of node i
    reg [3:0] init_idx;
    reg [3:0] temp_depth;
    reg [3:0] curr_node;
    reg [3:0] walker;
    
    // Helper for distance computation
    reg [3:0] dist_a;
    reg [3:0] dist_b;
    reg [3:0] lca_depth;
    reg [3:0] calc_depth_a;
    reg [3:0] calc_depth_b;
    reg [3:0] wa;
    reg [3:0] wb;
    reg [3:0] d_val;
    
    // Control signals
    reg inc_init_idx;
    reg init_depth;
    reg inc_node_a;
    reg inc_node_b;
    reg reset_pair;
    reg check_next_pair;
    reg inc_mask;
    reg update_res;
    reg clr_done;
    reg set_done;
    
    // Combinational logic
    wire [3:0] parent_a = parent[node_a];
    wire [3:0] parent_b = parent[node_b];
    wire is_marked_a = (node_a < N) ? current_mask[node_a] : 1'b0;
    wire is_marked_b = (node_b < N) ? current_mask[node_b] : 1'b0;
    
    // State Transition and Output Logic
    always @(*) begin
        inc_init_idx = 1'b0;
        init_depth = 1'b0;
        inc_node_a = 1'b0;
        inc_node_b = 1'b0;
        reset_pair = 1'b0;
        check_next_pair = 1'b0;
        inc_mask = 1'b0;
        update_res = 1'b0;
        clr_done = 1'b0;
        set_done = 1'b0;
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                    clr_done = 1'b1;
                end
            end
            
            INIT: begin
                if (init_idx < N) begin
                    inc_init_idx = 1'b1;
                    init_depth = 1'b1;
                end else begin
                    next_state = ENUMERATE;
                end
            end
            
            ENUMERATE: begin
                // Check if we have enumerated all subsets
                // 2^N subsets. Mask goes from 0 to (1<<N)-1
                if (current_mask == ((1 << N) - 1)) begin
                    next_state = DONE;
                    set_done = 1'b1;
                end else begin
                    // Start validation for this subset
                    // Skip empty subsets if needed, but let's process all
                    next_state = VALIDATE;
                    reset_pair = 1'b1;
                end
            end
            
            VALIDATE: begin
                check_next_pair = 1'b1;
                
                // Early exit if invalid
                if (!valid_flag) begin
                    next_state = ENUMERATE;
                    inc_mask = 1'b1;
                end
                else if (node_a >= N) begin
                    // Valid subset found (all pairs checked)
                    next_state = UPDATE_MAX;
                end else if (node_b >= N) begin
                    // Finished checking pairs for current A.
                    // Move to next A.
                    inc_node_a = 1'b1;
                end else begin
                    // Checking (node_a, node_b)
                    // Increment B for next cycle
                    inc_node_b = 1'b1;
                    next_state = VALIDATE;
                end
            end
            
            UPDATE_MAX: begin
                update_res = 1'b1;
                next_state = ENUMERATE;
                inc_mask = 1'b1;
            end
            
            DONE: begin
                if (!start) next_state = IDLE;
                else next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential Logic for State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'b0;
            current_mask <= 15'b0;
            max_count <= 4'b0;
            init_idx <= 4'b0;
            node_a <= 4'b0;
            node_b <= 4'b0;
            valid_flag <= 1'b1;
            current_count <= 4'b0;
        end else begin
            state <= next_state;
            
            if (set_done) done <= 1'b1;
            if (clr_done) done <= 1'b0;
            
            // INIT State Logic
            if (state == INIT) begin
                if (init_depth) begin
                    if (init_idx == 0) begin
                        depth[0] <= 4'b0;
                        parent[0] <= 4'b0; // Root
                    end else begin
                        parent[init_idx] <= edges[((init_idx-1)*4) +: 4];
                        depth[init_idx] <= depth[parent[init_idx]] + 1'b1;
                    end
                end
            end
            
            // Validation Logic
            if (state == VALIDATE) begin
                if (valid_flag && check_next_pair) begin
                    if (node_a < N && node_b < N) begin
                        if (is_marked_a && is_marked_b) begin
                            if (dist_calc < D) begin
                                valid_flag <= 1'b0;
                            end
                        end
                    end
                end
                
                if (inc_node_a) begin
                    node_a <= node_a + 1'b1;
                    node_b <= node_a + 2'd2; // A' = A+1, B' = A+2
                end else if (inc_node_b) begin
                    node_b <= node_b + 1'b1;
                end
            end
            
            // Mask and Result Updates
            if (state == ENUMERATE && next_state == VALIDATE) begin
                valid_flag <= 1'b1;
            end
            
            if (update_res) begin
                if (valid_flag) begin
                    max_count <= popcount_val;
                    result <= popcount_val;
                end
            end
            
            if (inc_mask) begin
                current_mask <= current_mask + 1'b1;
            end
        end
    end
    
    // Combinational Distance Calculator
    reg [3:0] dist_calc;
    reg [3:0] lca_node;
    always @(*) begin
        reg [3:0] a = node_a;
        reg [3:0] b = node_b;
        reg [3:0] da = depth[a];
        reg [3:0] db = depth[b];
        // Align depths
        if (da > db) begin
            repeat(15) if (a != 0 && depth[a] > db) a = parent[a];
        end else if (db > da) begin
            repeat(15) if (b != 0 && depth[b] > da) b = parent[b];
        end
        // Find LCA
        if (a == b) begin
            lca_node = a;
        end else begin
            repeat(15) begin
                if (a != b) begin
                    if (a != 0) a = parent[a];
                    if (b != 0) b = parent[b];
                end
            end
            lca_node = a; // or b
        end
        // Calc distance
        if (!is_marked_a || !is_marked_b || node_a >= N || node_b >= N) begin
            dist_calc = 4'hF; // Invalid or ignored
        end else begin
            dist_calc = depth[node_a] + depth[node_b] - 2 * depth[lca_node];
        end
    end
    
    // Popcount Logic
    wire [3:0] popcount_val;
    assign popcount_val = 
        (4)'( (current_mask[0]) + (current_mask[1]) + (current_mask[2]) + (current_mask[3]) + 
              (current_mask[4]) + (current_mask[5]) + (current_mask[6]) + (current_mask[7]) +
              (current_mask[8]) + (current_mask[9]) + (current_mask[10]) + (current_mask[11]) +
              (current_mask[12]) + (current_mask[13]) + (current_mask[14]) );

endmodule