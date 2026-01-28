module min_heap_check (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [4:0] len,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] RESET_Q   = 3'd1;
    localparam [2:0] CHECK     = 3'd2;
    localparam [2:0] VERIFY    = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] current_idx;      // Current node index being checked
    reg [4:0] left_child;
    reg [4:0] right_child;
    reg [4:0] queue_head;       // Head pointer for queue
    reg [4:0] queue_tail;       // Tail pointer for queue
    reg [4:0] queue [0:15];     // Fixed-depth queue for BFS
    reg is_valid;               // Internal validity flag
    reg [7:0] cycle_count;      // Cycle counter for timeout
    reg start_d;                // Delayed start signal
    
    // Wire declarations for child indices
    wire [4:0] left_child_wire;
    wire [4:0] right_child_wire;
    
    // Calculate child indices
    assign left_child_wire = (current_idx << 1) + 5'd1;
    assign right_child_wire = (current_idx << 1) + 5'd2;

    // FSM next state logic
    always @(*) begin
        next_state = state;  // Default
        case (state)
            IDLE: begin
                if (start && !start_d) begin
                    if (len <= 5'd1) begin
                        next_state = FINISH;  // Edge case: len <= 1 always valid
                    end else begin
                        next_state = RESET_Q;
                    end
                end
            end
            RESET_Q: begin
                next_state = CHECK;
            end
            CHECK: begin
                if (queue_head == queue_tail) begin
                    // Queue empty, traversal complete
                    next_state = VERIFY;
                end else begin
                    next_state = CHECK;  // Continue checking
                end
            end
            VERIFY: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // FSM sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            is_valid <= 1'b1;
            current_idx <= 5'd0;
            left_child <= 5'd0;
            right_child <= 5'd0;
            queue_head <= 5'd0;
            queue_tail <= 5'd0;
            cycle_count <= 8'd0;
            start_d <= 1'b0;
            // Initialize queue array
            queue[0] <= 5'd0; queue[1] <= 5'd0; queue[2] <= 5'd0; queue[3] <= 5'd0;
            queue[4] <= 5'd0; queue[5] <= 5'd0; queue[6] <= 5'd0; queue[7] <= 5'd0;
            queue[8] <= 5'd0; queue[9] <= 5'd0; queue[10] <= 5'd0; queue[11] <= 5'd0;
            queue[12] <= 5'd0; queue[13] <= 5'd0; queue[14] <= 5'd0; queue[15] <= 5'd0;
        end else begin
            start_d <= start;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start && !start_d) begin
                        if (len <= 5'd1) begin
                            is_valid <= 1'b1;
                        end else begin
                            is_valid <= 1'b1;
                        end
                    end
                end
                RESET_Q: begin
                    queue_head <= 5'd0;
                    queue_tail <= 5'd1;
                    queue[0] <= 5'd0;  // Enqueue root index
                    current_idx <= 5'd0;
                    left_child <= 5'd0;
                    right_child <= 5'd0;
                end
                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (queue_head != queue_tail) begin
                        // Dequeue current node
                        current_idx <= queue[queue_head];
                        queue_head <= queue_head + 5'd1;
                        
                        // Calculate child indices
                        left_child <= left_child_wire;
                        right_child <= right_child_wire;
                        
                        // Check left child if exists
                        if (left_child_wire < len) begin
                            if (arr[current_idx] > arr[left_child_wire]) begin
                                is_valid <= 1'b0;
                            end
                            // Enqueue left child if it's not a leaf
                            if (left_child_wire < (len >> 1)) begin
                                queue[queue_tail] <= left_child_wire;
                                queue_tail <= queue_tail + 5'd1;
                            end
                        end
                        
                        // Check right child if exists
                        if (right_child_wire < len) begin
                            if (arr[current_idx] > arr[right_child_wire]) begin
                                is_valid <= 1'b0;
                            end
                            // Enqueue right child if it's not a leaf
                            if (right_child_wire < (len >> 1)) begin
                                queue[queue_tail] <= right_child_wire;
                                queue_tail <= queue_tail + 5'd1;
                            end
                        end
                    end
                end
                VERIFY: begin
                    // Final result is already in is_valid
                    result <= is_valid;
                end
                FINISH: begin
                    done <= 1'b1;
                    // Reset for next operation
                    is_valid <= 1'b1;
                    queue_head <= 5'd0;
                    queue_tail <= 5'd0;
                end
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                    is_valid <= 1'b1;
                    current_idx <= 5'd0;
                    left_child <= 5'd0;
                    right_child <= 5'd0;
                    queue_head <= 5'd0;
                    queue_tail <= 5'd0;
                    cycle_count <= 8'd0;
                    start_d <= 1'b0;
                end
            endcase
        end
    end

endmodule