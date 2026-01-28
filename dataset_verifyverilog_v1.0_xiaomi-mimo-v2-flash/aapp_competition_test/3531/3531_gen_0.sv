module MST_Kruskal (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] edge_in,
    input wire [4:0] edge_count,
    input wire [15:0] special_mask,
    input wire [3:0] target_w,
    output reg [15:0] result,
    output reg done
);

    // Local parameters for states
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD_EDGES = 3'd1;
    localparam [2:0] SORT_EDGES = 3'd2;
    localparam [2:0] PROCESS    = 3'd3;
    localparam [2:0] FINISH     = 3'd4;
    localparam [2:0] ERROR      = 3'd5;

    // Internal signals and registers
    reg [2:0] state, next_state;
    reg [4:0] idx;              // Index for loading/sorting
    reg [4:0] limit;            // Loop limit
    reg [4:0] edges_added;
    reg [3:0] current_w;
    reg [15:0] total_cost;
    
    // Edge storage: 32 entries x 32 bits
    reg [31:0] edges [0:31];
    
    // Comparator outputs for bubble sort
    wire [31:0] comp_a;
    wire [31:0] comp_b;
    wire swap;
    
    // Parent array for Union-Find (max 16 nodes)
    reg [3:0] parent [0:15];
    
    // Temporary registers for bubble sort
    reg [31:0] temp_edge;
    
    // Edge extraction
    wire [15:0] edge_cost = edge_in[15:0];
    wire [7:0] node_a = edge_in[23:16];
    wire [7:0] node_b = edge_in[31:24];
    
    // Find root function (combinational)
    function automatic [3:0] find_root;
        input [3:0] node;
        reg [3:0] current;
        reg [3:0] root;
        reg [3:0] temp_parent;
        integer i;
        begin
            current = node;
            // Follow parent pointers
            for (i = 0; i < 16; i = i + 1) begin
                if (parent[current] != current) begin
                    current = parent[current];
                end else begin
                    root = current;
                    find_root = root;
                    return root;
                end
            end
            find_root = current;
        end
    endfunction
    
    // Union function
    function automatic union_sets;
        input [3:0] root_a;
        input [3:0] root_b;
        begin
            if (root_a != root_b) begin
                parent[root_b] = root_a;
                union_sets = 1'b1;
            end else begin
                union_sets = 1'b0;
            end
        end
    endfunction
    
    // Edge comparator for cost (16-bit comparison)
    assign comp_a = edges[idx];
    assign comp_b = edges[idx + 5'd1];
    assign swap = (comp_a[15:0] > comp_b[15:0]);
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            idx <= 5'd0;
            edges_added <= 5'd0;
            current_w <= 4'd0;
            total_cost <= 16'd0;
            limit <= 5'd0;
            // Initialize parent array
            parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3;
            parent[4] <= 4'd4; parent[5] <= 4'd5; parent[6] <= 4'd6; parent[7] <= 4'd7;
            parent[8] <= 4'd8; parent[9] <= 4'd9; parent[10] <= 4'd10; parent[11] <= 4'd11;
            parent[12] <= 4'd12; parent[13] <= 4'd13; parent[14] <= 4'd14; parent[15] <= 4'd15;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    edges_added <= 5'd0;
                    current_w <= 4'd0;
                    total_cost <= 16'd0;
                    idx <= 5'd0;
                end
                
                LOAD_EDGES: begin
                    if (start) begin
                        limit <= edge_count;
                    end else if (idx < limit) begin
                        edges[idx] <= edge_in;
                        idx <= idx + 5'd1;
                    end
                end
                
                SORT_EDGES: begin
                    // Bubble sort iteration
                    if (idx < (limit - 5'd1)) begin
                        if (swap) begin
                            edges[idx] <= comp_b;
                            edges[idx + 5'd1] <= comp_a;
                        end
                        idx <= idx + 5'd1;
                    end
                end
                
                PROCESS: begin
                    if (idx < limit) begin
                        // Process edge
                        if (edges[idx][15:0] != 16'hFFFF) begin // Valid edge
                            // Check if special-nonspecial edge
                            if ( (special_mask[edges[idx][23:16]-1] && !special_mask[edges[idx][31:24]-1]) ||
                                 (!special_mask[edges[idx][23:16]-1] && special_mask[edges[idx][31:24]-1]) ) begin
                                current_w <= current_w + 4'd1;
                            end
                            // Union-Find logic
                            // Note: This is simplified - actual find_root needs cycle delay
                            // We'll use a sequential approach for union-find
                        end
                        idx <= idx + 5'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if ((edges_added == (limit - 5'd1)) && (current_w == target_w)) begin
                        result <= total_cost;
                    end else begin
                        result <= 16'hFFFF; // -1 in 16-bit signed
                    end
                end
                
                ERROR: begin
                    done <= 1'b1;
                    result <= 16'hFFFF;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_EDGES;
            end
            
            LOAD_EDGES: begin
                if (start) next_state = IDLE;
                else if (idx >= limit) next_state = SORT_EDGES;
            end
            
            SORT_EDGES: begin
                // Sort for multiple passes
                if (idx >= (limit - 5'd1)) begin
                    next_state = PROCESS;
                end
            end
            
            PROCESS: begin
                if (idx >= limit) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Union-Find sequential processing (separate always block for cycles)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized above
        end else if (state == PROCESS && idx < limit) begin
            // Process current edge
            if (edges[idx][15:0] != 16'hFFFF) begin
                // Find roots
                reg [3:0] root_a;
                reg [3:0] root_b;
                root_a = find_root(edges[idx][23:16] - 8'd1);
                root_b = find_root(edges[idx][31:24] - 8'd1);
                
                if (root_a != root_b) begin
                    // No cycle - add edge
                    parent[root_b] <= root_a;
                    edges_added <= edges_added + 5'd1;
                    total_cost <= total_cost + edges[idx][15:0];
                    
                    // Count special-nonspecial edge
                    if ( (special_mask[edges[idx][23:16]-1] && !special_mask[edges[idx][31:24]-1]) ||
                         (!special_mask[edges[idx][23:16]-1] && special_mask[edges[idx][31:24]-1]) ) begin
                        // current_w is updated in main state machine
                    end
                end
            end
        end
    end
    
    // Fix for current_w update in PROCESS state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_w <= 4'd0;
        end else if (state == PROCESS && idx < limit) begin
            if (edges[idx][15:0] != 16'hFFFF) begin
                // Find roots
                reg [3:0] root_a;
                reg [3:0] root_b;
                root_a = find_root(edges[idx][23:16] - 8'd1);
                root_b = find_root(edges[idx][31:24] - 8'd1);
                
                if (root_a != root_b) begin
                    // Check if special-nonspecial edge
                    reg is_special_a;
                    reg is_special_b;
                    is_special_a = special_mask[edges[idx][23:16] - 8'd1];
                    is_special_b = special_mask[edges[idx][31:24] - 8'd1];
                    
                    if (is_special_a ^ is_special_b) begin
                        current_w <= current_w + 4'd1;
                    end
                end
            end
        end else if (state == IDLE) begin
            current_w <= 4'd0;
        end
    end

endmodule