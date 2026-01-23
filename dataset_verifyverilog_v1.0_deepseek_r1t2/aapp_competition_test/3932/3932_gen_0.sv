module tree_checker(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] c0,
    input [7:0] c1,
    input [7:0] c2,
    input [7:0] c3,
    input [7:0] c4,
    input [7:0] c5,
    input [7:0] c6,
    input [7:0] c7,
    output reg done,
    output reg yes
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] INIT          = 3'd1;
    localparam [2:0] BUILD_GRAPH   = 3'd2;
    localparam [2:0] COMPUTE_SIZES = 3'd3;
    localparam [2:0] VALIDATE      = 3'd4;
    localparam [2:0] FAIL          = 3'd5;
    localparam [2:0] SUCCESS       = 3'd6;

    reg [2:0] state;
    reg [2:0] current_node;
    reg [7:0] c_array [0:7];  // Stored input values
    reg [7:0] calc_sizes [0:7];  // Computed subtree sizes
    reg [2:0] parent [0:7];  // Parent assignments
    reg [2:0] children_count [0:7];  // Child counts per node
    reg [2:0] node_iter;  // General purpose iterator
    reg [7:0] cycle_count;
    
    integer i;  // For-loop variable

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            done <= 1'b0;
            yes <= 1'b0;
            state <= IDLE;
            current_node <= 3'd1;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                c_array[i] <= 8'd0;
                calc_sizes[i] <= 8'd0;
                parent[i] <= 3'd7;  // Invalid parent
                children_count[i] <= 3'd0;
            end
        end
        else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    yes <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Store input values
                        c_array[0] <= c0;
                        c_array[1] <= c1;
                        c_array[2] <= c2;
                        c_array[3] <= c3;
                        c_array[4] <= c4;
                        c_array[5] <= c5;
                        c_array[6] <= c6;
                        c_array[7] <= c7;
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize parent assignments
                    parent[0] <= 3'd0;
                    for (i = 1; i < 8; i = i + 1) begin
                        parent[i] <= 3'd7;
                        children_count[i] <= 3'd0;
                    end
                    current_node <= 3'd1;
                    state <= BUILD_GRAPH;
                end

                BUILD_GRAPH: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (current_node < n) begin
                        if (parent[current_node] == 3'd7) begin
                            parent[current_node] <= 3'd0;  // Start with root
                            children_count[0] <= children_count[0] + 3'd1;
                        end
                        else if (parent[current_node] + 1 < current_node) begin
                            // Decrement old parent's child count
                            children_count[parent[current_node]] <= children_count[parent[current_node]] - 3'd1;
                            parent[current_node] <= parent[current_node] + 3'd1;
                            children_count[parent[current_node] + 1] <= children_count[parent[current_node] + 1] + 3'd1;
                        end
                        else begin
                            // Backtrack
                            if (current_node == 3'd1) begin
                                state <= FAIL;
                            end
                            else begin
                                children_count[parent[current_node]] <= children_count[parent[current_node]] - 3'd1;
                                parent[current_node] <= 3'd7;
                                current_node <= current_node - 3'd1;
                                children_count[parent[current_node]] <= children_count[parent[current_node]] - 3'd1;
                                return;
                            end
                        end
                        
                        // Prevent invalid parents
                        if (parent[current_node] >= current_node)
                            state <= BUILD_GRAPH;
                        else
                            state <= COMPUTE_SIZES;
                    end
                    else begin
                        state <= COMPUTE_SIZES;
                    end
                end

                COMPUTE_SIZES: begin
                    // Reset computed sizes
                    for (i = 0; i < 8; i = i + 1)
                        calc_sizes[i] <= 8'd1;
                    
                    // Compute subtree sizes (starting from leaves)
                    for (node_iter = n-1; node_iter > 0; node_iter = node_iter - 3'd1) begin
                        if (parent[node_iter] < node_iter) 
                            calc_sizes[parent[node_iter]] <= calc_sizes[parent[node_iter]] + calc_sizes[node_iter];
                    end
                    
                    state <= VALIDATE;
                end

                VALIDATE: begin
                    // Check root condition
                    if (calc_sizes[0] != n) begin
                        state <= BUILD_GRAPH;
                        current_node <= current_node + 3'd1;
                        return;
                    end
                    
                    // Check all conditions
                    for (i = 0; i < n; i = i + 1) begin
                        // No node can have size 2
                        if (c_array[i] == 8'd2) begin
                            state <= BUILD_GRAPH;
                            current_node <= current_node + 3'd1;
                            return;
                        end
                        
                        // Check computed vs input
                        if (calc_sizes[i] != c_array[i]) begin
                            state <= BUILD_GRAPH;
                            current_node <= current_node + 3'd1;
                            return;
                        end
                        
                        // Internal nodes need >=2 children
                        if (i < n-1 && children_count[i] > 0 && children_count[i] < 2) begin
                            state <= BUILD_GRAPH;
                            current_node <= current_node + 3'd1;
                            return;
                        end
                    end
                    
                    state <= SUCCESS;
                end

                FAIL: begin
                    yes <= 1'b0;
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end

                SUCCESS: begin
                    yes <= 1'b1;
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            
            // Cycle timeout protection
            if (cycle_count > 8'd200) begin
                state <= FAIL;
            end
        end
    end
endmodule