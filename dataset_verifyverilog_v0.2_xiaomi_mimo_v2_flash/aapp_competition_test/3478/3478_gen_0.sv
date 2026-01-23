module graph_partition(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [5:0] edges [15:0],
    output reg valid,
    output reg [3:0] arya_set,
    output reg [3:0] sansa_set,
    output reg done
);

    // State Encoding
    localparam IDLE           = 5'b00001;
    localparam SETUP_ADJ      = 5'b00010;
    localparam GEN_PERM       = 5'b00100;
    localparam CHECK_CLIQUE   = 5'b01000;
    localparam DONE_STATE     = 5'b10000;

    reg [4:0] state, next_state;

    // Adjacency Matrix (4x4)
    reg adj [3:0][3:0];
    reg adj_next [3:0][3:0];

    // Permutation Generator Registers
    reg [1:0] p0, p1, p2, p3; // 0=None, 1=A, 2=S, 3=J
    reg [1:0] p0_next, p1_next, p2_next, p3_next;
    reg valid_perm;

    // Clique Check Registers
    reg [3:0] set_mask;
    reg [3:0] u, v;
    reg [3:0] u_next, v_next;
    reg is_clique;
    reg is_clique_next;
    reg check_passed;
    reg check_passed_next;
    
    // Counters for loops
    reg [2:0] setup_cnt;
    reg [2:0] setup_cnt_next;
    reg [2:0] clique_cnt; // 0: check A, 1: check S, 2: check J
    reg [2:0] clique_cnt_next;

    // Loop counters for bit iteration
    reg [1:0] i_iter, j_iter;
    reg [1:0] i_iter_next, j_iter_next;

    // Helper task to update adj matrix
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            // Reset Adjacency Matrix
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    adj[i][j] <= 0;
                end
            end
            p0 <= 0; p1 <= 0; p2 <= 0; p3 <= 0;
            u <= 0; v <= 0;
            is_clique <= 0;
            check_passed <= 0;
            setup_cnt <= 0;
            clique_cnt <= 0;
            i_iter <= 0; j_iter <= 0;
        end else begin
            state <= next_state;
            
            // Update Registers
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    adj[i][j] <= adj_next[i][j];
                end
            end
            
            p0 <= p0_next;
            p1 <= p1_next;
            p2 <= p2_next;
            p3 <= p3_next;
            
            u <= u_next;
            v <= v_next;
            is_clique <= is_clique_next;
            check_passed <= check_passed_next;
            setup_cnt <= setup_cnt_next;
            clique_cnt <= clique_cnt_next;
            i_iter <= i_iter_next;
            j_iter <= j_iter_next;
        end
    end

    always @(*) begin
        // Defaults
        next_state = state;
        
        // Matrix default (keep values)
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                adj_next[i][j] = adj[i][j];
            end
        end

        p0_next = p0; p1_next = p1; p2_next = p2; p3_next = p3;
        u_next = u; v_next = v;
        is_clique_next = is_clique;
        check_passed_next = check_passed;
        setup_cnt_next = setup_cnt;
        clique_cnt_next = clique_cnt;
        i_iter_next = i_iter;
        j_iter_next = j_iter;
        
        valid = valid; // Keep output state unless updated
        arya_set = arya_set;
        sansa_set = sansa_set;
        done = done;

        case (state)
            IDLE: begin
                done = 0;
                valid = 0;
                if (start) begin
                    next_state = SETUP_ADJ;
                    setup_cnt_next = 0;
                end
            end

            SETUP_ADJ: begin
                // Clear matrix first (done once)
                if (setup_cnt == 0) begin
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            adj_next[i][j] = 0;
                        end
                    end
                    setup_cnt_next = 1;
                end else if (setup_cnt == 1) begin
                    // Populate edges
                    // Note: edges are indexed 0 to (m-1). m is input.
                    // We assume m <= 16. We iterate in logic or use specific registers.
                    // Since m is small, we can iterate m times in state machine, but we need a loop counter.
                    // Let's reuse setup_cnt to iterate through edges.
                    // To avoid complex state loops in combinational logic, let's process one edge per cycle.
                    // However, m can be up to 16, so we need a counter 0-15.
                    // Let's rename setup_cnt to edge_idx.
                    if (setup_cnt - 1 < m && (setup_cnt - 1) < 16) begin
                        // Access edge
                        // edges[setup_cnt-1] is 6 bits. u=bits[5:4], v=bits[3:2]
                        // Assume 0-based indexing for cities in edge list.
                        // The prompt says City 1 and 2. Usually this maps to 0 and 1 in bitmask.
                        // Let's assume input edges use 0-based indices 0-3.
                        // If user inputs standard 1-based, logic might need adjustment, but usually input format defines it.
                        // Prompt says: edges {u[1:0], v[1:0]}. So 0 to 3.
                        // Let's assume valid input range.
                        if (edges[setup_cnt - 1][5:4] < n && edges[setup_cnt - 1][3:2] < n) begin
                            adj_next[edges[setup_cnt - 1][5:4]][edges[setup_cnt - 1][3:2]] = 1;
                            adj_next[edges[setup_cnt - 1][3:2]][edges[setup_cnt - 1][5:4]] = 1;
                        end
                        setup_cnt_next = setup_cnt + 1;
                    end else begin
                        // Done with edges
                        next_state = GEN_PERM;
                        // Initialize Permutation
                        // Constraints: City 0 (Node 1) -> A (1). City 1 (Node 2) -> S (2).
                        p0_next = 1;
                        p1_next = 2;
                        p2_next = 0;
                        p3_next = 0;
                        // If n < 2, invalid, but we proceed. If n=1, node 0 is A. 
                        // We need to handle n correctly. If n<=1, node 1 (idx 1) doesn't exist.
                        // But inputs force constraints. We will just generate perms for existing nodes.
                    end
                end
            end

            GEN_PERM: begin
                // Increment permutation for nodes >= 2
                // p2 (Node 2) and p3 (Node 3) iterate 0,1,2,3
                // We must filter 0 (None) based on n.
                // Let's perform a 'next_perm' operation. 
                // We treat the sequence p2, p3 as a base-4 counter.
                
                // Skip logic: If p2==0 and n > 2, we want to advance p2 to 1.
                // Actually, let's just generate 0..3 and filter invalid later.
                // But to be efficient, let's map the search space.
                // Search space is small (4x4=16 combos). 
                // Let's just iterate p2, p3. 
                
                // Current state is a specific (p2, p3).
                // Calculate next (p2, p3).
                if (p2 < 3) begin
                    p2_next = p2 + 1;
                    p3_next = p3;
                end else begin
                    p2_next = 0;
                    if (p3 < 3) begin
                        p3_next = p3 + 1;
                    end else begin
                        p3_next = 0; // Rolled over all
                    end
                end

                // Check validity of permutation
                valid_perm = 1;
                
                // Constraint: Node 0 (City 1) must be A (1)
                if (p0 != 1) valid_perm = 0;
                // Constraint: Node 1 (City 2) must be S (2)
                if (p1 != 2) valid_perm = 0;

                // Constraint: Only nodes < n exist.
                // If n=3, node 2 exists, node 3 does not. 
                // Node 2 must have a valid color (1,2,3). It cannot be 0 (None).
                if (n > 2 && p2 == 0) valid_perm = 0;
                if (n > 3 && p3 == 0) valid_perm = 0;
                // If n <= 2, p2 and p3 should be 0 (unused), but we iterate them.
                // Actually, if n=2, we don't care about p2/p3. 
                // However, the loop needs to terminate.
                // If n=2, we should only accept p2=0, p3=0.
                if (n <= 2) begin
                    if (p2 != 0 || p3 != 0) valid_perm = 0;
                end
                if (n <= 3 && n > 2) begin
                    if (p3 != 0) valid_perm = 0;
                end

                if (valid_perm) begin
                    next_state = CHECK_CLIQUE;
                    // Initialize Clique Check
                    clique_cnt_next = 0; // Check Arya (1)
                    u_next = 0; v_next = 1; // Start pair iteration
                    is_clique_next = 1; // Assume valid until proven false
                    check_passed_next = 0; // 0 = checking, 1 = passed
                    // Set mask for Arya
                    set_mask = { (p3==1), (p2==1), (p1==1), (p0==1) };
                end else begin
                    // Check if we finished all permutations
                    if (p2 == 0 && p3 == 0) begin
                         // We looped back to 0,0. But check inputs for n.
                         // If n==1, p0=1, p1=0 (wait p1 is forced 2? If n=1, City 2 doesn't exist.)
                         // Logic requires refinement. 
                         // If n=1, p1 shouldn't be forced to 2. But prompt says "City 1 in A, City 2 in S".
                         // If n=1, City 2 doesn't exist. Constraints might be impossible.
                         // We will assume constraints apply only if nodes exist.
                         // Let's check rollover termination:
                         // If we are at (0,0) and we just generated it, and it was invalid (due to n constraints), we are done.
                         // But the counter above increments. 
                         // If we are at (3,3) and increment, we go to (0,0).
                         // If (0,0) is invalid (e.g. n=2, p2=0 is ok, p3=0 is ok -> valid). 
                         // If n=4, (0,0) is invalid. 
                         // Let's fix termination: if we rolled over (p2,p3) from (3,3) to (0,0), we are done only if we checked everything.
                         // A simple way: if we are in GEN_PERM and the next state is not CHECK_CLIQUE and we have looped, go to DONE.
                         // Let's check the specific rollover condition:
                         // We are in GEN_PERM. We computed next p2, p3. 
                         // If old p2=3, p3=3, new p2=0, p3=0. That means we finished the cycle.
                         if (p2 == 3 && p3 == 3) begin
                            next_state = DONE_STATE;
                         end
                    end
                end
            end

            CHECK_CLIQUE: begin
                // We need to verify set 1, 2, 3.
                // Loop structure:
                // Outer: clique_cnt (0: A, 1: S, 2: J)
                // Inner: iterate all pairs (u, v) where u < v, and mask[u]=1, mask[v]=1.
                
                // Get Mask
                case (clique_cnt)
                    0: set_mask = { (p3==1), (p2==1), (p1==1), (p0==1) }; // A=1
                    1: set_mask = { (p3==2), (p2==2), (p1==2), (p0==2) }; // S=2
                    2: set_mask = { (p3==3), (p2==3), (p1==3), (p0==3) }; // J=3
                    default: set_mask = 0;
                endcase

                // Check pair (u, v)
                // Only check if u and v are both in the set and u < v
                if (set_mask[u] && set_mask[v] && u < v) begin
                    if (!adj[u][v]) begin
                        is_clique_next = 0; // Found missing edge
                    end
                end

                // Advance Indices
                if (v < 3) begin
                    u_next = u;
                    v_next = v + 1;
                end else begin
                    u_next = u + 1;
                    v_next = u + 2; // Skip v=u+1 since it will be handled by next increment or reset
                    // Actually, simpler: standard double loop reset
                    if (u < 2) begin
                        u_next = u + 1;
                        v_next = u + 2;
                    end else begin
                        // Finished this set
                        if (is_clique) begin
                            // Passed this set
                            if (clique_cnt < 2) begin
                                // Next set
                                clique_cnt_next = clique_cnt + 1;
                                u_next = 0;
                                v_next = 1;
                                is_clique_next = 1; // Reset for next set
                            end else begin
                                // All sets passed
                                check_passed_next = 1;
                                // We can stay in this state or go to UPDATE. 
                                // Let's stay one cycle to latch results if needed, or go to UPDATE.
                                // The prompt has UPDATE_RESULT state.
                                next_state = UPDATE_RESULT;
                            end
                        end else begin
                            // Failed, back to gen perm
                            next_state = GEN_PERM;
                            // Check if we are at the end of the permutation space to go to DONE
                            // We are in CHECK_CLIQUE. We came from GEN_PERM.
                            // If we fail, we must continue generating permutations.
                        end
                    end
                end
                
                // Optimization: If is_clique is already 0, we can fail early.
                // But since we update is_clique at the end of cycle, we can't break early easily without async logic.
                // We will rely on the loop running through.
                
                // If we finished all loops (u >= 2 and v loop finished)
                // The logic above handles it by moving to next set or UPDATE.
            end

            UPDATE_RESULT: begin
                valid = 1;
                arya_set = { (p3==1), (p2==1), (p1==1), (p0==1) };
                sansa_set = { (p3==2), (p2==2), (p1==2), (p0==2) };
                // Done is not asserted yet per state diagram, but let's go to DONE.
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                done = 1;
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule

module TopModule(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [5:0] edges [15:0],
    output valid,
    output [3:0] arya_set,
    output [3:0] sansa_set,
    output done
);
    graph_partition gp (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .n(n),
        .m(m),
        .edges(edges),
        .valid(valid),
        .arya_set(arya_set),
        .sansa_set(sansa_set),
        .done(done)
    );
endmodule
