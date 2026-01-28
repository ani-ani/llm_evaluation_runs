module RankingModule (
    input clk,
    input rst_n,
    input start,
    input [255:0] adj,
    input [15:0] S_mask,
    input [3:0] k,
    output reg [3:0] result,
    output reg found,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD       = 3'd1;
    localparam [2:0] CHECK_SIZE = 3'd2;
    localparam [2:0] GEN_COMBO  = 3'd3;
    localparam [2:0] KAHNS      = 3'd4;
    localparam [2:0] VALID_FIND = 3'd5;
    localparam [2:0] FINISH     = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [255:0] adj_reg;
    reg [15:0] S_reg;
    reg [3:0] k_reg;
    
    // Iteration control
    reg [3:0] search_size;           // Current S' size being checked (0 to k-1)
    reg [15:0] current_combo;        // Current combination mask
    reg [15:0] combo_counter;        // Counter for generating combinations
    reg [3:0] popcount;              // Popcount of current_combo
    reg [3:0] required_popcount;     // Target popcount for current size
    
    // Kahn's algorithm internals
    reg [15:0] active_nodes;         // Nodes in R (active)
    reg [15:0] in_degree [0:15];     // In-degrees for each node (wires only)
    reg [15:0] zero_queue;           // Queue of nodes with 0 in-degree
    reg [3:0] queue_head;            // Pointer for queue processing
    reg [3:0] processed_count;       // Count of removed nodes
    reg [15:0] temp_in_degree [0:15]; // Working copy of in-degrees
    
    // Wires for combinational logic
    wire [3:0] popcount_w;
    wire [3:0] active_count_w;
    
    // Helper: Popcount of 16-bit number
    function automatic [3:0] popcount16;
        input [15:0] val;
        integer i;
        reg [3:0] count;
        begin
            count = 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                if (val[i]) count = count + 4'd1;
            end
            popcount16 = count;
        end
    endfunction
    
    // Combinational signals
    assign popcount_w = popcount16(current_combo);
    assign active_count_w = popcount16(~S_reg & ~current_combo);
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            adj_reg <= 256'd0;
            S_reg <= 16'd0;
            k_reg <= 4'd0;
            search_size <= 4'd0;
            current_combo <= 16'd0;
            combo_counter <= 16'd0;
            required_popcount <= 4'd0;
            zero_queue <= 16'd0;
            queue_head <= 4'd0;
            processed_count <= 4'd0;
            result <= 4'd0;
            found <= 1'b0;
            done <= 1'b0;
            // Initialize temp_in_degree array
            temp_in_degree[0] <= 16'd0; temp_in_degree[1] <= 16'd0;
            temp_in_degree[2] <= 16'd0; temp_in_degree[3] <= 16'd0;
            temp_in_degree[4] <= 16'd0; temp_in_degree[5] <= 16'd0;
            temp_in_degree[6] <= 16'd0; temp_in_degree[7] <= 16'd0;
            temp_in_degree[8] <= 16'd0; temp_in_degree[9] <= 16'd0;
            temp_in_degree[10] <= 16'd0; temp_in_degree[11] <= 16'd0;
            temp_in_degree[12] <= 16'd0; temp_in_degree[13] <= 16'd0;
            temp_in_degree[14] <= 16'd0; temp_in_degree[15] <= 16'd0;
            active_nodes <= 16'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    result <= 4'd0;
                end
                LOAD: begin
                    adj_reg <= adj;
                    S_reg <= S_mask;
                    k_reg <= k;
                    search_size <= 4'd0;
                    // If k==0, skip directly to finish (impossible since k>=2)
                end
                CHECK_SIZE: begin
                    // Prepare for combo generation
                    combo_counter <= 16'd0;
                    required_popcount <= search_size;
                    current_combo <= 16'd0;
                end
                GEN_COMBO: begin
                    // Generate next combination with correct popcount
                    if (popcount_w == required_popcount) begin
                        current_combo <= current_combo; // Keep valid combo
                    end else begin
                        current_combo <= current_combo + 16'd1;
                    end
                end
                KAHNS: begin
                    // Initialize Kahn's state for current combo
                    active_nodes <= ~S_reg & ~current_combo;
                    zero_queue <= 16'd0;
                    queue_head <= 4'd0;
                    processed_count <= 4'd0;
                    // Initialize temp_in_degree and zero_queue
                    temp_in_degree[0] <= (active_nodes[0] && adj_reg[0*16 + 0]) ? 16'd1 : 16'd0; // Self-loop check
                    // Actually, in-degree calc needs edges from other active nodes
                    // Combinational calc handled below
                end
                VALID_FIND: begin
                    // Found valid S'
                    result <= search_size;
                    found <= 1'b1;
                    done <= 1'b1;
                end
                FINISH: begin
                    if (!found) begin
                        result <= 4'd15; // Impossible code
                        found <= 1'b0;
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                // Check if S' size 0 is valid immediately (size < k check)
                if (k_reg == 4'd0) next_state = FINISH; // Should not happen per spec
                else next_state = CHECK_SIZE;
            end
            CHECK_SIZE: begin
                if (search_size >= k_reg) begin
                    next_state = FINISH;
                end else begin
                    next_state = GEN_COMBO;
                end
            end
            GEN_COMBO: begin
                // Check if popcount matches target
                if (popcount_w == required_popcount) begin
                    // Valid combo, proceed to check
                    next_state = KAHNS;
                end else begin
                    // Try next mask
                    if (combo_counter == 16'hFFFF) begin
                        // Exhausted all masks for this size
                        next_state = CHECK_SIZE;
                    end else begin
                        combo_counter = combo_counter + 16'd1;
                        next_state = GEN_COMBO;
                    end
                end
            end
            KAHNS: begin
                // Kahn's algorithm runs for fixed number of cycles (16)
                // We use a separate counter or state to iterate steps
                // For simplicity, we'll jump to VALID_FIND or CHECK_SIZE
                // depending on result of Kahn's (combinational check)
                // Since combinational logic is ready by next cycle:
                // If valid (acyclic), go to VALID_FIND
                // Else go to GEN_COMBO to get next combo
                // Note: We need to ensure Kahn's logic has completed.
                // We'll add a tiny delay by staying here 1 cycle if needed,
                // but best is to compute in combinational block.
                // Let's assume combinational result is ready.
                // Valid condition: processed_count == active_count_w (and queue emptied correctly)
                // We need a flag from combinational logic.
                next_state = GEN_COMBO; // Default: try next combo
                if (kahn_is_acyclic) begin
                    next_state = VALID_FIND;
                end else if (combo_counter == 16'hFFFF) begin
                    // Last combo for this size failed
                    next_state = CHECK_SIZE;
                end
            end
            VALID_FIND: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE; // Remain here until reset or start
            end
        endcase
        
        // Override: if in GEN_COMBO and popcount matches but mask is invalid (not in U)
        // We need to skip masks that include bits in S_reg (since S' must be disjoint from S)
        // The problem says "excluding any in the original set S".
        // So S_prime_mask & S_mask must be 0.
        // We'll handle this in GEN_COMBO logic.
    end
    
    // Combinational Logic for Kahn's Algorithm and Validity Check
    reg kahn_is_acyclic;
    integer i, j;
    reg [15:0] calc_active;
    reg [15:0] calc_in_degree [0:15];
    reg [15:0] calc_zero_q;
    reg [3:0] calc_head;
    reg [3:0] calc_processed;
    reg valid_flag;
    
    always @(*) begin
        // 1. Calculate Active Nodes and In-Degrees
        calc_active = ~S_reg & ~current_combo;
        
        // Initialize in-degrees
        for (i = 0; i < 16; i = i + 1) begin
            calc_in_degree[i] = 16'd0;
        end
        
        // Count in-degrees based on adj matrix
        // adj is packed: adj[i*16 + j] is 1 if i beats j
        // We only count edges where both i and j are active
        for (i = 0; i < 16; i = i + 1) begin
            if (calc_active[i]) begin
                for (j = 0; j < 16; j = j + 1) begin
                    if (calc_active[j] && adj_reg[i*16 + j]) begin
                        // Edge i -> j exists. Increment in-degree of j
                        // We need to add 1 to calc_in_degree[j]
                        // Since Verilog doesn't allow loops in combinational blocks easily for array updates,
                        // we will use a generate block or inline logic.
                        // For synthesis, unrolled logic is best.
                        // However, we are inside an always block. 
                        // We will assume we can update calc_in_degree[j] sequentially.
                        // Note: The inner loop overwrites j if i increments, so we must accumulate.
                        // Actually, standard way: calc_in_degree[j] = calc_in_degree[j] + (edge_exists ? 1 : 0);
                        // Since we are inside loops, we can do:
                    end
                end
            end
        end
        
        // Re-implement loop structure for Verilog compatibility
        // Reset calc_in_degree
        calc_in_degree[0] = 16'd0; calc_in_degree[1] = 16'd0;
        calc_in_degree[2] = 16'd0; calc_in_degree[3] = 16'd0;
        calc_in_degree[4] = 16'd0; calc_in_degree[5] = 16'd0;
        calc_in_degree[6] = 16'd0; calc_in_degree[7] = 16'd0;
        calc_in_degree[8] = 16'd0; calc_in_degree[9] = 16'd0;
        calc_in_degree[10] = 16'd0; calc_in_degree[11] = 16'd0;
        calc_in_degree[12] = 16'd0; calc_in_degree[13] = 16'd0;
        calc_in_degree[14] = 16'd0; calc_in_degree[15] = 16'd0;
        
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                if (calc_active[j] && calc_active[i] && adj_reg[i*16 + j]) begin
                    calc_in_degree[j] = calc_in_degree[j] + 16'd1;
                end
            end
        end
        
        // 2. Run Kahn's Algorithm
        calc_zero_q = 16'd0;
        calc_head = 4'd0;
        calc_processed = 4'd0;
        
        // Find initial zeros
        for (i = 0; i < 16; i = i + 1) begin
            if (calc_active[i] && calc_in_degree[i] == 16'd0) begin
                calc_zero_q = calc_zero_q | (16'd1 << i);
            end
        end
        
        // Process queue (simulated for 16 cycles max)
        // Since we are in combinational block, we can loop
        // But we need to simulate the popping.
        // We will use a 'processed' mask to track removed nodes
        reg [15:0] processed_mask;
        processed_mask = 16'd0;
        
        // Loop 16 times (max nodes)
        for (i = 0; i < 16; i = i + 1) begin
            // Find a node in calc_zero_q that is not processed
            reg found_zero;
            found_zero = 1'b0;
            integer u;
            u = 0;
            while (u < 16 && !found_zero) begin
                if (calc_zero_q[u] && !processed_mask[u]) begin
                    found_zero = 1'b1;
                    processed_mask[u] = 1'b1;
                    calc_processed = calc_processed + 4'd1;
                    // Update neighbors
                    for (j = 0; j < 16; j = j + 1) begin
                        if (calc_active[j] && adj_reg[u*16 + j]) begin
                            calc_in_degree[j] = calc_in_degree[j] - 16'd1;
                            if (calc_in_degree[j] == 16'd0 && !processed_mask[j]) begin
                                calc_zero_q[j] = 1'b1;
                            end
                        end
                    end
                end
                u = u + 1;
            end
            if (!found_zero) begin
                // No more nodes to process, break
                // break; // Not supported in Icarus
                // We use a flag or just exit loop logic naturally
                // Since loop runs fixed times, we just skip updates
                // To force break effect, we can set i to 16
                // But Verilog doesn't allow loop control modification.
                // We just rely on no 'found_zero' meaning no progress.
            end
        end
        
        // Check if acyclic
        // valid if processed_count == active_count
        kahn_is_acyclic = (calc_processed == active_count_w);
    end

    // Correction for GEN_COMBO logic to skip invalid masks (overlapping with S)
    // We need to ensure we don't pick bits that are already in S_reg
    // We can do this by modifying the counter logic or skipping.
    // Since we can't easily skip in combinational logic loops, we'll rely on the check:
    // If (current_combo & S_reg) != 0, treat as invalid and force next state to GEN_COMBO.
    
    // Revised Next State Logic block to handle the skip
    always @(*) begin
        // Default next state logic from previous block is kept, 
        // but we add the overlap check here.
        
        // Re-evaluate next_state based on overlap
        if (state == GEN_COMBO && (current_combo & S_reg) != 16'd0) begin
            // Overlap with S, invalid S'. Treat as failure for this mask.
            // Move to next mask.
            if (combo_counter == 16'hFFFF) begin
                next_state = CHECK_SIZE;
            end else begin
                next_state = GEN_COMBO;
            end
        end
    end

endmodule