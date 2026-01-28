module EscapeRoutes(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [2:0] h,
    input wire [2:0] edge_u [0:6],
    input wire [2:0] edge_v [0:6],
    output reg [2:0] m,
    output reg [2:0] added_u [0:3],
    output reg [2:0] added_v [0:3],
    output reg done
);

    // FSM Declarations
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] BUILD_ADJ     = 4'd1;
    localparam [3:0] COMP_DEGREES  = 4'd2;
    localparam [3:0] INIT_BFS      = 4'd3;
    localparam [3:0] BFS_RUN       = 4'd4;
    localparam [3:0] COMPUTE_M     = 4'd5;
    localparam [3:0] GEN_EDGES     = 4'd6;
    localparam [3:0] DONE_STATE    = 4'd7;
    
    reg [3:0] state, next_state;
    
    // Internal registers
    reg [3:0] n_reg;
    reg [2:0] h_reg;
    reg [2:0] edge_u_reg [0:6];
    reg [2:0] edge_v_reg [0:6];
    
    // Adjacency Matrix
    reg [7:0] adj_matrix [0:7]; // adj_matrix[i][j] = bit j of adj_matrix[i]
    
    // Degree registers
    reg [3:0] degree_reg [0:7];
    
    // BFS related registers
    reg [2:0] queue [0:7];
    reg [2:0] front, rear;
    reg [7:0] visited;
    reg [3:0] leaf_count;
    reg [2:0] leaves [0:7];
    
    // Cycle counter for timeout
    reg [7:0] cycle_count;
    
    // Edge generation variables
    reg [3:0] L;
    
    // Loop counters
    integer i, j, k;
    
    // FSM and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            m <= 3'd0;
            cycle_count <= 8'd0;
            
            // Zero all arrays
            for (i = 0; i < 8; i = i + 1) begin
                adj_matrix[i] <= 8'd0;
                degree_reg[i] <= 4'd0;
                queue[i] <= 3'd0;
                leaves[i] <= 3'd0;
            end
            
            for (i = 0; i < 4; i = i + 1) begin
                added_u[i] <= 3'd0;
                added_v[i] <= 3'd0;
            end
            
            for (i = 0; i < 7; i = i + 1) begin
                edge_u_reg[i] <= 3'd0;
                edge_v_reg[i] <= 3'd0;
            end
            
            // Initialize other regs
            front <= 3'd0;
            rear <= 3'd0;
            visited <= 8'd0;
            leaf_count <= 4'd0;
            L <= 4'd0;
            n_reg <= 4'd0;
            h_reg <= 3'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Capture inputs
                        n_reg <= n;
                        h_reg <= h;
                        for (i = 0; i < 7; i = i + 1) begin
                            edge_u_reg[i] <= edge_u[i];
                            edge_v_reg[i] <= edge_v[i];
                        end
                        state <= BUILD_ADJ;
                    end
                end
                
                BUILD_ADJ: begin
                    // Initialize adjacency matrix
                    for (i = 0; i < 8; i = i + 1) begin
                        adj_matrix[i] <= 8'd0;
                    end
                    
                    // Build adjacency matrix (n_reg-1 edges)
                    for (i = 0; i < (n_reg - 1); i = i + 1) begin
                        adj_matrix[edge_u_reg[i]][edge_v_reg[i]] <= 1'b1;
                        adj_matrix[edge_v_reg[i]][edge_u_reg[i]] <= 1'b1;
                    end
                    
                    state <= COMP_DEGREES;
                end
                
                COMP_DEGREES: begin
                    // Compute degrees for each node
                    for (i = 0; i < 8; i = i + 1) begin
                        degree_reg[i] <= 4'd0;
                        for (j = 0; j < 8; j = j + 1) begin
                            if (adj_matrix[i][j] && (i < n_reg) && (j < n_reg)) begin
                                degree_reg[i] <= degree_reg[i] + 4'd1;
                            end
                        end
                    end
                    
                    state <= INIT_BFS;
                end
                
                INIT_BFS: begin
                    // Initialize BFS
                    front <= 3'd0;
                    rear <= 3'd1;
                    leaf_count <= 4'd0;
                    queue[0] <= h_reg;
                    visited <= 8'd0;
                    visited[h_reg] <= 1'b1;
                    
                    for (i = 0; i < 8; i = i + 1) begin
                        leaves[i] <= 3'd0;
                    end
                    
                    state <= BFS_RUN;
                end
                
                BFS_RUN: begin
                    if (front < rear) begin
                        // Dequeue
                        reg [2:0] current_node = queue[front];
                        front <= front + 3'd1;
                        
                        // Check if leaf
                        if (degree_reg[current_node] == 4'd1) begin
                            leaves[leaf_count] <= current_node;
                            leaf_count <= leaf_count + 4'd1;
                        end
                        
                        // Scan all possible neighbors
                        for (j = 0; j < 8; j = j + 1) begin
                            if ((j < n_reg) && adj_matrix[current_node][j] && !visited[j]) begin
                                visited[j] <= 1'b1;
                                queue[rear] <= j;
                                rear <= rear + 3'd1;
                            end
                        end
                    end else begin
                        // BFS complete
                        L <= leaf_count;
                        state <= COMPUTE_M;
                    end
                end
                
                COMPUTE_M: begin
                    // Handle edge cases
                    if (n_reg < 4'd2) begin
                        m <= 3'd0;
                        state <= DONE_STATE;
                    end else begin
                        m <= (L + 4'd1) >> 1; // ceil(L/2)
                        state <= GEN_EDGES;
                    end
                end
                
                GEN_EDGES: begin
                    // Generate added edges based on leaf count
                    for (k = 0; k < 4; k = k + 1) begin
                        added_u[k] <= 3'd0;
                        added_v[k] <= 3'd0;
                    end
                    
                    if (L >= 4'd1) begin
                        for (k = 0; k < m; k = k + 1) begin
                            if ((2*k + 1) < L) begin
                                added_u[k] <= leaves[2*k];
                                added_v[k] <= leaves[2*k + 1];
                            end else begin
                                added_u[k] <= leaves[2*k];
                                added_v[k] <= leaves[0];
                            end
                        end
                    end
                    
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule