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
localparam [5:0] NODE_SOURCE = 6'd0;
localparam [5:0] NODE_SINK = 6'd1;
localparam [5:0] NODE_SUPPLIERS_START = 6'd2;
localparam [5:0] NODE_FACTORIES_START = 6'd10;  // After suppliers (max 8)
localparam [5:0] NODE_COMPANIES_START = 6'd18;  // After factories (max 8)
localparam [5:0] MAX_NODES = 6'd26;              // Total nodes: 1+1+8+8+8
localparam [5:0] INVALID_NODE = 6'd63;

// Flow network adjacency matrix (capacity)
reg [7:0] capacity [0:25][0:25];
// Flow matrix
reg [7:0] flow [0:25][0:25];

// BFS and state machine variables
reg [5:0] parent [0:25];      // For path reconstruction
reg [5:0] queue [0:25];       // BFS queue
reg [5:0] queue_head, queue_tail;
reg visited [0:25];

// Algorithm state
reg [3:0] state;
localparam [3:0] S_IDLE = 4'd0;
localparam [3:0] S_BUILD_NETWORK = 4'd1;
localparam [3:0] S_BFS_INIT = 4'd2;
localparam [3:0] S_BFS_PROCESS = 4'd3;
localparam [3:0] S_BFS_PROCESS_NEIGHBORS = 4'd4;
localparam [3:0] S_UPDATE_FLOW = 4'd5;
localparam [3:0] S_FIND_MIN = 4'd6;
localparam [3:0] S_UPDATE_FLOW_ALONG = 4'd7;
localparam [3:0] S_CHECK_DONE = 4'd8;
localparam [3:0] S_FINISH = 4'd9;

// Loop counters
reg [3:0] i, j, k, m;
reg [5:0] u, v;
reg [7:0] path_flow;
reg [7:0] max_flow_reg;

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 0;
        max_flow <= 0;
        max_flow_reg <= 0;
        i <= 0;
        j <= 0;
        k <= 0;
        m <= 0;
        u <= 0;
        v <= 0;
        path_flow <= 0;
        queue_head <= 0;
        queue_tail <= 0;
        // Reset matrices
        for (i = 0; i < 26; i = i + 1) begin
            for (j = 0; j < 26; j = j + 1) begin
                capacity[i][j] <= 8'd0;
                flow[i][j] <= 8'd0;
            end
            parent[i] <= INVALID_NODE;
            visited[i] <= 0;
            queue[i] <= 6'd0;
        end
    end else begin
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= S_BUILD_NETWORK;
                    max_flow_reg <= 8'd0;
                    i <= 4'd0;
                end
            end
            
            S_BUILD_NETWORK: begin
                // Build flow network
                if (i == 4'd0) begin
                    // Edges from source to suppliers
                    if (j < 8) begin
                        if (j < num_suppliers) begin
                            capacity[NODE_SOURCE][NODE_SUPPLIERS_START + j] <= 8'd1;
                        end else begin
                            capacity[NODE_SOURCE][NODE_SUPPLIERS_START + j] <= 8'd0;
                        end
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;
                        i <= 4'd1;
                    end
                end else if (i == 4'd1) begin
                    // Edges from factories to sink
                    if (j < 8) begin
                        if (j < num_factories) begin
                            capacity[NODE_FACTORIES_START + j][NODE_SINK] <= 8'd1;
                        end else begin
                            capacity[NODE_FACTORIES_START + j][NODE_SINK] <= 8'd0;
                        end
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;
                        k <= 4'd0;
                        i <= 4'd2;
                    end
                end else if (i == 4'd2) begin
                    // Edges from suppliers to companies
                    if (j < num_suppliers) begin
                        if (k < num_companies) begin
                            // Check if company k can operate in supplier j's state
                            if (k < 8 && j < 8 && k < 8'd8) begin
                                if (company_states[k][0] == supplier_states[j] && company_states[k][0] != 4'hF) begin
                                    capacity[NODE_SUPPLIERS_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                end else if (company_states[k][1] == supplier_states[j] && company_states[k][1] != 4'hF) begin
                                    capacity[NODE_SUPPLIERS_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                end else if (company_states[k][2] == supplier_states[j] && company_states[k][2] != 4'hF) begin
                                    capacity[NODE_SUPPLIERS_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                end else if (company_states[k][3] == supplier_states[j] && company_states[k][3] != 4'hF) begin
                                    capacity[NODE_SUPPLIERS_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                end else if (company_states[k][4] == supplier_states[j] && company_states[k][4] != 4'hF) begin
                                    capacity[NODE_SUPPLIERS_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                end else if (company_states[k][5] == supplier_states[j] && company_states[k][5] != 4'hF) begin
                                    capacity[NODE_SUPPLIERS_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                end else if (company_states[k][6] == supplier_states[j] && company_states[k][6] != 4'hF) begin
                                    capacity[NODE_SUPPLIERS_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                end else if (company_states[k][7] == supplier_states[j] && company_states[k][7] != 4'hF) begin
                                    capacity[NODE_SUPPLIERS_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                end else begin
                                    capacity[NODE_SUPPLIERS_START + j][NODE_COMPANIES_START + k] <= 8'd0;
                                end
                            end
                            k <= k + 4'd1;
                        end else begin
                            k <= 4'd0;
                            j <= j + 4'd1;
                        end
                    end else begin
                        j <= 4'd0;
                        k <= 4'd0;
                        i <= 4'd3;
                    end
                end else if (i == 4'd3) begin
                    // Edges from companies to factories
                    if (j < num_companies) begin
                        if (k < num_factories) begin
                            // Check if company j can operate in factory k's state
                            if (j < 8 && k < 8) begin
                                if (company_states[j][0] == factory_states[k] && company_states[j][0] != 4'hF) begin
                                    capacity[NODE_COMPANIES_START + j][NODE_FACTORIES_START + k] <= 8'd1;
                                end else if (company_states[j][1] == factory_states[k] && company_states[j][1] != 4'hF) begin
                                    capacity[NODE_COMPANIES_START + j][NODE_FACTORIES_START + k] <= 8'd1;
                                end else if (company_states[j][2] == factory_states[k] && company_states[j][2] != 4'hF) begin
                                    capacity[NODE_COMPANIES_START + j][NODE_FACTORIES_START + k] <= 8'd1;
                                end else if (company_states[j][3] == factory_states[k] && company_states[j][3] != 4'hF) begin
                                    capacity[NODE_COMPANIES_START + j][NODE_FACTORIES_START + k] <= 8'd1;
                                end else if (company_states[j][4] == factory_states[k] && company_states[j][4] != 4'hF) begin
                                    capacity[NODE_COMPANIES_START + j][NODE_FACTORIES_START + k] <= 8'd1;
                                end else if (company_states[j][5] == factory_states[k] && company_states[j][5] != 4'hF) begin
                                    capacity[NODE_COMPANIES_START + j][NODE_FACTORIES_START + k] <= 8'd1;
                                end else if (company_states[j][6] == factory_states[k] && company_states[j][6] != 4'hF) begin
                                    capacity[NODE_COMPANIES_START + j][NODE_FACTORIES_START + k] <= 8'd1;
                                end else if (company_states[j][7] == factory_states[k] && company_states[j][7] != 4'hF) begin
                                    capacity[NODE_COMPANIES_START + j][NODE_FACTORIES_START + k] <= 8'd1;
                                end else begin
                                    capacity[NODE_COMPANIES_START + j][NODE_FACTORIES_START + k] <= 8'd0;
                                end
                            end
                            k <= k + 4'd1;
                        end else begin
                            k <= 4'd0;
                            j <= j + 4'd1;
                        end
                    end else begin
                        j <= 4'd0;
                        k <= 4'd0;
                        m <= 4'd0;
                        i <= 4'd4;
                    end
                end else if (i == 4'd4) begin
                    // Edges between companies (if they share any state)
                    if (j < num_companies) begin
                        if (k < num_companies && k != j) begin
                            // Check for common state
                            if (j < 8 && k < 8) begin
                                if (company_states[j][0] != 4'hF && company_states[k][0] != 4'hF) begin
                                    if (company_states[j][0] == company_states[k][0]) begin
                                        capacity[NODE_COMPANIES_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                    end else if (company_states[j][0] == company_states[k][1]) begin
                                        capacity[NODE_COMPANIES_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                    end else if (company_states[j][0] == company_states[k][2]) begin
                                        capacity[NODE_COMPANIES_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                    end else if (company_states[j][0] == company_states[k][3]) begin
                                        capacity[NODE_COMPANIES_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                    end else if (company_states[j][0] == company_states[k][4]) begin
                                        capacity[NODE_COMPANIES_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                    end else if (company_states[j][0] == company_states[k][5]) begin
                                        capacity[NODE_COMPANIES_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                    end else if (company_states[j][0] == company_states[k][6]) begin
                                        capacity[NODE_COMPANIES_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                    end else if (company_states[j][0] == company_states[k][7]) begin
                                        capacity[NODE_COMPANIES_START + j][NODE_COMPANIES_START + k] <= 8'd1;
                                    end else begin
                                        capacity[NODE_COMPANIES_START + j][NODE_COMPANIES_START + k] <= 8'd0;
                                    end
                                end else begin
                                    capacity[NODE_COMPANIES_START + j][NODE_COMPANIES_START + k] <= 8'd0;
                                end
                            end
                            k <= k + 4'd1;
                        end else begin
                            k <= 4'd0;
                            j <= j + 4'd1;
                        end
                    end else begin
                        state <= S_BFS_INIT;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end
            end
            
            S_BFS_INIT: begin
                // Initialize BFS for augmenting path search
                for (i = 0; i < 26; i = i + 1) begin
                    parent[i] <= INVALID_NODE;
                    visited[i] <= 1'b0;
                    queue[i] <= 6'd0;
                end
                queue_head <= 6'd0;
                queue_tail <= 6'd0;
                queue[0] <= NODE_SOURCE;
                visited[NODE_SOURCE] <= 1'b1;
                state <= S_BFS_PROCESS;
                i <= 4'd0;
                j <= 4'd0;
            end
            
            S_BFS_PROCESS: begin
                if (queue_head < queue_tail || (queue_head == 6'd0 && queue_tail == 6'd0 && visited[NODE_SOURCE])) begin
                    u <= queue[queue_head];
                    queue_head <= queue_head + 6'd1;
                    j <= 6'd0;
                    state <= S_BFS_PROCESS_NEIGHBORS;
                end else begin
                    // BFS complete, check if sink was reached
                    if (parent[NODE_SINK] != INVALID_NODE) begin
                        state <= S_UPDATE_FLOW;
                    end else begin
                        state <= S_CHECK_DONE;
                    end
                end
            end
            
            S_BFS_PROCESS_NEIGHBORS: begin
                if (j < MAX_NODES) begin
                    // Check capacity and residual flow
                    if (capacity[u][j] > flow[u][j] && !visited[j]) begin
                        queue[queue_tail] <= j;
                        queue_tail <= queue_tail + 6'd1;
                        parent[j] <= u;
                        visited[j] <= 1'b1;
                    end
                    j <= j + 6'd1;
                end else begin
                    j <= 6'd0;
                    state <= S_BFS_PROCESS;
                end
            end
            
            S_UPDATE_FLOW: begin
                // Find minimum residual capacity along path
                path_flow <= 8'd255;  // Initialize to large value
                v <= NODE_SINK;
                state <= S_FIND_MIN;
            end
            
            S_FIND_MIN: begin
                if (parent[v] != INVALID_NODE && parent[v] != NODE_SOURCE) begin
                    u <= parent[v];
                    if (capacity[parent[v]][v] - flow[parent[v]][v] < path_flow) begin
                        path_flow <= capacity[parent[v]][v] - flow[parent[v]][v];
                    end
                    v <= parent[v];
                end else if (parent[v] != INVALID_NODE) begin
                    // Reached source, update flow
                    v <= NODE_SINK;
                    state <= S_UPDATE_FLOW_ALONG;
                end else begin
                    state <= S_BFS_INIT;  // Shouldn't happen
                end
            end
            
            S_UPDATE_FLOW_ALONG: begin
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
                done <= 1'b1;
                state <= S_IDLE;
            end
            
            default: state <= S_IDLE;
        endcase
    end
end

endmodule