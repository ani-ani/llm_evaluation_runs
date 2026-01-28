module bst_depth_calc (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] val,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] TRAVERSE  = 3'd1;
    localparam [2:0] ALLOCATE  = 3'd2;
    localparam [2:0] UPDATE    = 3'd3;
    localparam [2:0] DONE      = 3'd4;

    // Node structure: 24-bit packed
    // [23:16] = value (8-bit), [15:8] = left_idx (4-bit), [7:0] = right_idx (4-bit)
    reg [23:0] nodes [0:15];
    reg [3:0] free_list [0:15];  // Queue of free node indices
    reg [3:0] free_head;
    reg [3:0] free_tail;
    
    reg [3:0] root_idx;
    reg [3:0] curr_idx;
    reg [3:0] parent_idx;
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] search_val;
    reg [3:0] depth_count;
    reg [15:0] cum_result;
    
    // Index for loops
    integer i;

    // Combinational logic for traversal decision
    wire [7:0] curr_val;
    wire [3:0] curr_left;
    wire [3:0] curr_right;
    wire is_left;
    
    assign curr_val = nodes[curr_idx][23:16];
    assign curr_left = nodes[curr_idx][15:12];
    assign curr_right = nodes[curr_idx][11:8];
    assign is_left = (search_val < curr_val);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            next_state <= IDLE;
            root_idx <= 4'd0;
            curr_idx <= 4'd0;
            parent_idx <= 4'd0;
            search_val <= 8'd0;
            depth_count <= 4'd0;
            cum_result <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            free_head <= 4'd0;
            free_tail <= 4'd15;
            
            // Initialize all nodes to empty
            for (i = 0; i < 16; i = i + 1) begin
                nodes[i] <= 24'd0;  // All pointers 0, value 0
            end
            
            // Initialize free list: 1, 2, 3, ..., 15
            free_list[0] <= 4'd1;
            free_list[1] <= 4'd2;
            free_list[2] <= 4'd3;
            free_list[3] <= 4'd4;
            free_list[4] <= 4'd5;
            free_list[5] <= 4'd6;
            free_list[6] <= 4'd7;
            free_list[7] <= 4'd8;
            free_list[8] <= 4'd9;
            free_list[9] <= 4'd10;
            free_list[10] <= 4'd11;
            free_list[11] <= 4'd12;
            free_list[12] <= 4'd13;
            free_list[13] <= 4'd14;
            free_list[14] <= 4'd15;
            free_list[15] <= 4'd0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    depth_count <= 4'd0;
                    
                    if (start) begin
                        search_val <= val;
                        curr_idx <= root_idx;
                        parent_idx <= 4'd0;
                        
                        if (root_idx == 4'd0) begin
                            // Tree empty, go straight to allocate
                            state <= ALLOCATE;
                            next_state <= DONE;
                        end else begin
                            state <= TRAVERSE;
                            next_state <= ALLOCATE;
                        end
                    end
                end
                
                TRAVERSE: begin
                    // Check if we reached empty child
                    if (is_left) begin
                        if (curr_left == 4'd0) begin
                            // Found empty left slot
                            state <= ALLOCATE;
                            next_state <= UPDATE;
                            // Track which direction for parent update
                        end else begin
                            // Move left
                            curr_idx <= curr_left;
                            parent_idx <= curr_idx;
                            depth_count <= depth_count + 4'd1;
                        end
                    end else begin
                        if (curr_right == 4'd0) begin
                            // Found empty right slot
                            state <= ALLOCATE;
                            next_state <= UPDATE;
                        end else begin
                            // Move right
                            curr_idx <= curr_right;
                            parent_idx <= curr_idx;
                            depth_count <= depth_count + 4'd1;
                        end
                    end
                end
                
                ALLOCATE: begin
                    // Allocate new node from free list
                    if (free_head < 16'd15) begin
                        curr_idx <= free_list[free_head];
                        free_head <= free_head + 4'd1;
                        
                        // Write value to new node
                        nodes[free_list[free_head]] <= {val, 4'd0, 4'd0};
                        
                        state <= next_state;
                    end
                end
                
                UPDATE: begin
                    // Update parent's pointer
                    if (parent_idx == 4'd0) begin
                        // This was the root (shouldn't happen if root was 0)
                        root_idx <= curr_idx;
                    end else begin
                        // Update parent's left or right pointer
                        if (is_left) begin
                            nodes[parent_idx][15:12] <= curr_idx;
                        end else begin
                            nodes[parent_idx][11:8] <= curr_idx;
                        end
                    end
                    
                    // Update cumulative result
                    cum_result <= cum_result + depth_count;
                    result <= cum_result + depth_count;
                    
                    state <= DONE;
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule