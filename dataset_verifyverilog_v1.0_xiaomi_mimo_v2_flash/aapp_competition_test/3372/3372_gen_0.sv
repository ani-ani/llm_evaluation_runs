module shortest_path (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] s,
    input wire [2:0] t,
    input wire [7:0] adj_0,
    input wire [7:0] adj_1,
    input wire [7:0] adj_2,
    input wire [7:0] adj_3,
    input wire [7:0] adj_4,
    input wire [7:0] adj_5,
    input wire [7:0] adj_6,
    input wire [7:0] adj_7,
    output reg [3:0] result,
    output reg done,
    output reg impossible
);
    // Parameters
    parameter N_NODES = 8;
    parameter MAX_CYCLES = 1000;
    
    // State encoding
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] INIT = 2'b01;
    localparam [1:0] LOOP = 2'b10;
    localparam [1:0] FINISH = 2'b11;
    
    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] dist_reg;
    reg [3:0] next_dist;
    reg [7:0] visited;
    reg [7:0] next_visited;
    reg [2:0] queue [0:7]; // FIFO for BFS
    reg [2:0] queue_head;
    reg [2:0] queue_tail;
    reg [2:0] next_queue_head;
    reg [2:0] next_queue_tail;
    reg [3:0] cycle_count;
    reg [3:0] next_cycle_count;
    reg found_target;
    reg next_found_target;
    
    // Wires for adjacency matrix
    wire [7:0] adj [0:7];
    assign adj[0] = adj_0;
    assign adj[1] = adj_1;
    assign adj[2] = adj_2;
    assign adj[3] = adj_3;
    assign adj[4] = adj_4;
    assign adj[5] = adj_5;
    assign adj[6] = adj_6;
    assign adj[7] = adj_7;
    
    // Current node in queue
    wire [2:0] current_node = queue[queue_head];
    
    // Next state logic
    always @(*) begin
        next_state = state;
        next_dist = dist_reg;
        next_visited = visited;
        next_queue_head = queue_head;
        next_queue_tail = queue_tail;
        next_cycle_count = cycle_count + 1;
        next_found_target = found_target;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                    next_cycle_count = 0;
                    next_found_target = 1'b0;
                end
            end
            
            INIT: begin
                // Initialize queue with start node
                queue[queue_tail] = s;
                next_queue_tail = queue_tail + 1;
                next_visited = (1'b1 << s);
                next_dist = 0;
                
                if (s == t) begin
                    next_found_target = 1'b1;
                    next_state = FINISH;
                end else begin
                    next_state = LOOP;
                end
            end
            
            LOOP: begin
                if (queue_head >= queue_tail || cycle_count >= MAX_CYCLES) begin
                    // Queue empty or timeout - no path
                    next_state = FINISH;
                end else begin
                    // Process current node
                    if (current_node == t) begin
                        next_found_target = 1'b1;
                        next_state = FINISH;
                    end else begin
                        // Move queue head forward
                        next_queue_head = queue_head + 1;
                        
                        // Check all possible neighbors
                        if (adj[current_node][0] && !visited[0] && queue_tail < 8) begin
                            queue[queue_tail] = 0;
                            next_queue_tail = queue_tail + 1;
                            next_visited[0] = 1'b1;
                        end
                        if (adj[current_node][1] && !visited[1] && queue_tail < 8) begin
                            queue[queue_tail] = 1;
                            next_queue_tail = queue_tail + 1;
                            next_visited[1] = 1'b1;
                        end
                        if (adj[current_node][2] && !visited[2] && queue_tail < 8) begin
                            queue[queue_tail] = 2;
                            next_queue_tail = queue_tail + 1;
                            next_visited[2] = 1'b1;
                        end
                        if (adj[current_node][3] && !visited[3] && queue_tail < 8) begin
                            queue[queue_tail] = 3;
                            next_queue_tail = queue_tail + 1;
                            next_visited[3] = 1'b1;
                        end
                        if (adj[current_node][4] && !visited[4] && queue_tail < 8) begin
                            queue[queue_tail] = 4;
                            next_queue_tail = queue_tail + 1;
                            next_visited[4] = 1'b1;
                        end
                        if (adj[current_node][5] && !visited[5] && queue_tail < 8) begin
                            queue[queue_tail] = 5;
                            next_queue_tail = queue_tail + 1;
                            next_visited[5] = 1'b1;
                        end
                        if (adj[current_node][6] && !visited[6] && queue_tail < 8) begin
                            queue[queue_tail] = 6;
                            next_queue_tail = queue_tail + 1;
                            next_visited[6] = 1'b1;
                        end
                        if (adj[current_node][7] && !visited[7] && queue_tail < 8) begin
                            queue[queue_tail] = 7;
                            next_queue_tail = queue_tail + 1;
                            next_visited[7] = 1'b1;
                        end
                        
                        next_dist = dist_reg + 1;
                    end
                end
            end
            
            FINISH: begin
                // Hold state
                next_state = FINISH;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            dist_reg <= 4'd0;
            visited <= 8'd0;
            queue_head <= 3'd0;
            queue_tail <= 3'd0;
            cycle_count <= 4'd0;
            result <= 4'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            found_target <= 1'b0;
        end else begin
            state <= next_state;
            dist_reg <= next_dist;
            visited <= next_visited;
            queue_head <= next_queue_head;
            queue_tail <= next_queue_tail;
            cycle_count <= next_cycle_count;
            found_target <= next_found_target;
            
            if (state == FINISH) begin
                done <= 1'b1;
                if (found_target) begin
                    impossible <= 1'b0;
                    result <= dist_reg;
                end else begin
                    impossible <= 1'b1;
                    result <= 4'd0;
                end
            end else begin
                done <= 1'b0;
                impossible <= 1'b0;
            end
        end
    end
endmodule