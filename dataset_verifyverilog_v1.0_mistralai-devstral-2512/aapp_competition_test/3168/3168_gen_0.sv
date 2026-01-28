module BSTDepthCalculator(
    input clk,
    input rst_n,
    input start,
    input [7:0] val,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] TRAVERSE  = 3'd1;
    localparam [2:0] ALLOCATE  = 3'd2;
    localparam [2:0] UPDATE    = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Node structure: value (8-bit), left (4-bit), right (4-bit)
    reg [7:0] node_val [0:15];
    reg [3:0] node_left [0:15];
    reg [3:0] node_right [0:15];

    // Tree management
    reg [3:0] root_idx;
    reg [3:0] current_idx;
    reg [3:0] parent_idx;
    reg [3:0] free_list [0:15];
    reg [3:0] free_head;
    reg [3:0] free_count;

    // Traversal state
    reg [3:0] depth;
    reg go_left;

    // Control state
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            root_idx <= 4'd0;
            current_idx <= 4'd0;
            parent_idx <= 4'd0;
            depth <= 4'd0;
            go_left <= 1'b0;
            cycle_count <= 8'd0;
            free_count <= 8'd16;
            free_head <= 4'd1;

            // Initialize free list (0 is reserved for null)
            integer i;
            for (i = 1; i < 16; i = i + 1) begin
                free_list[i] <= i + 4'd1;
            end
            free_list[15] <= 4'd0;

            // Initialize all nodes to 0
            for (i = 0; i < 16; i = i + 1) begin
                node_val[i] <= 8'd0;
                node_left[i] <= 4'd0;
                node_right[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= TRAVERSE;
                        current_idx <= root_idx;
                        parent_idx <= 4'd0;
                        depth <= 4'd0;
                    end
                end

                TRAVERSE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if tree is empty
                    if (root_idx == 4'd0) begin
                        state <= ALLOCATE;
                    end else if (current_idx == 4'd0) begin
                        // Found insertion point
                        state <= ALLOCATE;
                    end else begin
                        // Compare and decide direction
                        if (val < node_val[current_idx]) begin
                            go_left <= 1'b1;
                            parent_idx <= current_idx;
                            current_idx <= node_left[current_idx];
                            depth <= depth + 4'd1;
                        end else begin
                            go_left <= 1'b0;
                            parent_idx <= current_idx;
                            current_idx <= node_right[current_idx];
                            depth <= depth + 4'd1;
                        end
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                ALLOCATE: begin
                    // Allocate new node from free list
                    if (free_count > 8'd0) begin
                        current_idx <= free_head;
                        free_head <= free_list[free_head];
                        free_count <= free_count - 8'd1;
                        
                        // Store the new value
                        node_val[current_idx] <= val;
                        node_left[current_idx] <= 4'd0;
                        node_right[current_idx] <= 4'd0;
                        
                        state <= UPDATE;
                    end else begin
                        // No free nodes - error condition
                        state <= IDLE;
                    end
                end

                UPDATE: begin
                    // Update parent's pointer
                    if (parent_idx == 4'd0) begin
                        // First node - set as root
                        root_idx <= current_idx;
                    end else if (go_left) begin
                        node_left[parent_idx] <= current_idx;
                    end else begin
                        node_right[parent_idx] <= current_idx;
                    end
                    
                    // Update cumulative result
                    result <= result + {8'd0, depth};
                    
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
endmodule