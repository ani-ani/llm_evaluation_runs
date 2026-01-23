module bst_builder(
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    output reg [7:0] cumulative_sum,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] TRAVERSE = 3'd1;
    localparam [2:0] INSERT   = 3'd2;
    localparam [2:0] DONE     = 3'd3;

    // Node structure parameters
    localparam [2:0] NULL_PTR = 3'd7;
    localparam [3:0] MAX_NODES = 4'd8;

    // State registers
    reg [2:0] state;
    reg [2:0] next_state;

    // Tree storage registers (packed for single cycle access)
    // Each node: [7:0] value, [10:8] left_idx, [13:11] right_idx, [14] valid
    reg [14:0] nodes [0:7];

    // Node access aliases (combinational)
    wire [7:0] node_value;
    wire [2:0] node_left;
    wire [2:0] node_right;
    wire node_valid;

    // Current node registers
    reg [2:0] current_idx;
    reg [7:0] insert_value;
    reg [2:0] traversal_depth;
    reg [2:0] parent_idx;
    reg left_child_flag; // 1 if insert as left child, 0 if right

    // Helper signals
    wire [2:0] next_available;
    wire [2:0] child_idx;
    wire found_position;
    wire is_left;

    // Assign node fields from current index
    assign node_value = nodes[current_idx][7:0];
    assign node_left = nodes[current_idx][10:8];
    assign node_right = nodes[current_idx][13:11];
    assign node_valid = nodes[current_idx][14];

    // Find next available node index (combinational)
    assign next_available = (!nodes[0][14]) ? 3'd0 :
                            (!nodes[1][14]) ? 3'd1 :
                            (!nodes[2][14]) ? 3'd2 :
                            (!nodes[3][14]) ? 3'd3 :
                            (!nodes[4][14]) ? 3'd4 :
                            (!nodes[5][14]) ? 3'd5 :
                            (!nodes[6][14]) ? 3'd6 :
                            (!nodes[7][14]) ? 3'd7 : 3'd7;

    // Child pointer comparison
    assign child_idx = left_child_flag ? node_left : node_right;
    assign found_position = (child_idx == NULL_PTR);

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            cumulative_sum <= 8'd0;
            done <= 1'b0;
            insert_value <= 8'd0;
            current_idx <= 3'd0;
            parent_idx <= 3'd0;
            traversal_depth <= 3'd0;
            left_child_flag <= 1'b0;
            
            // Initialize all nodes as invalid
            for (integer i = 0; i < 8; i = i + 1) begin
                nodes[i] <= 15'd0;
            end
        end else begin
            // Default values
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        insert_value <= data_in;
                        traversal_depth <= 3'd0;
                        
                        if (!nodes[0][14]) begin
                            // First node (empty tree)
                            state <= INSERT;
                            current_idx <= 3'd0;
                            parent_idx <= NULL_PTR;
                            left_child_flag <= 1'b0;
                        end else begin
                            // Start traversal from root
                            state <= TRAVERSE;
                            current_idx <= 3'd0;
                            parent_idx <= NULL_PTR;
                        end
                    end
                end

                TRAVERSE: begin
                    // Move down the tree
                    if (insert_value < node_value) begin
                        left_child_flag <= 1'b1;
                    end else begin
                        left_child_flag <= 1'b0;
                    end

                    if (found_position) begin
                        // Found insertion point
                        state <= INSERT;
                        current_idx <= next_available;
                    end else begin
                        // Continue traversal
                        current_idx <= child_idx;
                        traversal_depth <= traversal_depth + 3'd1;
                        parent_idx <= current_idx;
                    end
                end

                INSERT: begin
                    // Insert the new node
                    if (parent_idx == NULL_PTR) begin
                        // Inserting as root (should only happen on first node)
                        nodes[current_idx] <= {1'b1, 3'd7, 3'd7, insert_value};
                    end else begin
                        // Insert as child of parent
                        nodes[current_idx] <= {1'b1, 3'd7, 3'd7, insert_value};
                        // Update parent's pointer
                        if (left_child_flag) begin
                            nodes[parent_idx][10:8] <= current_idx;
                        end else begin
                            nodes[parent_idx][13:11] <= current_idx;
                        end
                        // Update cumulative sum (skip for root)
                        cumulative_sum <= cumulative_sum + traversal_depth + 8'd1;
                    end
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                    // Note: cumulative_sum was already updated in INSERT for non-root
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Special handling for root insertion (cumulative sum update)
    always @(posedge clk) begin
        if (!rst_n) begin
            // handled in main block
        end else if (state == INSERT && parent_idx == NULL_PTR && nodes[0][14]) begin
            // This is NOT the first insertion (root already exists)
            // This path shouldn't happen in normal operation, but keeping for safety
        end else if (state == INSERT && parent_idx == NULL_PTR && !nodes[0][14]) begin
            // First insertion - root depth is 0, cumulative_sum stays 0
            // No update needed
        end
    end

endmodule