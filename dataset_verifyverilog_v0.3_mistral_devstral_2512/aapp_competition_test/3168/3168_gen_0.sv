module bst_builder(
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    output reg [7:0] cumulative_sum,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] TRAVERSE = 2'd1;
    localparam [1:0] INSERT   = 2'd2;
    localparam [1:0] DONE     = 2'd3;

    // Node structure: valid, value, left, right
    reg [0:0] node_valid [0:7];
    reg [7:0] node_value [0:7];
    reg [2:0] node_left [0:7];
    reg [2:0] node_right [0:7];

    // Control registers
    reg [1:0] state;
    reg [2:0] root_idx;
    reg [2:0] next_node_idx;
    reg [2:0] current_idx;
    reg [2:0] parent_idx;
    reg [7:0] depth_counter;
    reg [7:0] insertion_depth;

    // Initialize all nodes to invalid
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            root_idx <= 3'd0;
            next_node_idx <= 3'd0;
            current_idx <= 3'd0;
            parent_idx <= 3'd0;
            depth_counter <= 8'd0;
            insertion_depth <= 8'd0;
            cumulative_sum <= 8'd0;
            done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                node_valid[i] <= 1'b0;
                node_value[i] <= 8'd0;
                node_left[i] <= 3'd7;
                node_right[i] <= 3'd7;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= TRAVERSE;
                        current_idx <= root_idx;
                        parent_idx <= 3'd7;
                        depth_counter <= 8'd0;
                    end
                end

                TRAVERSE: begin
                    if (current_idx == 3'd7) begin
                        // Empty tree, insert at root
                        insertion_depth <= 8'd0;
                        state <= INSERT;
                    end else if (data_in < node_value[current_idx]) begin
                        // Go left
                        parent_idx <= current_idx;
                        current_idx <= node_left[current_idx];
                        depth_counter <= depth_counter + 8'd1;
                    end else begin
                        // Go right
                        parent_idx <= current_idx;
                        current_idx <= node_right[current_idx];
                        depth_counter <= depth_counter + 8'd1;
                    end
                end

                INSERT: begin
                    // Insert new node
                    node_valid[next_node_idx] <= 1'b1;
                    node_value[next_node_idx] <= data_in;
                    node_left[next_node_idx] <= 3'd7;
                    node_right[next_node_idx] <= 3'd7;

                    // Link to parent
                    if (parent_idx == 3'd7) begin
                        // First node, becomes root
                        root_idx <= next_node_idx;
                        insertion_depth <= 8'd0;
                    end else if (data_in < node_value[parent_idx]) begin
                        node_left[parent_idx] <= next_node_idx;
                        insertion_depth <= depth_counter;
                    end else begin
                        node_right[parent_idx] <= next_node_idx;
                        insertion_depth <= depth_counter;
                    end

                    // Update cumulative sum
                    cumulative_sum <= cumulative_sum + insertion_depth;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                    // Increment next_node_idx for next insertion
                    next_node_idx <= next_node_idx + 3'd1;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule