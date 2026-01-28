module LavaPathfinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] step_elsa,
    input wire [7:0] step_father,
    input wire [1:0] map_in,
    input wire [7:0] map_addr,
    input wire map_write,
    output reg [1:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] DONE    = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Map storage (16x16 grid, 256 cells)
    reg [1:0] map [0:255];
    
    // BFS structures
    reg [7:0] elsa_queue [0:255];
    reg [7:0] father_queue [0:255];
    reg [7:0] elsa_queue_ptr, elsa_queue_size;
    reg [7:0] father_queue_ptr, father_queue_size;
    reg [7:0] next_elsa_queue_ptr, next_father_queue_ptr;
    
    // Visited flags
    reg elsa_visited [0:255];
    reg father_visited [0:255];
    
    // Current processing
    reg [7:0] current_elsa, current_father;
    reg [3:0] current_x, current_y;
    reg [3:0] neighbor_x, neighbor_y;
    reg [7:0] neighbor_addr;
    
    // Results
    reg [7:0] elsa_depth, father_depth;
    reg elsa_found, father_found;
    
    // Counters
    reg [7:0] load_counter;
    reg [7:0] compute_counter;
    reg [3:0] x_counter, y_counter;
    
    // Distance calculations
    reg [8:0] dx, dy;
    reg [8:0] dx_sq, dy_sq, dist_sq;
    reg [8:0] manhattan_dist;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 2'd0;
            done <= 1'b0;
            
            // Initialize map
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                map[i] <= 2'd3; // Default to lava
            end
            
            // Initialize queues
            elsa_queue_ptr <= 8'd0;
            elsa_queue_size <= 8'd0;
            father_queue_ptr <= 8'd0;
            father_queue_size <= 8'd0;
            next_elsa_queue_ptr <= 8'd0;
            next_father_queue_ptr <= 8'd0;
            
            // Initialize visited
            for (i = 0; i < 256; i = i + 1) begin
                elsa_visited[i] <= 1'b0;
                father_visited[i] <= 1'b0;
            end
            
            // Initialize results
            elsa_depth <= 8'd0;
            father_depth <= 8'd0;
            elsa_found <= 1'b0;
            father_found <= 1'b0;
            
            // Initialize counters
            load_counter <= 8'd0;
            compute_counter <= 8'd0;
            x_counter <= 4'd0;
            y_counter <= 4'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                if (load_counter == 8'd255) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                if ((elsa_found && father_found) || 
                    (elsa_queue_size == 8'd0 && father_queue_size == 8'd0) ||
                    compute_counter == 8'd255) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Load map data
    always @(posedge clk) begin
        if (state == LOAD && map_write) begin
            map[map_addr] <= map_in;
            load_counter <= load_counter + 8'd1;
        end
    end
    
    // BFS computation
    always @(posedge clk) begin
        if (state == COMPUTE) begin
            compute_counter <= compute_counter + 8'd1;
            
            // Process Elsa's queue
            if (elsa_queue_size > 8'd0 && !elsa_found) begin
                current_elsa <= elsa_queue[elsa_queue_ptr];
                elsa_queue_ptr <= elsa_queue_ptr + 8'd1;
                elsa_queue_size <= elsa_queue_size - 8'd1;
                
                current_x <= current_elsa[7:4];
                current_y <= current_elsa[3:0];
                
                // Check if goal reached
                if (map[current_elsa] == 2'd2) begin
                    elsa_found <= 1'b1;
                end
            end
            
            // Process Father's queue
            if (father_queue_size > 8'd0 && !father_found) begin
                current_father <= father_queue[father_queue_ptr];
                father_queue_ptr <= father_queue_ptr + 8'd1;
                father_queue_size <= father_queue_size - 8'd1;
                
                current_x <= current_father[7:4];
                current_y <= current_father[3:0];
                
                // Check if goal reached
                if (map[current_father] == 2'd2) begin
                    father_found <= 1'b1;
                end
            end
            
            // Neighbor checking
            if (elsa_queue_size > 8'd0 || father_queue_size > 8'd0) begin
                // Generate neighbor coordinates
                if (x_counter == 4'd0 && y_counter == 4'd0) begin
                    neighbor_x <= current_x;
                    neighbor_y <= current_y;
                end else if (x_counter == 4'd0 && y_counter == 4'd1) begin
                    neighbor_x <= current_x - 4'd1;
                    neighbor_y <= current_y - 4'd1;
                end else if (x_counter == 4'd0 && y_counter == 4'd2) begin
                    neighbor_x <= current_x - 4'd1;
                    neighbor_y <= current_y;
                end else if (x_counter == 4'd0 && y_counter == 4'd3) begin
                    neighbor_x <= current_x - 4'd1;
                    neighbor_y <= current_y + 4'd1;
                end else if (x_counter == 4'd1 && y_counter == 4'd0) begin
                    neighbor_x <= current_x;
                    neighbor_y <= current_y - 4'd1;
                end else if (x_counter == 4'd1 && y_counter == 4'd1) begin
                    neighbor_x <= current_x;
                    neighbor_y <= current_y;
                end else if (x_counter == 4'd1 && y_counter == 4'd2) begin
                    neighbor_x <= current_x;
                    neighbor_y <= current_y + 4'd1;
                end else if (x_counter == 4'd1 && y_counter == 4'd3) begin
                    neighbor_x <= current_x + 4'd1;
                    neighbor_y <= current_y - 4'd1;
                end else if (x_counter == 4'd2 && y_counter == 4'd0) begin
                    neighbor_x <= current_x + 4'd1;
                    neighbor_y <= current_y;
                end else if (x_counter == 4'd2 && y_counter == 4'd1) begin
                    neighbor_x <= current_x + 4'd1;
                    neighbor_y <= current_y + 4'd1;
                end
                
                // Check bounds
                if (neighbor_x < 4'd16 && neighbor_y < 4'd16) begin
                    neighbor_addr <= {neighbor_x, neighbor_y};
                    
                    // Check if valid cell
                    if (map[neighbor_addr] == 2'd1 || map[neighbor_addr] == 2'd2) begin
                        // Elsa's movement check (Euclidean)
                        dx <= neighbor_x - current_x;
                        dy <= neighbor_y - current_y;
                        dx_sq <= dx * dx;
                        dy_sq <= dy * dy;
                        dist_sq <= dx_sq + dy_sq;
                        
                        if (!elsa_visited[neighbor_addr] && 
                            dist_sq <= (step_elsa * step_elsa)) begin
                            elsa_queue[next_elsa_queue_ptr] <= neighbor_addr;
                            next_elsa_queue_ptr <= next_elsa_queue_ptr + 8'd1;
                            elsa_visited[neighbor_addr] <= 1'b1;
                        end
                        
                        // Father's movement check (Manhattan)
                        manhattan_dist <= (neighbor_x - current_x) + (neighbor_y - current_y);
                        
                        if (!father_visited[neighbor_addr] && 
                            manhattan_dist <= step_father) begin
                            father_queue[next_father_queue_ptr] <= neighbor_addr;
                            next_father_queue_ptr <= next_father_queue_ptr + 8'd1;
                            father_visited[neighbor_addr] <= 1'b1;
                        end
                    end
                end
                
                // Update counters
                if (y_counter == 4'd3) begin
                    y_counter <= 4'd0;
                    if (x_counter == 4'd2) begin
                        x_counter <= 4'd0;
                        
                        // Update queue sizes
                        if (elsa_queue_size == 8'd0) begin
                            elsa_queue_size <= next_elsa_queue_ptr;
                            next_elsa_queue_ptr <= 8'd0;
                            elsa_queue_ptr <= 8'd0;
                            elsa_depth <= elsa_depth + 8'd1;
                        end
                        
                        if (father_queue_size == 8'd0) begin
                            father_queue_size <= next_father_queue_ptr;
                            next_father_queue_ptr <= 8'd0;
                            father_queue_ptr <= 8'd0;
                            father_depth <= father_depth + 8'd1;
                        end
                    end else begin
                        x_counter <= x_counter + 4'd1;
                    end
                end else begin
                    y_counter <= y_counter + 4'd1;
                end
            end
        end
    end
    
    // Result determination
    always @(posedge clk) begin
        if (state == DONE) begin
            if (elsa_found && father_found) begin
                if (elsa_depth == father_depth) begin
                    result <= 2'd1; // SUCCESS
                end else if (elsa_depth < father_depth) begin
                    result <= 2'd2; // GO FOR IT
                end else begin
                    result <= 2'd3; // NO CHANCE
                end
            end else if (elsa_found) begin
                result <= 2'd2; // GO FOR IT
            end else if (father_found) begin
                result <= 2'd3; // NO CHANCE
            end else begin
                result <= 2'd0; // NO WAY
            end
            
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end
    
    // Initialize start positions
    always @(posedge clk) begin
        if (state == COMPUTE && compute_counter == 8'd0) begin
            // Find start position
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                if (map[i] == 2'd0) begin
                    elsa_queue[0] <= i;
                    elsa_queue_size <= 8'd1;
                    elsa_visited[i] <= 1'b1;
                    
                    father_queue[0] <= i;
                    father_queue_size <= 8'd1;
                    father_visited[i] <= 1'b1;
                end
            end
        end
    end

endmodule