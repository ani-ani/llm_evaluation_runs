module min_heap_validator(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [4:0] len,
    output reg result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Queue for node indices (max 16 elements)
    reg [3:0] queue [0:15];
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [3:0] queue_size;
    
    // Current node being checked
    reg [3:0] current_node;
    reg [3:0] left_child;
    reg [3:0] right_child;
    
    // Result tracking
    reg heap_valid;
    
    // Initialize queue
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            heap_valid <= 1'b1;
            
            // Reset queue
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            queue_size <= 4'd0;
            
            // Clear queue contents
            for (i = 0; i < 16; i = i + 1) begin
                queue[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    heap_valid <= 1'b1;
                    
                    if (start) begin
                        // Initialize queue with root node
                        queue[0] <= 4'd0;
                        queue_head <= 4'd0;
                        queue_tail <= 4'd1;
                        queue_size <= 4'd1;
                        
                        // Edge case: len <= 1 is always valid
                        if (len <= 5'd1) begin
                            heap_valid <= 1'b1;
                            state <= FINISH;
                        end else begin
                            state <= CHECK;
                        end
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if queue is empty
                    if (queue_size == 4'd0) begin
                        state <= FINISH;
                    end else begin
                        // Dequeue current node
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        queue_size <= queue_size - 4'd1;
                        
                        // Calculate child indices
                        left_child <= current_node * 2'd2 + 2'd1;
                        right_child <= current_node * 2'd2 + 2'd2;
                        
                        // Check left child
                        if (left_child < len) begin
                            if (arr[current_node] > arr[left_child]) begin
                                heap_valid <= 1'b0;
                            end
                            // Enqueue left child
                            queue[queue_tail] <= left_child;
                            queue_tail <= queue_tail + 4'd1;
                            queue_size <= queue_size + 4'd1;
                        end
                        
                        // Check right child
                        if (right_child < len && heap_valid) begin
                            if (arr[current_node] > arr[right_child]) begin
                                heap_valid <= 1'b0;
                            end
                            // Enqueue right child
                            queue[queue_tail] <= right_child;
                            queue_tail <= queue_tail + 4'd1;
                            queue_size <= queue_size + 4'd1;
                        end
                        
                        // Safety check for cycle limit
                        if (cycle_count >= MAX_CYCLES) begin
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    result <= heap_valid;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule