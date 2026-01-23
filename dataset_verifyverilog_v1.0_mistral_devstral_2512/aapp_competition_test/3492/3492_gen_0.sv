module max_flow_network (
    input wire clk,
    input wire rst_n,
    input wire start,

    // Network configuration
    input wire [3:0] num_suppliers,      // 1-8
    input wire [3:0] num_factories,      // 1-8  
    input wire [3:0] num_companies,      // 1-8

    // Supplier states: supplier_states[i] = state index (0-15)
    input wire [3:0] supplier_states [0:7],

    // Factory states: factory_states[i] = state index (0-15)
    input wire [3:0] factory_states [0:7],

    // Company states: company_states[i][j] = state index for company i, state j
    // Valid states are 0-15, 15 = invalid/unused
    input wire [3:0] company_states [0:7][0:7],

    // Output
    output reg [7:0] max_flow,           // Result: number of matched factories
    output reg done                      // Computation complete
);

// Internal parameters
localparam NODE_SOURCE = 0;
localparam NODE_SINK = 1;
localparam NODE_SUPPLIERS_START = 2;
localparam NODE_FACTORIES_START = 10;  // After suppliers (max 8)
localparam NODE_COMPANIES_START = 18;  // After factories (max 8)
localparam MAX_NODES = 26;              // Total nodes: 1+1+8+8+8
localparam INVALID_NODE = 63;

// Flow network adjacency matrix (capacity)
reg [7:0] capacity [0:MAX_NODES-1][0:MAX_NODES-1];
// Flow matrix
reg [7:0] flow [0:MAX_NODES-1][0:MAX_NODES-1];

// BFS and state machine variables
reg [5:0] parent [0:MAX_NODES-1];      // For path reconstruction
reg [5:0] queue [0:MAX_NODES-1];       // BFS queue
reg [5:0] queue_head, queue_tail;
reg visited [0:MAX_NODES-1];

// Algorithm state
reg [3:0] state;
localparam S_IDLE = 0;
localparam S_BUILD_NETWORK = 1;
localparam S_BFS_INIT = 2;
localparam S_BFS_PROCESS = 3;
localparam S_UPDATE_FLOW = 4;
localparam S_CHECK_DONE = 5;
localparam S_FINISH = 6;

// Loop counters
reg [3:0] i, j, k;
reg [5:0] u, v;
reg [7:0] path_flow;
reg [7:0] max_flow_reg;

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 0;
        max_flow <= 0;
        // Reset matrices
        for (i = 0; i < MAX_NODES; i = i + 1) begin
            for (j = 0; j < MAX_NODES; j = j + 1) begin
                capacity[i][j] <= 0;
                flow[i][j] <= 0;
            end
        end
    end else begin
        case (state)
            S_IDLE: begin
                done <= 0;
                if (start) begin
                    state <= S_BUILD_NETWORK;
                    max_flow_reg <= 0;
                end
            end
            
            S_BUILD_NETWORK: begin
                // Build flow network
                // Edges from source to suppliers
                for (i = 0; i < 8; i = i + 1) begin
                    if (i < num_suppliers) begin
                        capacity[NODE_SOURCE][NODE_SUPPLIERS_START + i] <= 1;
                    end else begin
                        capacity[NODE_SOURCE][NODE_SUPPLIERS_START + i] <= 0;
                    end
                end
                
                // Edges from factories to sink
                for (i = 0; i < 8; i = i + 1) begin
                    if (i < num_factories) begin
                        capacity[NODE_FACTORIES_START + i][NODE_SINK] <= 1;
                    end else begin
                        capacity[NODE_FACTORIES_START + i][NODE_SINK] <= 0;
                    end
                end
                
                // Edges from suppliers to companies (if company operates in supplier state)
                for (i = 0; i < 8; i = i + 1) begin  // suppliers
                    if (i < num_suppliers) begin
                        for (j = 0; j < 8; j = j + 1) begin  // companies
                            if (j < num_companies) begin
                                // Check if company j can operate in supplier i's state
                                for (k = 0; k < 8; k = k + 1) begin
                                    if (company_states[j][k] == supplier_states[i] && company_states[j][k] != 4'hF) begin
                                        capacity[NODE_SUPPLIERS_START + i][NODE_COMPANIES_START + j] <= 1;
                                    end
                                end
                            end
                        end
                    end
                end
                
                // Edges from companies to factories (if company operates in factory state)
                for (i = 0; i < 8; i = i + 1) begin  // companies
                    if (i < num_companies) begin
                        for (j = 0; j < 8; j = j + 1) begin  // factories
                            if (j < num_factories) begin
                                // Check if company i can operate in factory j's state
                                for (k = 0; k < 8; k = k + 1) begin
                                    if (company_states[i][k] == factory_states[j] && company_states[i][k] != 4'hF) begin
                                        capacity[NODE_COMPANIES_START + i][NODE_FACTORIES_START + j] <= 1;
                                    end
                                end
                            end
                        end
                    end
                end
                
                // Edges between companies (if they share any state)
                for (i = 0; i < 8; i = i + 1) begin  // companies i
                    if (i < num_companies) begin
                        for (j = 0; j < 8; j = j + 1) begin  // companies j
                            if (j < num_companies && i != j) begin
                                // Check for common state
                                for (k = 0; k < 8; k = k + 1) begin
                                    if (company_states[i][k] != 4'hF) begin
                                        for (int m = 0; m < 8; m = m + 1) begin
                                            if (company_states[j][m] == company_states[i][k] && company_states[j][m] != 4'hF) begin
                                                capacity[NODE_COMPANIES_START + i][NODE_COMPANIES_START + j] <= 1;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                state <= S_BFS_INIT;
            end
            
            S_BFS_INIT: begin
                // Initialize BFS for augmenting path search
                for (i = 0; i < MAX_NODES; i = i + 1) begin
                    parent[i] <= INVALID_NODE;
                    visited[i] <= 0;
                end
                queue_head <= 0;
                queue_tail <= 0;
                queue[0] <= NODE_SOURCE;
                visited[NODE_SOURCE] <= 1;
                state <= S_BFS_PROCESS;
            end
            
            S_BFS_PROCESS: begin
                if (queue_head < queue_tail || (queue_head == 0 && queue_tail == 0 && visited[NODE_SOURCE])) begin
                    u <= queue[queue_head];
                    queue_head <= queue_head + 1;
                    state <= 3'd3;  // Process neighbors
                end else begin
                    // BFS complete, check if sink was reached
                    if (parent[NODE_SINK] != INVALID_NODE) begin
                        state <= S_UPDATE_FLOW;
                    end else begin
                        state <= S_CHECK_DONE;
                    end
                end
            end
            
            3'd3: begin  // Process neighbors of u
                if (j < MAX_NODES) begin
                    // Check capacity and residual flow
                    if (capacity[u][j] > flow[u][j] && !visited[j]) begin
                        queue[queue_tail] <= j;
                        queue_tail <= queue_tail + 1;
                        parent[j] <= u;
                        visited[j] <= 1;
                    end
                    j <= j + 1;
                end else begin
                    j <= 0;
                    state <= S_BFS_PROCESS;
                end
            end
            
            S_UPDATE_FLOW: begin
                // Find minimum residual capacity along path
                path_flow <= 255;  // Initialize to large value
                v <= NODE_SINK;
                state <= 4'd4;  // Find min capacity
            end
            
            4'd4: begin  // Find min capacity
                if (parent[v] != INVALID_NODE && parent[v] != NODE_SOURCE) begin
                    u <= parent[v];
                    if (capacity[parent[v]][v] - flow[parent[v]][v] < path_flow) begin
                        path_flow <= capacity[parent[v]][v] - flow[parent[v]][v];
                    end
                    v <= parent[v];
                end else if (parent[v] != INVALID_NODE) begin
                    // Reached source, update flow
                    v <= NODE_SINK;
                    state <= 4'd5;  // Update flow along path
                end else begin
                    state <= S_BFS_INIT;  // Shouldn't happen
                end
            end
            
            4'd5: begin  // Update flow along path
                if (parent[v] != INVALID_NODE) begin
                    // Forward edge
                    flow[parent[v]][v] <= flow[parent[v]][v] + path_flow;
                    // Backward edge (residual)
                    flow[v][parent[v]] <= flow[v][parent[v]] - path_flow;
                    v <= parent[v];
                end else begin
                    max_flow_reg <= max_flow_reg + path_flow;
                    state <= S_BFS_INIT;  // Look for more augmenting paths
                end
            end
            
            S_CHECK_DONE: begin
                // No more augmenting paths
                max_flow <= max_flow_reg;
                state <= S_FINISH;
            end
            
            S_FINISH: begin
                done <= 1;
                state <= S_IDLE;
            end
            
            default: state <= S_IDLE;
        endcase
    end
end

endmodule