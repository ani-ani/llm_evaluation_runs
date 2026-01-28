module GraphPartitionSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [255:0] edges,
    output reg valid,
    output reg [15:0] arya_mask,
    output reg [15:0] sansa_mask,
    output reg [15:0] other_mask,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE             = 4'd0;
    localparam [3:0] CHECK_INPUT      = 4'd1;
    localparam [3:0] INIT_A           = 4'd2;
    localparam [3:0] COMPUTE_A        = 4'd3;
    localparam [3:0] INIT_B           = 4'd4;
    localparam [3:0] COMPUTE_B        = 4'd5;
    localparam [3:0] COMPUTE_REMAIN   = 4'd6;
    localparam [3:0] VERIFY           = 4'd7;
    localparam [3:0] DONE_STATE       = 4'd8;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Cycle counter for safety
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd256;
    
    // Internal registers
    reg [15:0] arya_reg;
    reg [15:0] sansa_reg;
    reg [15:0] other_reg;
    reg [3:0] node_idx;
    reg [3:0] temp_node;
    reg [15:0] temp_mask;
    reg [15:0] temp_arya;
    reg [15:0] temp_sansa;
    reg [3:0] nodes_in_arya;
    reg [3:0] nodes_in_sansa;
    reg valid_reg;
    
    // Combinational helper signals
    reg [15:0] current_arya;
    reg [15:0] current_sansa;
    reg [15:0] current_other;
    reg [15:0] edge_mask;
    reg [3:0] node_count;
    
    // Helper function to check if two nodes are connected
    function automatic [0:0] connected(input [3:0] i, input [3:0] j, input [255:0] edge_matrix);
        reg [0:0] bit_val;
        begin
            if (i == j) begin
                bit_val = 1'b1;
            end else if (i < 16 && j < 16) begin
                bit_val = edge_matrix[i * 16 + j];
            end else begin
                bit_val = 1'b0;
            end
            connected = bit_val;
        end
    endfunction
    
    // Helper to check if a set of nodes forms a clique
    function automatic [0:0] is_clique(input [15:0] mask, input [3:0] n_nodes, input [255:0] edge_matrix);
        integer i, j;
        reg [0:0] result;
        reg [3:0] count;
        begin
            result = 1'b1;
            count = 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                if (mask[i] && i < n_nodes) begin
                    count = count + 1;
                end
            end
            if (count != n_nodes) begin
                result = 1'b0;
            end else begin
                for (i = 0; i < 16 && result; i = i + 1) begin
                    if (mask[i] && i < n_nodes) begin
                        for (j = i + 1; j < 16; j = j + 1) begin
                            if (mask[j] && j < n_nodes) begin
                                if (!connected(i, j, edge_matrix)) begin
                                    result = 1'b0;
                                end
                            end
                        end
                    end
                end
            end
            is_clique = result;
        end
    endfunction
    
    // Helper to check if node connects to all nodes in mask
    function automatic [0:0] connects_to_all(input [3:0] node, input [15:0] mask, input [3:0] n_nodes, input [255:0] edge_matrix);
        integer j;
        reg [0:0] result;
        begin
            result = 1'b1;
            for (j = 0; j < 16 && result; j = j + 1) begin
                if (mask[j] && j < n_nodes && node < n_nodes) begin
                    if (!connected(node, j, edge_matrix)) begin
                        result = 1'b0;
                    end
                end
            end
            connects_to_all = result;
        end
    endfunction
    
    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_INPUT;
                end
            end
            CHECK_INPUT: begin
                next_state = INIT_A;
            end
            INIT_A: begin
                next_state = COMPUTE_A;
            end
            COMPUTE_A: begin
                if (node_idx >= n || node_idx >= 16) begin
                    next_state = INIT_B;
                end
            end
            INIT_B: begin
                next_state = COMPUTE_B;
            end
            COMPUTE_B: begin
                if (node_idx >= n || node_idx >= 16) begin
                    next_state = COMPUTE_REMAIN;
                end
            end
            COMPUTE_REMAIN: begin
                next_state = VERIFY;
            end
            VERIFY: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            arya_mask <= 16'd0;
            sansa_mask <= 16'd0;
            other_mask <= 16'd0;
            done <= 1'b0;
            cycle_count <= 9'd0;
            arya_reg <= 16'd0;
            sansa_reg <= 16'd0;
            other_reg <= 16'd0;
            node_idx <= 4'd0;
            temp_node <= 4'd0;
            temp_mask <= 16'd0;
            temp_arya <= 16'd0;
            temp_sansa <= 16'd0;
            nodes_in_arya <= 4'd0;
            nodes_in_sansa <= 4'd0;
            valid_reg <= 1'b0;
            current_arya <= 16'd0;
            current_sansa <= 16'd0;
            current_other <= 16'd0;
            edge_mask <= 16'd0;
            node_count <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 9'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 9'd0;
                end
                CHECK_INPUT: begin
                    // Check for direct edge between node 1 (bit 0) and node 2 (bit 1)
                    if (n >= 2 && edges[0 * 16 + 1] == 1'b1) begin
                        valid_reg <= 1'b0;
                    end else begin
                        valid_reg <= 1'b1;
                    end
                end
                INIT_A: begin
                    arya_reg <= 16'd1;  // Node 1 (bit 0) is always in Arya's clique
                    nodes_in_arya <= 4'd1;
                    node_idx <= 4'd1;  // Start checking from node 2 (index 1)
                end
                COMPUTE_A: begin
                    if (valid_reg && node_idx < n && node_idx < 16) begin
                        // Check if node_idx connects to all current Arya nodes
                        if (connects_to_all(node_idx, arya_reg, n, edges)) begin
                            // Add to Arya's clique
                            arya_reg <= arya_reg | (16'd1 << node_idx);
                            nodes_in_arya <= nodes_in_arya + 4'd1;
                        end
                    end
                    node_idx <= node_idx + 4'd1;
                end
                INIT_B: begin
                    node_idx <= 4'd1;  // Start checking from node 2 (index 1)
                    // Remove Arya nodes from consideration for Sansa
                    temp_arya <= arya_reg;
                    sansa_reg <= 16'd0;
                    nodes_in_sansa <= 4'd0;
                end
                COMPUTE_B: begin
                    if (valid_reg && node_idx < n && node_idx < 16) begin
                        // Check if node is not in Arya's clique
                        if (arya_reg[node_idx] == 1'b0) begin
                            if (sansa_reg == 16'd0) begin
                                // First node for Sansa (must be node 2, bit 1)
                                if (node_idx == 4'd1) begin
                                    sansa_reg <= sansa_reg | (16'd1 << node_idx);
                                    nodes_in_sansa <= nodes_in_sansa + 4'd1;
                                end
                            end else begin
                                // Check if connects to all Sansa nodes
                                if (connects_to_all(node_idx, sansa_reg, n, edges)) begin
                                    sansa_reg <= sansa_reg | (16'd1 << node_idx);
                                    nodes_in_sansa <= nodes_in_sansa + 4'd1;
                                end
                            end
                        end
                    end
                    node_idx <= node_idx + 4'd1;
                end
                COMPUTE_REMAIN: begin
                    // Collect remaining nodes
                    other_reg <= 16'd0;
                    if (valid_reg) begin
                        for (temp_node = 0; temp_node < 16; temp_node = temp_node + 1) begin
                            if (temp_node < n) begin
                                if (arya_reg[temp_node] == 1'b0 && sansa_reg[temp_node] == 1'b0) begin
                                    other_reg <= other_reg | (16'd1 << temp_node);
                                end
                            end
                        end
                    end
                end
                VERIFY: begin
                    // Verify all constraints
                    if (valid_reg) begin
                        // Check disjoint
                        if ((arya_reg & sansa_reg) != 16'd0 || 
                            (arya_reg & other_reg) != 16'd0 || 
                            (sansa_reg & other_reg) != 16'd0) begin
                            valid_reg <= 1'b0;
                        end
                        // Check Arya is clique
                        else if (!is_clique(arya_reg, nodes_in_arya, edges)) begin
                            valid_reg <= 1'b0;
                        end
                        // Check Sansa is clique
                        else if (!is_clique(sansa_reg, nodes_in_sansa, edges)) begin
                            valid_reg <= 1'b0;
                        end
                        // Check remaining is clique
                        else if (other_reg != 16'd0) begin
                            node_count = 4'd0;
                            for (temp_node = 0; temp_node < 16; temp_node = temp_node + 1) begin
                                if (temp_node < n && other_reg[temp_node]) begin
                                    node_count = node_count + 4'd1;
                                end
                            end
                            if (!is_clique(other_reg, node_count, edges)) begin
                                valid_reg <= 1'b0;
                            end
                        end
                    end
                end
                DONE_STATE: begin
                    valid <= valid_reg;
                    arya_mask <= arya_reg;
                    sansa_mask <= sansa_reg;
                    other_mask <= other_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule