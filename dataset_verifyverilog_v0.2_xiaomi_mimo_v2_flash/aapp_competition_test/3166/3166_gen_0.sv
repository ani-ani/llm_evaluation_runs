module fair_ranking_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,          // Number of players (2-8)
    input [2:0] k,          // Target max disqualified count (2-4)
    input [7:0] adj_matrix [0:7][0:7],
    input [7:0] s_mask,     // Fixed set S
    output reg [2:0] min_disqualify_size,
    output reg found,
    output reg impossible
);

    // --- State Definition ---
    localparam IDLE = 3'b000;
    localparam CHECK_SUBSET = 3'b001;
    localparam VERIFY_INIT = 3'b010;
    localparam VERIFY_FIND = 3'b011;
    localparam VERIFY_PROC = 3'b100;
    localparam NEXT_SUBSET = 3'b101;
    localparam DONE = 3'b110;
    localparam IMPOSSIBLE = 3'b111;

    // --- Registers ---
    reg [2:0] current_state;
    reg [2:0] next_state;
    reg [2:0] current_size;
    reg [7:0] current_subset;
    
    // Verification Registers
    reg [7:0] verify_mask;         // Mask of removed players
    reg [7:0] working_deg [0:7];   // Working in-degrees
    reg [2:0] verify_node;         // Iterator 0-7
    reg [2:0] processed_count;     // Number of nodes removed (visited)
    reg [2:0] zero_node_idx;       // Latched index of node with degree 0
    reg found_zero;                // Flag during VERIFY_FIND
    
    integer i; // For loop
    reg [3:0] vcount_temp; // For popcount
    reg [2:0] total_remaining; // For popcount result

    // --- Popcount Logic (Sequential to save logic, or Combinatorial) ---
    // We need it for CHECK_SUBSET.
    wire [2:0] subset_popcount;
    assign subset_popcount = current_subset[0] + current_subset[1] + current_subset[2] + current_subset[3] + 
                             current_subset[4] + current_subset[5] + current_subset[6] + current_subset[7];

    // --- Main FSM ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            min_disqualify_size <= 3'b000;
            found <= 1'b0;
            impossible <= 1'b0;
            current_size <= 3'b000;
            current_subset <= 8'h00;
            verify_mask <= 8'h00;
            processed_count <= 3'b000;
        end else begin
            case (current_state)
                IDLE: begin
                    found <= 1'b0;
                    impossible <= 1'b0;
                    current_size <= 3'b000;
                    current_subset <= 8'h00;
                    if (start) begin
                        current_state <= CHECK_SUBSET;
                    end
                end

                CHECK_SUBSET: begin
                    // 1. Check size
                    // 2. Check disjoint from S
                    // 3. Check if all 0s are checked (boundary)
                    
                    // Optimization: If subset overlaps S, skip immediately
                    if ((current_subset & s_mask) != 8'h00) begin
                        current_state <= NEXT_SUBSET;
                    end else if (subset_popcount == current_size) begin
                        // Valid candidate
                        verify_mask <= current_subset | s_mask;
                        processed_count <= 3'b000;
                        verify_node <= 3'b000;
                        found_zero <= 1'b0;
                        current_state <= VERIFY_INIT;
                    end else begin
                        // Wrong size
                        current_state <= NEXT_SUBSET;
                    end
                end

                VERIFY_INIT: begin
                    // Compute in-degrees for remaining nodes
                    // Loop verify_node 0 to 7
                    if (verify_node < 3'd7) begin
                        verify_node <= verify_node + 1;
                    end else begin
                        verify_node <= 3'b000;
                        current_state <= VERIFY_FIND;
                    end

                    // Compute Degree of verify_node
                    // If node is removed (in verify_mask), degree is 0
                    // Else sum of incoming edges
                    if (verify_node < n && !((verify_mask >> verify_node) & 1'b1)) begin
                        working_deg[verify_node] <= 
                            ((adj_matrix[0][verify_node] && !((verify_mask >> 0) & 1'b1)) ? 1'b1 : 1'b0) +
                            ((adj_matrix[1][verify_node] && !((verify_mask >> 1) & 1'b1)) ? 1'b1 : 1'b0) +
                            ((adj_matrix[2][verify_node] && !((verify_mask >> 2) & 1'b1)) ? 1'b1 : 1'b0) +
                            ((adj_matrix[3][verify_node] && !((verify_mask >> 3) & 1'b1)) ? 1'b1 : 1'b0) +
                            ((adj_matrix[4][verify_node] && !((verify_mask >> 4) & 1'b1)) ? 1'b1 : 1'b0) +
                            ((adj_matrix[5][verify_node] && !((verify_mask >> 5) & 1'b1)) ? 1'b1 : 1'b0) +
                            ((adj_matrix[6][verify_node] && !((verify_mask >> 6) & 1'b1)) ? 1'b1 : 1'b0) +
                            ((adj_matrix[7][verify_node] && !((verify_mask >> 7) & 1'b1)) ? 1'b1 : 1'b0);
                    end else begin
                        working_deg[verify_node] <= 8'h00;
                    end
                end

                VERIFY_FIND: begin
                    // Find a node with degree 0 that is not already removed/visited
                    // Iterate verify_node 0 to 7
                    if (verify_node < 3'd7) begin
                        verify_node <= verify_node + 1;
                    end else begin
                        verify_node <= 3'b000; // Reset for next cycle
                        if (found_zero) begin
                            current_state <= VERIFY_PROC;
                        end else begin
                            // End of search for zeros. Check if we are done.
                            // Calculate remaining nodes count
                            vcount_temp = 0;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (verify_mask[i]) vcount_temp = vcount_temp + 1;
                            end
                            total_remaining = n - vcount_temp;
                            
                            if (processed_count == total_remaining) begin
                                current_state <= DONE;
                                min_disqualify_size <= current_size;
                                found <= 1'b1;
                            end else begin
                                current_state <= NEXT_SUBSET; // Cycle detected
                            end
                        end
                    end

                    // Check current node
                    if (verify_node < n && !((verify_mask >> verify_node) & 1'b1)) begin
                        if (working_deg[verify_node] == 0) begin
                            found_zero <= 1'b1;
                            zero_node_idx <= verify_node;
                        end
                    end
                    // If we are at the start of the loop (verify_node==0), clear found_zero
                    if (verify_node == 0) found_zero <= 1'b0;
                end

                VERIFY_PROC: begin
                    // Remove node zero_node_idx
                    // Update neighbors (decrement degrees)
                    
                    // 1. Mark as visited in working_deg (set to non-zero or use mask)
                    // We'll just update verify_mask logically, but we use verify_mask for "removed".
                    // Actually, we should use a separate visited mask or just rely on deg=0.
                    // Kahn's: Remove node, decrement neighbors.
                    
                    // We update verify_mask to include the removed node so we don't process it again.
                    // Wait, verify_mask initially contains S | S'. We add processed nodes to it.
                    verify_mask[zero_node_idx] <= 1'b1;
                    processed_count <= processed_count + 1;
                    
                    // Decrement degrees of neighbors
                    // Neighbors are nodes j such that adj_matrix[zero_node_idx][j] == 1
                    // Loop through j 0 to 7 to update working_deg[j]
                    // We can do this in one cycle or multiple. Since small N, one cycle is fine.
                    
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < n && !((verify_mask >> i) & 1'b1) && adj_matrix[zero_node_idx][i]) begin
                            // If edge exists from removed node to neighbor i, and neighbor i is still active
                            if (working_deg[i] > 0) begin
                                working_deg[i] <= working_deg[i] - 1;
                            end
                        end
                    end
                    
                    // Go back to find next zero
                    current_state <= VERIFY_FIND;
                    verify_node <= 3'b000; // Reset iterator
                    found_zero <= 1'b0;
                end

                NEXT_SUBSET: begin
                    // Increment current_subset
                    if (current_subset == 8'hFF) begin
                        // Loop finished for this size
                        current_subset <= 8'h00;
                        current_size <= current_size + 1;
                        if (current_size + 1 >= k) begin
                            current_state <= IMPOSSIBLE;
                        end else begin
                            current_state <= CHECK_SUBSET;
                        end
                    end else begin
                        current_subset <= current_subset + 1;
                        current_state <= CHECK_SUBSET;
                    end
                end

                DONE: begin
                    // Solution found, stay here
                end

                IMPOSSIBLE: begin
                    impossible <= 1'b1;
                    // Stay here
                end
            endcase
        end
    end

endmodule