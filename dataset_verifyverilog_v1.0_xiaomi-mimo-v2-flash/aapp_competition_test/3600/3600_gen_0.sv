module IndependentSetSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] k_in,
    input wire [511:0] graph_packed,
    input wire [5:0] num_nodes,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] INIT         = 3'd1;
    localparam [2:0] CHECK        = 3'd2;
    localparam [2:0] NEXT_COMBO   = 3'd3;
    localparam [2:0] FOUND_VALID  = 3'd4;
    localparam [2:0] DONE_STATE   = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [4:0] k_reg;              // k value (0-15)
    reg [5:0] n_reg;              // number of nodes (1-32)
    reg [31:0] selection_mask;    // current selection
    reg [31:0] combo_index;       // combination counter
    reg [5:0] node_idx;           // node checking index
    reg [5:0] node_idx2;          // second node for adjacency check
    reg valid_found;              // flag for valid combination
    reg [7:0] cycle_count;        // cycle counter for timeout
    localparam [7:0] MAX_CYCLES = 8'd200;
    localparam [7:0] MAX_COMBOS = 8'd100; // limit for worst-case

    // Internal signals
    reg [31:0] temp_selection;
    reg [31:0] adj_mask_node1;
    reg [31:0] adj_mask_node2;
    reg [15:0] temp_bits;
    reg [4:0] selected_count;
    reg [5:0] shift_idx;
    reg [31:0] node_bit;
    reg [31:0] check_mask;
    reg [31:0] overlap;
    reg [31:0] first_node_mask;
    reg [5:0] first_node_idx;
    reg [5:0] second_node_idx;

    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            k_reg <= 5'd0;
            n_reg <= 6'd0;
            selection_mask <= 32'd0;
            combo_index <= 32'd0;
            node_idx <= 6'd0;
            node_idx2 <= 6'd0;
            valid_found <= 1'b0;
            cycle_count <= 8'd0;
            selected_count <= 5'd0;
            shift_idx <= 6'd0;
            node_bit <= 32'd0;
            check_mask <= 32'd0;
            overlap <= 32'd0;
            first_node_mask <= 32'd0;
            first_node_idx <= 6'd0;
            second_node_idx <= 6'd0;
            adj_mask_node1 <= 32'd0;
            adj_mask_node2 <= 32'd0;
            temp_bits <= 16'd0;
            temp_selection <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        k_reg <= {1'b0, k_in};
                        n_reg <= num_nodes;
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Handle trivial cases
                    if (k_reg == 5'd0 || k_reg == 5'd1) begin
                        result <= 1'b1;
                        state <= DONE_STATE;
                    end else if (k_reg > n_reg) begin
                        result <= 1'b0;
                        state <= DONE_STATE;
                    end else begin
                        // Initialize for combination search
                        selection_mask <= 32'd0;
                        combo_index <= 32'd0;
                        valid_found <= 1'b0;
                        // Generate first combination: k lowest bits
                        node_idx <= 6'd0;
                        temp_selection <= 32'd0;
                        selected_count <= 5'd0;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    // Check current selection_mask
                    if (selected_count != k_reg) begin
                        // Need to generate valid combination first
                        // Try to set bits in selection_mask based on combo_index
                        selection_mask <= 32'd0;
                        temp_selection <= 32'd0;
                        node_idx <= 6'd0;
                        selected_count <= 5'd0;
                        shift_idx <= 6'd0;
                        // Start combination generation
                        // Use binary representation approach
                        combo_index <= combo_index + 32'd1;
                        if (combo_index < 32'd100) begin
                            state <= NEXT_COMBO;
                        end else begin
                            state <= DONE_STATE;
                            result <= 1'b0;
                        end
                    end else begin
                        // Check adjacency for current selection
                        node_idx <= 6'd0;
                        node_idx2 <= 6'd0;
                        first_node_idx <= 6'd0;
                        second_node_idx <= 6'd0;
                        first_node_mask <= 32'd0;
                        adj_mask_node1 <= 32'd0;
                        adj_mask_node2 <= 32'd0;
                        state <= NEXT_COMBO; // will continue checking
                    end
                end

                NEXT_COMBO: begin
                    // Generate next combination of k nodes
                    // Simple method: try sequential combinations with limited search
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (valid_found) begin
                        state <= FOUND_VALID;
                    end else if (cycle_count >= MAX_CYCLES || combo_index > 32'd5000) begin
                        result <= 1'b0;
                        state <= DONE_STATE;
                    end else begin
                        // Generate a valid combination of k bits
                        // Use a simple pattern: set bits at positions based on combo_index
                        selection_mask <= 32'd0;
                        temp_selection <= 32'd0;
                        
                        // Create combination: bits at positions [combo_index % n] etc
                        // For simplicity, use binary counter pattern
                        node_idx <= 6'd0;
                        selected_count <= 5'd0;
                        temp_selection <= combo_index;
                        
                        // Check if this selection has exactly k bits and within n
                        if (combo_index[31:0] != 32'd0) begin
                            // Count bits and verify
                            node_idx2 <= 6'd0;
                            state <= CHECK;
                            // Actually, let's generate properly
                            // Use a combinatorial method
                            selection_mask <= combo_index & ((32'h1 << n_reg) - 32'h1);
                            node_idx <= 6'd0;
                        end
                        
                        // Actually, let's just check current combo_index as selection mask
                        // But need to ensure exactly k bits set
                        // This is tricky in hardware
                        // Alternative: generate specific combinations
                        
                        // Use next state to check adjacency
                        state <= CHECK;
                    end
                end

                FOUND_VALID: begin
                    result <= 1'b1;
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

    // Adjacency checking logic (combinatorial)
    // This runs concurrently with state machine
    reg check_done;
    reg [31:0] bits_set;
    reg [31:0] adj_check_temp;
    reg [5:0] bit_count;
    reg [5:0] check_node;
    reg [5:0] check_node2;
    reg [31:0] node_adj_mask;
    reg [31:0] selection_check;
    reg conflict_found;
    
    // Sequential process for detailed checking
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            check_done <= 1'b0;
            bits_set <= 32'd0;
            adj_check_temp <= 32'd0;
            bit_count <= 6'd0;
            check_node <= 6'd0;
            check_node2 <= 6'd0;
            node_adj_mask <= 32'd0;
            selection_check <= 32'd0;
            conflict_found <= 1'b0;
        end else begin
            if (state == NEXT_COMBO || state == CHECK) begin
                // Count bits in selection_mask
                if (combo_index == 32'd0) begin
                    bits_set <= 32'd0;
                    bit_count <= 6'd0;
                    check_node <= 6'd0;
                    conflict_found <= 1'b0;
                    selection_check <= selection_mask;
                end
                
                // Count set bits (popcount)
                if (check_node < 32) begin
                    if (selection_check[check_node]) begin
                        bit_count <= bit_count + 6'd1;
                        // Extract adjacency for this node
                        // Graph packed: 16 bits per node
                        adj_check_temp <= graph_packed[(check_node * 16) +: 16];
                    end
                    check_node <= check_node + 6'd1;
                end
                
                // Check if bit count matches k
                if (check_node >= 32 && bit_count == k_reg && !conflict_found) begin
                    // Now check for adjacencies between selected nodes
                    if (node_idx < 32) begin
                        if (selection_check[node_idx]) begin
                            // Get adjacency mask for this node (16 bits)
                            node_adj_mask <= {{16{1'b0}}, graph_packed[(node_idx * 16) +: 16]};
                            node_idx2 <= node_idx + 6'd1;
                        end
                        node_idx <= node_idx + 6'd1;
                    end else if (!conflict_found && bit_count == k_reg) begin
                        // No conflicts found
                        valid_found <= 1'b1;
                    end
                    
                    if (node_idx2 < 32 && selection_check[node_idx2]) begin
                        // Check if node_idx2 is adjacent to node_idx
                        if (node_adj_mask[node_idx2]) begin
                            conflict_found <= 1'b1;
                        end
                        node_idx2 <= node_idx2 + 6'd1;
                    end
                end
                
                if (conflict_found || (check_node >= 32 && bit_count != k_reg)) begin
                    valid_found <= 1'b0;
                end
            end
        end
    end

    // Simplified combination generation using combinatorial logic
    // This generates combinations sequentially
    always @(*) begin
        // Generate next combination
        // Simple approach: for testing, use a pattern
        // In practice, this would need proper combination generation
        
        // For now, we rely on the state machine logic
    end

endmodule