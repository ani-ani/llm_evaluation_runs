module MaxMinReach (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    input wire [3:0] m_in,
    input wire [3:0] s_in,
    input wire [15:0] edge_type,
    input wire [63:0] edge_u,
    input wire [63:0] edge_v,
    output reg [4:0] max_reach,
    output reg [4:0] min_reach,
    output reg [15:0] max_orient,
    output reg [15:0] min_orient,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE           = 4'd0;
    localparam [3:0] LATCH_INPUTS   = 4'd1;
    localparam [3:0] MAX_INIT       = 4'd2;
    localparam [3:0] MAX_BFS        = 4'd3;
    localparam [3:0] MAX_PROCESS    = 4'd4;
    localparam [3:0] MAX_UPDATE     = 4'd5;
    localparam [3:0] MIN_INIT       = 4'd6;
    localparam [3:0] MIN_BFS        = 4'd7;
    localparam [3:0] MIN_PROCESS    = 4'd8;
    localparam [3:0] MIN_UPDATE     = 4'd9;
    localparam [3:0] DONE           = 4'd10;

    // FSM registers
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Input latching
    reg [3:0] n_reg;
    reg [3:0] m_reg;
    reg [3:0] s_reg;
    reg [15:0] et_reg;
    reg [63:0] eu_reg;
    reg [63:0] ev_reg;
    
    // BFS/DFS registers
    reg [15:0] visited;
    reg [15:0] next_visited;
    reg [15:0] queue;
    reg [15:0] next_queue;
    reg [15:0] temp_queue;
    reg [4:0] visit_count;
    reg [4:0] next_visit_count;
    reg [3:0] edge_idx;
    reg [3:0] node_idx;
    reg [3:0] u, v;
    reg edge_found;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd30;
    
    // Orientation tracking
    reg [15:0] current_orient;
    reg [15:0] next_current_orient;
    
    // Registers for final outputs
    reg [15:0] max_orient_reg;
    reg [15:0] min_orient_reg;
    
    // Edge lookup logic (combinational)
    reg [3:0] lookup_u;
    reg [3:0] lookup_v;
    reg lookup_directed;
    
    always @(*) begin
        lookup_u = eu_reg[edge_idx*4 +: 4];
        lookup_v = ev_reg[edge_idx*4 +: 4];
        lookup_directed = et_reg[edge_idx];
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LATCH_INPUTS;
            end
            LATCH_INPUTS: begin
                next_state = MAX_INIT;
            end
            MAX_INIT: begin
                next_state = MAX_BFS;
            end
            MAX_BFS: begin
                if (queue == 16'd0) next_state = MAX_INIT; // Check if traversal done
                else next_state = MAX_PROCESS;
            end
            MAX_PROCESS: begin
                if (edge_found) next_state = MAX_UPDATE;
                else if (edge_idx >= m_reg) next_state = MAX_BFS;
                else next_state = MAX_PROCESS;
            end
            MAX_UPDATE: begin
                next_state = MAX_PROCESS;
            end
            MIN_INIT: begin
                next_state = MIN_BFS;
            end
            MIN_BFS: begin
                if (queue == 16'd0) next_state = MIN_INIT; // Check if traversal done
                else next_state = MIN_PROCESS;
            end
            MIN_PROCESS: begin
                if (edge_found) next_state = MIN_UPDATE;
                else if (edge_idx >= m_reg) next_state = MIN_BFS;
                else next_state = MIN_PROCESS;
            end
            MIN_UPDATE: begin
                next_state = MIN_PROCESS;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // State transition and logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_reach <= 5'd0;
            min_reach <= 5'd0;
            max_orient <= 16'd0;
            min_orient <= 16'd0;
            done <= 1'b0;
            n_reg <= 4'd0;
            m_reg <= 4'd0;
            s_reg <= 4'd0;
            et_reg <= 16'd0;
            eu_reg <= 64'd0;
            ev_reg <= 64'd0;
            visited <= 16'd0;
            queue <= 16'd0;
            visit_count <= 5'd0;
            edge_idx <= 4'd0;
            node_idx <= 4'd0;
            cycle_count <= 5'd0;
            current_orient <= 16'd0;
            max_orient_reg <= 16'd0;
            min_orient_reg <= 16'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    // Clear outputs when idle
                    max_reach <= 5'd0;
                    min_reach <= 5'd0;
                    max_orient <= 16'd0;
                    min_orient <= 16'd0;
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                end
                
                LATCH_INPUTS: begin
                    n_reg <= n_in;
                    m_reg <= m_in;
                    s_reg <= s_in;
                    et_reg <= edge_type;
                    eu_reg <= edge_u;
                    ev_reg <= edge_v;
                    cycle_count <= 5'd0;
                end
                
                // --- MAX PASS ---
                MAX_INIT: begin
                    // Initialize for Max BFS
                    visited <= 16'd0;
                    queue <= 16'd0;
                    current_orient <= 16'd0;
                    visit_count <= 5'd0;
                    if (n_reg > 4'd0) begin
                        visited[s_reg] <= 1'b1;
                        queue[s_reg] <= 1'b1;
                        visit_count <= 5'd1;
                    end
                end
                
                MAX_BFS: begin
                    edge_idx <= 4'd0;
                    cycle_count <= cycle_count + 5'd1;
                end
                
                MAX_PROCESS: begin
                    // Find next node in queue
                    if (queue != 16'd0) begin
                        // Find first set bit (simplified: sequential scan)
                        if (edge_idx == 4'd0) begin
                            node_idx <= 4'd0;
                            // Check if current node_idx is in queue
                            if (queue[node_idx]) begin
                                // Processing this node
                            end else begin
                                // Find next node
                                for (integer i = 0; i < 16; i = i + 1) begin
                                    if (queue[i] && i > node_idx) begin
                                        node_idx <= i;
                                    end
                                end
                            end
                        end
                    end
                    
                    edge_found <= 1'b0;
                    
                    if (edge_idx < m_reg) begin
                        // Check this edge
                        if (queue[node_idx] && (lookup_u == node_idx || lookup_v == node_idx)) begin
                            // Edge is incident to current node
                            integer target;
                            integer other;
                            
                            if (lookup_u == node_idx) begin
                                target = lookup_v;
                                other = lookup_u;
                            end else begin
                                target = lookup_u;
                                other = lookup_v;
                            end
                            
                            if (!visited[target]) begin
                                if (lookup_directed) begin
                                    // Directed: must be u->v
                                    if (lookup_u == node_idx && lookup_v == target) begin
                                        edge_found <= 1'b1;
                                    end
                                end else begin
                                    // Undirected: orient u->v
                                    edge_found <= 1'b1;
                                end
                            end
                        end
                    end
                end
                
                MAX_UPDATE: begin
                    // Update visited and queue
                    if (edge_found) begin
                        integer target;
                        if (lookup_u == node_idx) target = lookup_v;
                        else target = lookup_u;
                        
                        visited[target] <= 1'b1;
                        queue[target] <= 1'b1;
                        visit_count <= visit_count + 5'd1;
                        
                        // Set orientation
                        if (!lookup_directed) begin
                            // If traversing u->v, set '+' for edge_idx
                            current_orient[edge_idx] <= 1'b1;
                        end
                        
                        // Remove current node from queue if no more outgoing edges
                        // (Simplified: keep in queue, BFS handles duplicates by visited check)
                        if (edge_idx >= m_reg - 1) begin
                            queue[node_idx] <= 1'b0;
                        end
                    end
                    edge_idx <= edge_idx + 4'd1;
                end
                
                // --- MIN PASS ---
                MIN_INIT: begin
                    // Save Max results
                    max_reach <= visit_count;
                    max_orient <= current_orient;
                    max_orient_reg <= current_orient;
                    
                    // Initialize for Min BFS
                    visited <= 16'd0;
                    queue <= 16'd0;
                    current_orient <= 16'd0;
                    visit_count <= 5'd0;
                    
                    // Initial node s is always reachable
                    if (n_reg > 4'd0) begin
                        visited[s_reg] <= 1'b1;
                        queue[s_reg] <= 1'b1;
                        visit_count <= 5'd1;
                    end
                end
                
                MIN_BFS: begin
                    edge_idx <= 4'd0;
                    cycle_count <= cycle_count + 5'd1;
                end
                
                MIN_PROCESS: begin
                    edge_found <= 1'b0;
                    
                    // Find current node in queue
                    if (edge_idx == 4'd0) begin
                        for (integer j = 0; j < 16; j = j + 1) begin
                            if (queue[j]) node_idx <= j;
                        end
                    end
                    
                    if (edge_idx < m_reg) begin
                        // Check edges incident to node_idx
                        if (queue[node_idx]) begin
                            if ((lookup_u == node_idx) || (lookup_v == node_idx)) begin
                                integer target;
                                if (lookup_u == node_idx) target = lookup_v;
                                else target = lookup_u;
                                
                                if (!visited[target]) begin
                                    if (lookup_directed) begin
                                        // Directed: only if u->v
                                        if (lookup_u == node_idx) begin
                                            edge_found <= 1'b1;
                                        end
                                    end else begin
                                        // Undirected: orient u->v
                                        // Can traverse if we are u (and target is v)
                                        if (lookup_u == node_idx) begin
                                            edge_found <= 1'b1;
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                MIN_UPDATE: begin
                    if (edge_found) begin
                        integer target;
                        if (lookup_u == node_idx) target = lookup_v;
                        else target = lookup_u;
                        
                        visited[target] <= 1'b1;
                        queue[target] <= 1'b1;
                        visit_count <= visit_count + 5'd1;
                        
                        if (!lookup_directed) begin
                            current_orient[edge_idx] <= 1'b1;
                        end
                    end
                    edge_idx <= edge_idx + 4'd1;
                end
                
                DONE: begin
                    min_reach <= visit_count;
                    min_orient <= current_orient;
                    min_orient_reg <= current_orient;
                    done <= 1'b1;
                end
            endcase
            
            // Safety timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE) begin
                state <= DONE;
            end
        end
    end
endmodule