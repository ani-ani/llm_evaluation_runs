module SecureNetwork (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] p,
    input [31:0] insecure_list,
    input [63:0] edge_u,
    input [63:0] edge_v,
    input [255:0] edge_cost,
    input [15:0] edge_valid,
    output reg [15:0] result,
    output reg done,
    output reg impossible
);

    // State declarations
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] CHECK_SPECIAL = 4'd1;
    localparam [3:0] FIND_MIN      = 4'd2;
    localparam [3:0] BUILD_MST     = 4'd3;
    localparam [3:0] COMPUTE       = 4'd4;
    localparam [3:0] DONE_STATE    = 4'd5;

    reg [3:0] state, next_state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Internal registers
    reg [3:0] secure_count;
    reg [3:0] insecure_count;
    reg [3:0] current_insecure;
    reg [3:0] current_edge;
    reg [3:0] min_edge_index;
    reg [15:0] min_edge_cost;
    reg [3:0] parent [0:7];
    reg [3:0] rank [0:7];
    reg [15:0] total_cost;
    reg [15:0] edge_cost_reg [0:15];
    reg [3:0] edge_u_reg [0:15];
    reg [3:0] edge_v_reg [0:15];
    reg [15:0] edge_valid_reg;
    reg [3:0] secure_nodes [0:7];
    reg [3:0] insecure_nodes [0:7];
    reg [3:0] temp_parent;
    reg [3:0] temp_rank;
    reg [3:0] i, j, k;
    reg found;
    reg edge_found;
    reg mst_complete;
    reg all_secure_connected;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 10'd0;
            secure_count <= 4'd0;
            insecure_count <= 4'd0;
            current_insecure <= 4'd0;
            current_edge <= 4'd0;
            min_edge_index <= 4'd0;
            min_edge_cost <= 16'd0;
            total_cost <= 16'd0;
            edge_valid_reg <= 16'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            result <= 16'd0;
            for (i = 0; i < 8; i = i + 1) begin
                parent[i] <= 4'd0;
                rank[i] <= 4'd0;
                secure_nodes[i] <= 4'd0;
                insecure_nodes[i] <= 4'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                edge_cost_reg[i] <= 16'd0;
                edge_u_reg[i] <= 4'd0;
                edge_v_reg[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                impossible <= 1'b0;
                result <= 16'd0;
                cycle_count = 10'd0;
                if (start) begin
                    next_state = CHECK_SPECIAL;
                end
            end

            CHECK_SPECIAL: begin
                // Initialize counts and node lists
                secure_count = n - p;
                insecure_count = p;
                
                // Extract insecure nodes
                for (i = 0; i < 8; i = i + 1) begin
                    if (i < p) begin
                        insecure_nodes[i] = insecure_list[i*4 +: 4];
                    end else begin
                        insecure_nodes[i] = 4'd0;
                    end
                end
                
                // Extract secure nodes
                j = 0;
                for (i = 0; i < 8; i = i + 1) begin
                    found = 1'b0;
                    for (k = 0; k < p; k = k + 1) begin
                        if (i == insecure_nodes[k]) begin
                            found = 1'b1;
                        end
                    end
                    if (!found && j < secure_count) begin
                        secure_nodes[j] = i;
                        j = j + 1;
                    end
                end
                
                // Load edges
                edge_valid_reg = edge_valid;
                for (i = 0; i < 16; i = i + 1) begin
                    edge_u_reg[i] = edge_u[i*4 +: 4];
                    edge_v_reg[i] = edge_v[i*4 +: 4];
                    edge_cost_reg[i] = edge_cost[i*16 +: 16];
                end
                
                // Case 1: p == n
                if (p == n) begin
                    if (n == 1) begin
                        total_cost = 16'd0;
                        next_state = DONE_STATE;
                    end else if (n == 2) begin
                        // Find edge between the two nodes
                        edge_found = 1'b0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (edge_valid_reg[i] && 
                                ((edge_u_reg[i] == insecure_nodes[0] && edge_v_reg[i] == insecure_nodes[1]) ||
                                 (edge_u_reg[i] == insecure_nodes[1] && edge_v_reg[i] == insecure_nodes[0]))) begin
                                total_cost = edge_cost_reg[i];
                                edge_found = 1'b1;
                            end
                        end
                        if (!edge_found) begin
                            impossible = 1'b1;
                        end
                        next_state = DONE_STATE;
                    end else begin
                        impossible = 1'b1;
                        next_state = DONE_STATE;
                    end
                end
                // Case 2: p == 0 (standard MST)
                else if (p == 0) begin
                    // Initialize union-find
                    for (i = 0; i < n; i = i + 1) begin
                        parent[i] = i;
                        rank[i] = 4'd0;
                    end
                    total_cost = 16'd0;
                    next_state = BUILD_MST;
                end
                // Case 3: 0 < p < n
                else begin
                    current_insecure = 4'd0;
                    next_state = FIND_MIN;
                end
            end

            FIND_MIN: begin
                // Find minimum edge from current insecure node to any secure node
                min_edge_cost = 16'd65535;
                min_edge_index = 4'd16;
                edge_found = 1'b0;
                
                for (i = 0; i < 16; i = i + 1) begin
                    if (edge_valid_reg[i]) begin
                        if ((edge_u_reg[i] == insecure_nodes[current_insecure] || 
                             edge_v_reg[i] == insecure_nodes[current_insecure]) &&
                            (edge_u_reg[i] != insecure_nodes[current_insecure] || 
                             edge_v_reg[i] != insecure_nodes[current_insecure])) begin
                            // Check if the other node is secure
                            temp_parent = (edge_u_reg[i] == insecure_nodes[current_insecure]) ? edge_v_reg[i] : edge_u_reg[i];
                            found = 1'b0;
                            for (k = 0; k < secure_count; k = k + 1) begin
                                if (temp_parent == secure_nodes[k]) begin
                                    found = 1'b1;
                                end
                            end
                            if (found && edge_cost_reg[i] < min_edge_cost) begin
                                min_edge_cost = edge_cost_reg[i];
                                min_edge_index = i;
                                edge_found = 1'b1;
                            end
                        end
                    end
                end
                
                if (edge_found) begin
                    total_cost = total_cost + min_edge_cost;
                    current_insecure = current_insecure + 4'd1;
                    if (current_insecure == p) begin
                        // Initialize union-find for secure nodes
                        for (i = 0; i < secure_count; i = i + 1) begin
                            parent[i] = secure_nodes[i];
                            rank[i] = 4'd0;
                        end
                        next_state = BUILD_MST;
                    end
                end else begin
                    impossible = 1'b1;
                    next_state = DONE_STATE;
                end
            end

            BUILD_MST: begin
                // Kruskal's algorithm using union-find
                mst_complete = 1'b1;
                for (i = 0; i < 16; i = i + 1) begin
                    if (edge_valid_reg[i]) begin
                        // Check if both nodes are secure
                        found = 1'b0;
                        for (k = 0; k < secure_count; k = k + 1) begin
                            if (edge_u_reg[i] == secure_nodes[k] || edge_v_reg[i] == secure_nodes[k]) begin
                                found = 1'b1;
                            end
                        end
                        if (found) begin
                            // Find roots
                            temp_parent = edge_u_reg[i];
                            while (parent[temp_parent] != temp_parent) begin
                                temp_parent = parent[temp_parent];
                            end
                            temp_rank = edge_v_reg[i];
                            while (parent[temp_rank] != temp_rank) begin
                                temp_rank = parent[temp_rank];
                            end
                            
                            // Union if different roots
                            if (temp_parent != temp_rank) begin
                                if (rank[temp_parent] < rank[temp_rank]) begin
                                    parent[temp_parent] = temp_rank;
                                end else if (rank[temp_parent] > rank[temp_rank]) begin
                                    parent[temp_rank] = temp_parent;
                                end else begin
                                    parent[temp_rank] = temp_parent;
                                    rank[temp_parent] = rank[temp_parent] + 4'd1;
                                end
                                total_cost = total_cost + edge_cost_reg[i];
                                edge_valid_reg[i] = 1'b0;
                                mst_complete = 1'b0;
                            end
                        end
                    end
                end
                
                if (mst_complete) begin
                    // Check if all secure nodes are connected
                    all_secure_connected = 1'b1;
                    temp_parent = secure_nodes[0];
                    while (parent[temp_parent] != temp_parent) begin
                        temp_parent = parent[temp_parent];
                    end
                    for (i = 1; i < secure_count; i = i + 1) begin
                        temp_rank = secure_nodes[i];
                        while (parent[temp_rank] != temp_rank) begin
                            temp_rank = parent[temp_rank];
                        end
                        if (temp_rank != temp_parent) begin
                            all_secure_connected = 1'b0;
                        end
                    end
                    
                    if (!all_secure_connected) begin
                        impossible = 1'b1;
                    end
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                result <= total_cost;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule