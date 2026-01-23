module gem_smash_solver (
    input clk,
    input rst_n,
    input start,
    input [15:0][15:0] gem_values,
    output reg [31:0] max_earnings,
    output reg done
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam STAGE1 = 3'b001;
    localparam STAGE2 = 3'b010;
    localparam DONE = 3'b100;
    
    localparam NUM_GEMS = 16;
    localparam NUM_NODES = 18; // 0-15: gems, 16: source, 17: sink
    localparam INF_CAPACITY = 20'b11111111111111111111; // Large constant for infinite capacity
    localparam MAX_BFS_ITER = 64;

    // State registers
    reg [2:0] state;
    reg [5:0] bfs_iter;
    reg [31:0] total_positive;
    reg [31:0] flow;
    reg [31:0] max_flow;

    // Residual graph representation (simplified for hardware)
    reg [19:0] residual [0:NUM_NODES-1][0:NUM_NODES-1];
    reg [19:0] temp_residual [0:NUM_NODES-1][0:NUM_NODES-1];

    // BFS state
    reg [4:0] queue [0:NUM_NODES-1];
    reg [4:0] queue_head, queue_tail;
    reg [4:0] parent [0:NUM_NODES-1];
    reg [4:0] current_node;
    reg found_path;

    // Initialize residual graph
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bfs_iter <= 0;
            total_positive <= 0;
            flow <= 0;
            max_flow <= 0;
            done <= 0;
            max_earnings <= 0;
        end else if (state == IDLE && start) begin
            state <= STAGE1;
            total_positive <= 0;
            max_flow <= 0;
            done <= 0;
        end
    end

    // Stage 1: Compute total positive and initialize residual graph
    always @(posedge clk) begin
        if (state == STAGE1) begin
            integer i, j;
            
            // Initialize residual graph
            for (i = 0; i < NUM_NODES; i = i + 1) begin
                for (j = 0; j < NUM_NODES; j = j + 1) begin
                    residual[i][j] <= 0;
                end
            end
            
            // Compute total positive and set up source/sink edges
            total_positive <= 0;
            for (i = 0; i < NUM_GEMS; i = i + 1) begin
                if (gem_values[i][15]) begin // Negative
                    residual[i][17] <= -$signed(gem_values[i]); // i -> T
                end else begin // Positive
                    residual[16][i] <= $signed(gem_values[i]); // S -> i
                    total_positive <= total_positive + $signed(gem_values[i]);
                end
            end
            
            // Set up gem-to-gem edges (multiples)
            for (i = 0; i < NUM_GEMS; i = i + 1) begin
                for (j = 0; j < NUM_GEMS; j = j + 1) begin
                    if (gem_values[j][15] == 0 && (j+1) % (i+1) == 0) begin
                        residual[i][j] <= INF_CAPACITY;
                    end
                end
            end
            
            state <= STAGE2;
            bfs_iter <= 0;
            max_flow <= 0;
        end
    end

    // Stage 2: Max Flow with BFS
    always @(posedge clk) begin
        if (state == STAGE2) begin
            if (bfs_iter < MAX_BFS_ITER) begin
                // Initialize BFS
                queue_head <= 0;
                queue_tail <= 0;
                found_path <= 0;
                
                // Reset parent array
                for (integer i = 0; i < NUM_NODES; i = i + 1) begin
                    parent[i] <= 0;
                end
                
                // Start BFS from source (node 16)
                queue[0] <= 16;
                queue_tail <= queue_tail + 1;
                parent[16] <= 16;
                
                // BFS loop (simplified for hardware)
                current_node <= queue[queue_head];
                queue_head <= queue_head + 1;
                
                // Check neighbors
                for (integer j = 0; j < NUM_NODES; j = j + 1) begin
                    if (residual[current_node][j] > 0 && parent[j] == 0) begin
                        parent[j] <= current_node;
                        queue[queue_tail] <= j;
                        queue_tail <= queue_tail + 1;
                        
                        if (j == 17) begin // Reached sink
                            found_path <= 1;
                        end
                    end
                end
                
                // If path found, augment flow
                if (found_path) begin
                    // Find minimum residual capacity along path
                    integer v = 17;
                    integer min_cap = residual[parent[v]][v];
                    while (parent[v] != v) begin
                        if (residual[parent[v]][v] < min_cap) begin
                            min_cap = residual[parent[v]][v];
                        end
                        v = parent[v];
                    end
                    
                    // Update residual graph
                    v = 17;
                    while (parent[v] != v) begin
                        residual[parent[v]][v] <= residual[parent[v]][v] - min_cap;
                        residual[v][parent[v]] <= residual[v][parent[v]] + min_cap;
                        v = parent[v];
                    end
                    
                    max_flow <= max_flow + min_cap;
                end
                
                bfs_iter <= bfs_iter + 1;
            end else begin
                // Done with BFS iterations
                max_earnings <= total_positive - max_flow;
                done <= 1;
                state <= DONE;
            end
        end else if (state == DONE && !start) begin
            state <= IDLE;
            done <= 0;
        end
    end

endmodule