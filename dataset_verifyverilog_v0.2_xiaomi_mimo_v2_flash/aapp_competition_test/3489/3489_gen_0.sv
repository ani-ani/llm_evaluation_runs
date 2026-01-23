module safe_network (
    input clk,
    input rst_n,
    input start,
    input [3:0] n_minus_1_edges_count,
    input [3:0] edge_index,
    input [3:0] u,
    input [3:0] v,
    input [3:0] h,
    output reg [3:0] m,
    output reg [3:0] out_u,
    output reg [3:0] out_v,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam LOAD_EDGES = 3'b001;
    localparam CALC_DEGREES = 3'b010;
    localparam FIND_LEAVES = 3'b011;
    localparam OUTPUT_EDGES = 3'b100;
    localparam DONE_STATE = 3'b101;

    reg [2:0] current_state, next_state;

    // Adjacency Matrix: 16x16 bits
    // We use a 2D array. Synthesis tools flatten this to a vector.
    reg adj_matrix [0:15][0:15];
    
    // Degree counters: 16x4 bits
    reg [3:0] degrees [0:15];
    
    // Leaf indices storage
    reg [3:0] leaf_list [0:15];
    reg [3:0] leaf_count;
    reg [3:0] leaf_idx_counter; // Used for storing and retrieving
    
    // Computation counters
    reg [3:0] node_idx; // Generic node counter for loops
    reg [3:0] edge_cnt; // Edge input counter
    reg [3:0] out_edge_idx; // Output edge counter
    reg [3:0] phase; // Used for pairing logic: 0=check first pair, 1=check second pair, etc.

    // Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State Transition and Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            done <= 0;
            m <= 0;
            out_u <= 0;
            out_v <= 0;
            leaf_count <= 0;
            edge_cnt <= 0;
            node_idx <= 0;
            out_edge_idx <= 0;
            leaf_idx_counter <= 0;
            phase <= 0;
            // Reset adjacency matrix and degrees
            for (integer i = 0; i < 16; i = i + 1) begin
                degrees[i] <= 4'b0;
                for (integer j = 0; j < 16; j = j + 1) begin
                    adj_matrix[i][j] <= 1'b0;
                end
            end
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Initialize counters and arrays for new computation
                        edge_cnt <= 0;
                        node_idx <= 0;
                        leaf_count <= 0;
                        leaf_idx_counter <= 0;
                        out_edge_idx <= 0;
                        phase <= 0;
                        m <= 0;
                        // Clear matrix and degrees
                        for (integer i = 0; i < 16; i = i + 1) begin
                            degrees[i] <= 4'b0;
                            for (integer j = 0; j < 16; j = j + 1) begin
                                adj_matrix[i][j] <= 1'b0;
                            end
                        end
                    end
                end

                LOAD_EDGES: begin
                    // Assume external logic handles valid signal or we just read inputs when available.
                    // The problem says 'Accept edges sequentially', implies inputs change per cycle.
                    // We use edge_index to verify sequence, or just stream in.
                    // Here we assume we process one edge per cycle when in this state.
                    // Since 'start' was asserted, we assume inputs are valid immediately or controlled by external flow.
                    // To be safe and cycle accurate, we increment edge_cnt every cycle.
                    if (edge_cnt < n_minus_1_edges_count) begin
                        // Load edge u-v
                        if (u < 16 && v < 16 && u != v) begin
                            adj_matrix[u][v] <= 1'b1;
                            adj_matrix[v][u] <= 1'b1;
                            // Optimization: We can increment degrees here to save a cycle, 
                            // but requirements ask for CALC_DEGREES state. We will do it there.
                            // Actually, let's just store edges in this state to follow requirements strictly.
                        end
                        edge_cnt <= edge_cnt + 1;
                    end
                end

                CALC_DEGREES: begin
                    // Iterate over all edges to calculate degrees
                    // Since we have the matrix, we can count connections.
                    // Or, we can just sum up edges during LOAD_EDGES. 
                    // Let's follow the state requirement: scan the matrix.
                    if (node_idx < 16) begin
                        // Calculate degree for node 'node_idx'
                        // Unroll loop for synthesis efficiency or keep compact.
                        // 16 nodes, 16 entries to check. 
                        // We need a sub-counter for the inner loop if doing it in one cycle is too heavy.
                        // Let's do a multi-cycle approach for inner loop to be safe with timing.
                        // Re-use 'phase' as internal counter for the node columns.
                        if (phase < 16) begin
                            if (adj_matrix[node_idx][phase]) begin
                                degrees[node_idx] <= degrees[node_idx] + 1;
                            end
                            phase <= phase + 1;
                        end else begin
                            phase <= 0;
                            node_idx <= node_idx + 1;
                        end
                    end
                end

                FIND_LEAVES: begin
                    // Identify leaves (degree == 1, excluding root h)
                    if (node_idx < 16) begin
                        if (degrees[node_idx] == 1 && node_idx != h) begin
                            // Found a leaf
                            leaf_list[leaf_count] <= node_idx;
                            leaf_count <= leaf_count + 1;
                        end
                        node_idx <= node_idx + 1;
                    end
                end

                OUTPUT_EDGES: begin
                    // Calculate m = (leaf_count + 1) / 2 (Integer division ceiling)
                    // This calculation happens before entering or right at start of this state.
                    // Let's do it once at the transition or inside.
                    if (phase == 0) begin
                        m <= (leaf_count + 1) >> 1; // Shift right for divide by 2
                        phase <= 1; // Mark as calculated
                        out_edge_idx <= 0;
                    end else begin
                        // Stream out edges
                        if (out_edge_idx < m) begin
                            // Pair logic: pair (0,1), (2,3)... if odd, last connects to root h
                            // Requirement: If odd, connect last leaf to root (or leaves[0]). 
                            // We will connect to root 'h' as specified in text description.
                            
                            // Current pair base index: out_edge_idx * 2
                            // Check if we are at the last edge and odd count
                            if (out_edge_idx == (m - 1) && (leaf_count[0] == 1'b1)) begin
                                // Odd number of leaves, last edge connects last leaf to root
                                out_u <= leaf_list[leaf_count - 1];
                                out_v <= h;
                            end else begin
                                // Normal pairing
                                out_u <= leaf_list[out_edge_idx * 2];
                                out_v <= leaf_list[(out_edge_idx * 2) + 1];
                            end
                            out_edge_idx <= out_edge_idx + 1;
                        end else begin
                            // Done outputting
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Combinational Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD_EDGES;
                else next_state = IDLE;
            end
            
            LOAD_EDGES: begin
                if (edge_cnt >= n_minus_1_edges_count) next_state = CALC_DEGREES;
                else next_state = LOAD_EDGES;
            end
            
            CALC_DEGREES: begin
                // Wait for all nodes (0-15) and their columns (0-15) to be processed
                // node_idx goes 0 to 15, phase handles sub-stepping
                if (node_idx == 16 && phase == 0) next_state = FIND_LEAVES;
                else next_state = CALC_DEGREES;
            end
            
            FIND_LEAVES: begin
                if (node_idx == 16) next_state = OUTPUT_EDGES;
                else next_state = FIND_LEAVES;
            end
            
            OUTPUT_EDGES: begin
                // Wait for output stream to finish
                // Check if m is calculated and outputs are done
                // We use a phase flag to ensure m is set before counting outputs
                if (phase != 0 && out_edge_idx >= m) next_state = DONE_STATE;
                else next_state = OUTPUT_EDGES;
            end
            
            DONE_STATE: begin
                next_state = DONE_STATE; // Stay done until reset
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule
