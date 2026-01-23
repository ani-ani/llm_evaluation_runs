module tree_lis_solver (
    input clk,
    input rst_n,
    input start,
    input valid_in,
    input [15:0] node_label,
    input [2:0] node_parent,
    output reg [3:0] max_length,
    output reg [15:0] path_count,
    output reg done
);

    // Parameters
    parameter MAX_NODES = 8;
    parameter MOD = 20'd11092019;

    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD_NODE = 3'b001;
    localparam PROCESS_ANCESTORS = 3'b010;
    localparam UPDATE_GLOBAL = 3'b011;
    localparam DONE = 3'b100;

    // Internal registers
    reg [2:0] current_state;
    reg [2:0] next_state;

    // Node storage (max 8 nodes)
    reg [15:0] node_labels [0:7];
    reg [2:0] node_parents [0:7];
    reg [7:0] node_valid_mask; // Bitmask for loaded nodes

    // DP arrays
    reg [3:0] len [0:7];      // Longest path ending at each node
    reg [19:0] cnt [0:7];     // Count of paths ending at each node

    // Processing counters
    reg [2:0] current_node_idx;  // Index of node being processed
    reg [2:0] ancestor_idx;      // Index of current ancestor being checked
    reg [2:0] path_len_temp;     // Temporary path length
    reg [19:0] path_cnt_temp;    // Temporary path count

    // Intermediate calculations
    reg [15:0] compare_label;    // Label of current node
    reg [3:0] compare_len;       // Length of current node
    reg [2:0] search_ptr;        // Pointer for ancestor traversal

    // Helper signals
    reg [2:0] num_nodes_loaded;  // Counter for number of nodes loaded
    reg processing_done;         // Flag for DP computation complete

    // MOD calculation helpers
    reg [35:0] mul_temp;         // For multiplication (20+16 = 36 bits max)

    integer i;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (start && valid_in) begin
                    next_state = LOAD_NODE;
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD_NODE: begin
                if (num_nodes_loaded >= MAX_NODES) begin
                    // All nodes loaded, start processing from root
                    next_state = PROCESS_ANCESTORS;
                end else if (valid_in) begin
                    // Keep loading nodes
                    next_state = LOAD_NODE;
                end else begin
                    // Wait for more data
                    next_state = LOAD_NODE;
                end
            end

            PROCESS_ANCESTORS: begin
                if (processing_done) begin
                    next_state = UPDATE_GLOBAL;
                end else begin
                    next_state = PROCESS_ANCESTORS;
                end
            end

            UPDATE_GLOBAL: begin
                if (current_node_idx == MAX_NODES - 1) begin
                    next_state = DONE;
                end else begin
                    next_state = PROCESS_ANCESTORS;
                end
            end

            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Main processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            max_length <= 4'd0;
            path_count <= 16'd0;
            done <= 1'b0;

            node_valid_mask <= 8'b0;
            num_nodes_loaded <= 3'd0;
            current_node_idx <= 3'd0;
            ancestor_idx <= 3'd0;
            processing_done <= 1'b0;

            for (i = 0; i < MAX_NODES; i = i + 1) begin
                node_labels[i] <= 16'b0;
                node_parents[i] <= 3'b0;
                len[i] <= 4'b0;
                cnt[i] <= 20'b0;
            end

        end else begin
            case (current_state)

                IDLE: begin
                    done <= 1'b0;
                    if (start && valid_in) begin
                        // Load root node
                        node_labels[0] <= node_label;
                        node_parents[0] <= 3'd0; // Root's parent is 0 (itself)
                        node_valid_mask[0] <= 1'b1;
                        num_nodes_loaded <= 3'd1;

                        // Initialize DP for root
                        len[0] <= 4'd1;
                        cnt[0] <= 20'd1;
                    end
                end

                LOAD_NODE: begin
                    if (valid_in && num_nodes_loaded < MAX_NODES) begin
                        // Load current node data
                        node_labels[num_nodes_loaded] <= node_label;
                        node_parents[num_nodes_loaded] <= node_parent;
                        node_valid_mask[num_nodes_loaded] <= 1'b1;

                        // Initialize DP for this node (temporary values)
                        len[num_nodes_loaded] <= 4'd1;
                        cnt[num_nodes_loaded] <= 20'd1;

                        num_nodes_loaded <= num_nodes_loaded + 3'd1;
                    end
                end

                PROCESS_ANCESTORS: begin
                    // Initialize for processing current node
                    if (ancestor_idx == 3'd0 && !processing_done) begin
                        // Start processing node current_node_idx
                        if (current_node_idx < MAX_NODES && node_valid_mask[current_node_idx]) begin
                            // Reset temp values
                            path_len_temp <= 4'd1;
                            path_cnt_temp <= 20'd1;

                            // If root, skip ancestor processing
                            if (node_parents[current_node_idx] == 3'd0 && current_node_idx == 0) begin
                                // Root is already initialized
                                processing_done <= 1'b1;
                            end else begin
                                // Start from parent
                                ancestor_idx <= node_parents[current_node_idx];
                            end
                        end else begin
                            // Node not valid, skip
                            processing_done <= 1'b1;
                        end
                    end else if (!processing_done) begin
                        // Process ancestor
                        if (ancestor_idx == current_node_idx) begin
                            // Finished going up to root
                            processing_done <= 1'b1;
                        end else if (ancestor_idx < MAX_NODES && node_valid_mask[ancestor_idx]) begin
                            // Check label condition
                            if (node_labels[ancestor_idx] <= node_labels[current_node_idx]) begin
                                // Candidate path
                                if (len[ancestor_idx] + 1 > path_len_temp) begin
                                    path_len_temp <= len[ancestor_idx] + 1;
                                    path_cnt_temp <= cnt[ancestor_idx];
                                end else if (len[ancestor_idx] + 1 == path_len_temp) begin
                                    // Add counts
                                    if (path_cnt_temp + cnt[ancestor_idx] < MOD) begin
                                        path_cnt_temp <= path_cnt_temp + cnt[ancestor_idx];
                                    end else begin
                                        path_cnt_temp <= (path_cnt_temp + cnt[ancestor_idx]) - MOD;
                                    end
                                end
                            end

                            // Move to parent of current ancestor
                            ancestor_idx <= node_parents[ancestor_idx];
                        end else begin
                            // Invalid ancestor, finish
                            processing_done <= 1'b1;
                        end
                    end
                end

                UPDATE_GLOBAL: begin
                    // Update DP state for current node
                    len[current_node_idx] <= path_len_temp;
                    cnt[current_node_idx] <= path_cnt_temp;

                    // Update global max
                    if (path_len_temp > max_length) begin
                        max_length <= path_len_temp;
                        path_count <= path_cnt_temp[15:0];
                    end else if (path_len_temp == max_length) begin
                        // Add counts modulo MOD
                        if ({16'b0, path_count} + path_cnt_temp < MOD) begin
                            path_count <= path_count + path_cnt_temp[15:0];
                        end else begin
                            path_count <= (path_count + path_cnt_temp[15:0]) - 16'(MOD[15:0]);
                        end
                    end

                    // Prepare for next node
                    current_node_idx <= current_node_idx + 3'd1;
                    ancestor_idx <= 3'd0;
                    processing_done <= 1'b0;
                end

                DONE: begin
                    done <= 1'b1;
                    // Keep outputs stable
                end

            endcase
        end
    end

endmodule