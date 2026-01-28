module cave_nav (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] A,
    input wire [15:0] H,
    input wire [4:0] n,
    input wire [4:0] m,
    input wire [64:0] edges [0:31], // Packed: {src[4:0], dst[4:0], enemy_a[15:0], enemy_h[15:0]} = 5+5+16+16 = 42 bits. Use 65 for safety
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] SEARCH     = 3'd1;
    localparam [2:0] CALC_DMG   = 3'd2;
    localparam [2:0] UPDATE_BEST= 3'd3;
    localparam [2:0] BACKTRACK  = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    
    // Graph traversal registers
    reg [4:0] curr_node; // Current node in path
    reg [4:0] next_node;
    reg [3:0] path_depth; // 0 to 15
    reg [15:0] stack_nodes [0:15]; // Stack for path nodes
    reg [15:0] stack_health [0:15]; // Stack for health at each node
    
    // Edge selection
    reg [4:0] edge_idx;
    reg [4:0] edge_limit;
    reg edge_found;
    
    // Combat calculation
    reg [15:0] curr_edge_a;
    reg [15:0] curr_edge_h;
    wire [15:0] hits_to_kill;
    wire [15:0] damage;
    wire [31:0] damage_32;
    
    // Results
    reg [15:0] best_health;
    reg [15:0] curr_health;
    
    // Loop counters
    integer i;
    
    // Cycle counter for timeout
    reg [13:0] cycle_count; // Max 10,000 cycles
    localparam [13:0] MAX_CYCLES = 14'd10000;

    // --- Combinatorial Logic for Combat Math ---
    // hits_to_kill = ceil(enemy_h / A) = (enemy_h + A - 1) / A
    wire [15:0] numerator;
    wire [15:0] denominator;
    assign numerator = curr_edge_h + A - 16'd1;
    assign denominator = A;
    
    // Integer division for 16-bit
    // Since synthesis tools might not support division well, we implement manual or use behavior.
    // Verilog behavior division is generally synthesizable for constants/small logic.
    assign hits_to_kill = (denominator == 16'd0) ? 16'd0 : (numerator / denominator);
    
    // damage = (hits_to_kill - 1) * enemy_a
    // Check if hits_to_kill > 0
    wire [31:0] dmg_mult;
    assign dmg_mult = (hits_to_kill > 16'd0) ? (hits_to_kill - 16'd1) * curr_edge_a : 32'd0;
    
    // Clamp damage to 16-bit max or keep 32-bit for comparison
    // If damage > 16'hFFFF, it will definitely kill Unnar.
    // We use 32-bit logic for comparison.
    assign damage_32 = dmg_mult;
    
    // --- Sequential Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            best_health <= 16'd0;
            cycle_count <= 14'd0;
            path_depth <= 4'd0;
            edge_idx <= 5'd0;
            // Initialize stacks (required for Icarus Verilog)
            for (i = 0; i < 16; i = i + 1) begin
                stack_nodes[i] <= 16'd0;
                stack_health[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 14'd0;
                    best_health <= 16'd0;
                    if (start) begin
                        // Initialize start state
                        // Assuming node 1 is start. (Nodes are 1-indexed based on description)
                        // User description says Unnar starts at node 1, target is node n.
                        // We need to be careful with 0 vs 1 based indexing for edges.
                        // Assuming edges have src/dst as 0..n-1 or 1..n.
                        // Given node count is 'n' (max 16), typically indices 1..n.
                        // Let's assume edges use indices 1..n for now, 
                        // but we might need to support 0..n-1 if testbench uses standard 0-index.
                        // Given 'n' is count, and 'max nodes is 16', usually 0-based for hardware.
                        // However, prompt says "Unnar starts at node 1". 
                        // Let's verify: If n=16, nodes 0..15? Or 1..16?
                        // If "target is node n", and n is 5-bit, likely 1..n.
                        // We will treat nodes as 1..n (inclusive).
                        
                        // However, to be safe against 0-based testbenches, we must handle both.
                        // A common trick: Start at 1. If n=1, path is trivial.
                        
                        path_depth <= 4'd0;
                        stack_nodes[0] <= 16'd1; // Start at node 1
                        stack_health[0] <= H;    // Start with health H
                        curr_health <= H;
                        
                        // Prepare to search from node 1
                        curr_node <= 16'd1;
                        edge_idx <= 5'd0;
                    end
                end
                
                SEARCH: begin
                    // Find next valid edge
                    // Logic: Iterate through all edges (up to 32).
                    // Check if edge.src == curr_node
                    // Check if dst is NOT in current path stack (cycle prevention)
                    // We do this cycle by cycle or combinatorially.
                    // Given max 32 edges, we can iterate here.
                    // We need a flag to know if we found a valid edge.
                    
                    // This state logic is complex. 
                    // Instead of doing loop in one cycle, we use `edge_idx` to track progress.
                end
                
                CALC_DMG: begin
                    // Calculated in next state logic or wires
                    // Check validity: if curr_health - damage < 1, path invalid.
                    // Update curr_health = curr_health - damage (clamped)
                    
                    // Check if path is still valid
                    if (curr_health <= 16'd0) begin
                        // Should be caught by damage check, but safety
                        state <= BACKTRACK;
                    end else begin
                        state <= UPDATE_BEST;
                    end
                end
                
                UPDATE_BEST: begin
                    // Push to stack or update best
                    // If dst == n, update best_health
                    // Else, continue DFS
                end
                
                BACKTRACK: begin
                    // Pop stack
                    // If stack empty (depth 0), go to DONE
                    // Else, resume search from previous node
                end
                
                DONE_STATE: begin
                    result <= best_health;
                    done <= 1'b1;
                end
            endcase
            
            // Timeout check
            if (start) cycle_count <= 14'd1;
            else if (state != IDLE && state != DONE_STATE) begin
                if (cycle_count < MAX_CYCLES) cycle_count <= cycle_count + 14'd1;
                else state <= DONE_STATE; // Force finish on timeout
            end
        end
    end

    // --- Next State Logic and Datapath ---
    // We need to extract edge info combinatorially for the selected edge
    wire [4:0] edge_src;
    wire [4:0] edge_dst;
    wire [15:0] edge_ea;
    wire [15:0] edge_eh;
    
    assign edge_src = edges[edge_idx][47:43]; // Assuming packed: {src[4:0], dst[4:0], ea[15:0], eh[15:0]}
    assign edge_dst = edges[edge_idx][42:38];
    assign edge_ea  = edges[edge_idx][37:22];
    assign edge_eh  = edges[edge_idx][21:6];
    
    // Cycle prevention check: Is dst in stack_nodes?
    reg dst_in_path;
    integer j;
    always @(*) begin
        dst_in_path = 1'b0;
        for (j = 0; j < 16; j = j + 1) begin
            if (j < path_depth && stack_nodes[j] == edge_dst) begin
                dst_in_path = 1'b1;
            end
        end
    end

    // Edge search validity
    wire is_valid_edge;
    assign is_valid_edge = (edge_src == curr_node) && 
                           (edge_dst != curr_node) && 
                           (edge_dst >= 1 && edge_dst <= n) && // Bounds check
                           !dst_in_path;

    // Main FSM logic
    always @(*) begin
        next_state = state; // Default stay
        
        case (state)
            IDLE: begin
                if (start) begin
                    if (n == 1) begin
                        // Start and end are same (or trivial)
                        next_state = DONE_STATE;
                    end else begin
                        next_state = SEARCH;
                    end
                end
            end
            
            SEARCH: begin
                // Look for edge
                if (edge_idx < 32 && edge_idx < m) begin
                    if (is_valid_edge) begin
                        // Found valid edge
                        next_state = CALC_DMG;
                    end else begin
                        // Check next edge
                        next_state = SEARCH; // Stay, advance idx in combinational logic or here?
                    end
                end else begin
                    // No more edges found from current node
                    next_state = BACKTRACK;
                end
            end
            
            CALC_DMG: begin
                // Compute damage using comb logic wires
                // Check if health drops below 1
                // damage_32 is 32-bit, curr_health is 16-bit
                // If curr_health <= damage_32 (or damage_32 > 16'hFFFF), it's dead.
                // Actually, condition is: if (curr_health - damage < 1)
                // Which is: curr_health <= damage
                
                if (curr_health <= damage_32[15:0] && damage_32 < 32'h10000) begin
                    // Path invalid (dies)
                    next_state = BACKTRACK;
                end else if (damage_32 >= 32'h10000) begin
                    // Massive damage, dies for sure
                    next_state = BACKTRACK;
                end else begin
                    // Path valid, proceed to update
                    next_state = UPDATE_BEST;
                end
            end
            
            UPDATE_BEST: begin
                // Check if target reached
                if (edges[edge_idx][42:38] == n) begin // Check dst == n
                    // Target found. Update best if current health is better.
                    // Note: current health is after taking damage.
                    // If we just arrived at n, we check health.
                    next_state = BACKTRACK; // Continue searching other paths from this node
                end else begin
                    // Go deeper
                    next_state = SEARCH; // Will push in combinational logic?
                    // Actually, we need to set up for next depth.
                    // Set curr_node to dst, reset edge_idx.
                    // This is usually done in the combinational block driving the registers.
                end
            end
            
            BACKTRACK: begin
                // Pop stack
                if (path_depth == 4'd0) begin
                    // Finished searching all paths
                    next_state = DONE_STATE;
                end else begin
                    // Resume search from previous node
                    next_state = SEARCH;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE; // Stay here until reset or start
            end
            
            default: next_state = IDLE;
        endcase
    end

    // --- Datapath Update Logic (Sequencing) ---
    // We need to handle edge_idx increment, stack push/pop, health update
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // handled above
        end else begin
            // Logic specific to state transitions
            
            // SEARCH logic: Advance edge_idx
            if (state == SEARCH && next_state == SEARCH) begin
                edge_idx <= edge_idx + 5'd1;
            end
            if (state == SEARCH && next_state == CALC_DMG) begin
                // Capture edge data
                curr_edge_a <= edge_ea;
                curr_edge_h <= edge_eh;
                next_node <= edge_dst;
            end
            
            // UPDATE_BEST Logic
            if (state == CALC_DMG && next_state == UPDATE_BEST) begin
                // Update health for next node
                // damage_32 is guaranteed < 65536 here due to check
                curr_health <= curr_health - damage_32[15:0];
            end
            
            if (state == UPDATE_BEST) begin
                if (next_node == n) begin
                    // Reached target
                    if ((curr_health - damage_32[15:0]) > best_health) begin
                        best_health <= curr_health - damage_32[15:0];
                    end
                end
            end
            
            // PUSH Logic (when going deeper)
            // This happens when we transition from SEARCH/UPDATE_BEST to deeper search
            // We push when we are about to process a new node (dst) as curr_node
            if ((state == SEARCH && next_state == CALC_DMG) || 
                (state == UPDATE_BEST && next_state == SEARCH)) begin
                // Only push if we are NOT at target (we stop searching at target)
                // In UPDATE_BEST, if dst == n, we go to BACKTRACK, not SEARCH.
                // So this branch implies dst != n.
                
                stack_nodes[path_depth] <= curr_node;
                stack_health[path_depth] <= curr_health;
                path_depth <= path_depth + 4'd1;
                
                // Move to next node
                curr_node <= next_node;
                edge_idx <= 5'd0;
            end
            
            // POP Logic (Backtrack)
            if (state == BACKTRACK && next_state == SEARCH) begin
                path_depth <= path_depth - 4'd1;
                curr_node <= stack_nodes[path_depth - 1];
                curr_health <= stack_health[path_depth - 1];
                edge_idx <= 5'd0;
            end
            
            // Reset edge_idx when returning to idle or done
            if (state == BACKTRACK && next_state == DONE_STATE) begin
                edge_idx <= 5'd0;
            end
            if (state == DONE_STATE && next_state == IDLE) begin
                edge_idx <= 5'd0;
                path_depth <= 4'd0;
            end
        end
    end

endmodule