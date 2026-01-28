module TreeComponentAnalyzer(
    input clk,
    input rst_n,
    input start,
    input [7:0] h [0:255],
    input [7:0] v [0:255],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    
    // Time counter (0-255)
    reg [7:0] t;
    
    // Current heights at time t
    reg [7:0] current_heights [0:255];
    
    // Visited array for BFS
    reg visited [0:255];
    
    // BFS queue
    reg [7:0] queue [0:255];
    reg [7:0] queue_head, queue_tail;
    
    // Current component size
    reg [7:0] current_size;
    
    // Max component size found
    reg [7:0] max_size;
    
    // Cycle counter for timeout
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd50000;
    
    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            t <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            max_size <= 8'd0;
            cycle_count <= 16'd0;
            
            // Initialize arrays
            for (i = 0; i < 256; i = i + 1) begin
                current_heights[i] <= 8'd0;
                visited[i] <= 1'b0;
                queue[i] <= 8'd0;
            end
            queue_head <= 8'd0;
            queue_tail <= 8'd0;
            current_size <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        next_state <= COMPUTE;
                        t <= 8'd0;
                        max_size <= 8'd0;
                        
                        // Reset visited array
                        for (i = 0; i < 256; i = i + 1) begin
                            visited[i] <= 1'b0;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Compute heights for current t
                    for (i = 0; i < 256; i = i + 1) begin
                        current_heights[i] <= h[i] + v[i] * t;
                    end
                    
                    // Find connected components
                    // Reset visited array for this t
                    for (i = 0; i < 256; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    
                    // BFS for each unvisited node
                    for (i = 0; i < 256; i = i + 1) begin
                        if (!visited[i]) begin
                            // Start BFS from this node
                            queue_head <= 8'd0;
                            queue_tail <= 8'd1;
                            queue[0] <= i;
                            visited[i] <= 1'b1;
                            current_size <= 8'd1;
                            
                            // BFS loop
                            while (queue_head < queue_tail) begin
                                reg [7:0] current_node = queue[queue_head];
                                queue_head <= queue_head + 8'd1;
                                
                                // Check 4 neighbors
                                reg [7:0] row = current_node / 16;
                                reg [7:0] col = current_node % 16;
                                reg [7:0] neighbor;
                                
                                // Up neighbor
                                if (row > 0) begin
                                    neighbor = (row - 1) * 16 + col;
                                    if (!visited[neighbor] && 
                                        current_heights[neighbor] == current_heights[current_node]) begin
                                        queue[queue_tail] <= neighbor;
                                        queue_tail <= queue_tail + 8'd1;
                                        visited[neighbor] <= 1'b1;
                                        current_size <= current_size + 8'd1;
                                    end
                                end
                                
                                // Down neighbor
                                if (row < 15) begin
                                    neighbor = (row + 1) * 16 + col;
                                    if (!visited[neighbor] && 
                                        current_heights[neighbor] == current_heights[current_node]) begin
                                        queue[queue_tail] <= neighbor;
                                        queue_tail <= queue_tail + 8'd1;
                                        visited[neighbor] <= 1'b1;
                                        current_size <= current_size + 8'd1;
                                    end
                                end
                                
                                // Left neighbor
                                if (col > 0) begin
                                    neighbor = row * 16 + (col - 1);
                                    if (!visited[neighbor] && 
                                        current_heights[neighbor] == current_heights[current_node]) begin
                                        queue[queue_tail] <= neighbor;
                                        queue_tail <= queue_tail + 8'd1;
                                        visited[neighbor] <= 1'b1;
                                        current_size <= current_size + 8'd1;
                                    end
                                end
                                
                                // Right neighbor
                                if (col < 15) begin
                                    neighbor = row * 16 + (col + 1);
                                    if (!visited[neighbor] && 
                                        current_heights[neighbor] == current_heights[current_node]) begin
                                        queue[queue_tail] <= neighbor;
                                        queue_tail <= queue_tail + 8'd1;
                                        visited[neighbor] <= 1'b1;
                                        current_size <= current_size + 8'd1;
                                    end
                                end
                            end
                            
                            // Update max_size
                            if (current_size > max_size) begin
                                max_size <= current_size;
                            end
                        end
                    end
                    
                    // Move to next time step
                    if (t == 8'd255) begin
                        next_state <= FINISH;
                    end else begin
                        t <= t + 8'd1;
                        next_state <= COMPUTE;
                    end
                    
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= max_size;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule