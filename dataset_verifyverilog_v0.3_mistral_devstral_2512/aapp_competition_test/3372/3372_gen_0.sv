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
    localparam [7:0] N_NODES = 8'd8;
    localparam [15:0] MAX_CYCLES = 16'd1000;
    
    // State encoding
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] LOOP = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] dist_reg;
    reg [3:0] next_dist;
    reg [7:0] visited;
    reg [7:0] next_visited;
    reg [2:0] queue [0:7];
    reg [2:0] queue_head;
    reg [2:0] next_queue_head;
    reg [2:0] queue_tail;
    reg [2:0] next_queue_tail;
    reg [15:0] cycle_count;
    reg [15:0] next_cycle_count;
    
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
        next_cycle_count = cycle_count + 16'd1;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                    next_cycle_count = 16'd0;
                end
            end
            
            INIT: begin
                // Initialize queue with start node
                queue[0] = s;
                next_queue_head = 3'd0;
                next_queue_tail = 3'd1;
                next_visited = (1'b1 << s);
                next_dist = 4'd0;
                
                if (s == t) begin
                    next_state = FINISH;
                end else begin
                    next_state = LOOP;
                end
            end
            
            LOOP: begin
                if (queue_head == queue_tail || cycle_count >= MAX_CYCLES) begin
                    // Queue empty or timeout - no path
                    next_state = FINISH;
                end else begin
                    // Process current node
                    if (current_node == t) begin
                        next_state = FINISH;
                    end else begin
                        // Add unvisited neighbors to queue
                        if (queue_head < 7) begin
                            next_queue_head = queue_head + 3'd1;
                        end
                        
                        // Check all possible neighbors
                        for (integer i = 0; i < 8; i = i + 1) begin
                            if (adj[current_node][i] && !visited[i]) begin
                                if (next_queue_tail < 8) begin
                                    queue[next_queue_tail] = i;
                                    next_queue_tail = next_queue_tail + 3'd1;
                                    next_visited[i] = 1'b1;
                                end
                            end
                        end
                        
                        next_dist = dist_reg + 4'd1;
                    end
                end
            end
            
            FINISH: begin
                // Hold state
                next_state = FINISH;
            end
            
            default: next_state = IDLE;
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
            cycle_count <= 16'd0;
            result <= 4'd0;
            done <= 1'b0;
            impossible <= 1'b0;
        end else begin
            state <= next_state;
            dist_reg <= next_dist;
            visited <= next_visited;
            queue_head <= next_queue_head;
            queue_tail <= next_queue_tail;
            cycle_count <= next_cycle_count;
            
            if (state == FINISH) begin
                done <= 1'b1;
                if (queue_head == queue_tail) begin
                    impossible <= 1'b1;
                    result <= 4'd0;
                end else begin
                    impossible <= 1'b0;
                    result <= dist_reg;
                end
            end else begin
                done <= 1'b0;
                impossible <= 1'b0;
            end
        end
    end
endmodule