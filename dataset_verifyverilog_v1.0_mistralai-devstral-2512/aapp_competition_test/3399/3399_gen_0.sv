module grid_partition(
    input clk,
    input rst_n,
    input start,
    input grid_valid,
    input [3:0] cell_data,
    input [7:0] cell_idx,
    output reg [255:0] result_a,
    output reg [255:0] result_b,
    output reg [255:0] result_c,
    output reg done,
    output reg possible
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Grid storage
    reg [255:0] grid_type1;  // '1' constraint cells
    reg [255:0] grid_type2;  // '2' constraint cells

    // Internal signals
    reg [7:0] load_counter;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // Region assignment
    reg [255:0] region_a;
    reg [255:0] region_b;
    reg [255:0] region_c;

    // BFS/DFS state
    reg [7:0] current_cell;
    reg [7:0] queue [0:255];
    reg [7:0] queue_head, queue_tail;
    reg [7:0] visited [0:255];

    // Connectivity check
    reg [255:0] temp_region;
    reg [7:0] connectivity_counter;
    reg region_connected;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            load_counter <= 8'd0;
            cycle_count <= 16'd0;
            grid_type1 <= 256'd0;
            grid_type2 <= 256'd0;
            region_a <= 256'd0;
            region_b <= 256'd0;
            region_c <= 256'd0;
            current_cell <= 8'd0;
            queue_head <= 8'd0;
            queue_tail <= 8'd0;
            for (integer i = 0; i < 256; i = i + 1) begin
                visited[i] <= 8'd0;
            end
            connectivity_counter <= 8'd0;
            region_connected <= 1'b0;
            done <= 1'b0;
            possible <= 1'b1;
        end else begin
            state <= next_state;
        end
    end

    // Load phase: store grid constraints
    always @(posedge clk) begin
        if (state == LOAD && grid_valid) begin
            if (load_counter < 8'd256) begin
                grid_type1[load_counter] <= cell_data[0];
                grid_type2[load_counter] <= cell_data[1];
                load_counter <= load_counter + 8'd1;
            end
            if (load_counter == 8'd255) begin
                next_state <= COMPUTE;
            end
        end
    end

    // Compute phase: assign regions
    always @(posedge clk) begin
        if (state == COMPUTE) begin
            cycle_count <= cycle_count + 16'd1;

            // Simple greedy assignment
            if (cycle_count == 16'd1) begin
                // Initialize regions
                region_a <= 256'd0;
                region_b <= 256'd0;
                region_c <= 256'd0;

                // Assign type1 cells to single regions
                for (integer i = 0; i < 256; i = i + 1) begin
                    if (grid_type1[i]) begin
                        if (i < 8'd85) begin
                            region_a[i] <= 1'b1;
                        end else if (i < 8'd170) begin
                            region_b[i] <= 1'b1;
                        end else begin
                            region_c[i] <= 1'b1;
                        end
                    end
                end

                // Assign type2 cells to multiple regions
                for (integer i = 0; i < 256; i = i + 1) begin
                    if (grid_type2[i]) begin
                        if (i < 8'd85) begin
                            region_a[i] <= 1'b1;
                            region_b[i] <= 1'b1;
                        end else if (i < 8'd170) begin
                            region_b[i] <= 1'b1;
                            region_c[i] <= 1'b1;
                        end else begin
                            region_c[i] <= 1'b1;
                            region_a[i] <= 1'b1;
                        end
                    end
                end

                // Ensure all cells are assigned
                for (integer i = 0; i < 256; i = i + 1) begin
                    if (!grid_type1[i] && !grid_type2[i]) begin
                        if (i < 8'd85) begin
                            region_a[i] <= 1'b1;
                        end else if (i < 8'd170) begin
                            region_b[i] <= 1'b1;
                        end else begin
                            region_c[i] <= 1'b1;
                        end
                    end
                end

                // Check connectivity
                region_connected <= 1'b1;
                
                // Check region A connectivity
                temp_region <= region_a;
                connectivity_counter <= 8'd0;
                for (integer i = 0; i < 256; i = i + 1) begin
                    if (temp_region[i]) begin
                        connectivity_counter <= connectivity_counter + 8'd1;
                        break;
                    end
                end
                
                if (connectivity_counter > 8'd0) begin
                    // BFS for connectivity
                    queue_head <= 8'd0;
                    queue_tail <= 8'd0;
                    for (integer i = 0; i < 256; i = i + 1) begin
                        visited[i] <= 8'd0;
                    end
                    
                    for (integer i = 0; i < 256; i = i + 1) begin
                        if (temp_region[i]) begin
                            queue[queue_tail] <= i;
                            queue_tail <= queue_tail + 8'd1;
                            visited[i] <= 8'd1;
                            break;
                        end
                    end
                    
                    while (queue_head < queue_tail) begin
                        current_cell <= queue[queue_head];
                        queue_head <= queue_head + 8'd1;
                        
                        // Check neighbors
                        integer x = current_cell % 16;
                        integer y = current_cell / 16;
                        
                        // Up
                        if (y > 0) begin
                            integer neighbor = (y - 1) * 16 + x;
                            if (temp_region[neighbor] && !visited[neighbor]) begin
                                queue[queue_tail] <= neighbor;
                                queue_tail <= queue_tail + 8'd1;
                                visited[neighbor] <= 8'd1;
                            end
                        end
                        
                        // Down
                        if (y < 15) begin
                            integer neighbor = (y + 1) * 16 + x;
                            if (temp_region[neighbor] && !visited[neighbor]) begin
                                queue[queue_tail] <= neighbor;
                                queue_tail <= queue_tail + 8'd1;
                                visited[neighbor] <= 8'd1;
                            end
                        end
                        
                        // Left
                        if (x > 0) begin
                            integer neighbor = y * 16 + (x - 1);
                            if (temp_region[neighbor] && !visited[neighbor]) begin
                                queue[queue_tail] <= neighbor;
                                queue_tail <= queue_tail + 8'd1;
                                visited[neighbor] <= 8'd1;
                            end
                        end
                        
                        // Right
                        if (x < 15) begin
                            integer neighbor = y * 16 + (x + 1);
                            if (temp_region[neighbor] && !visited[neighbor]) begin
                                queue[queue_tail] <= neighbor;
                                queue_tail <= queue_tail + 8'd1;
                                visited[neighbor] <= 8'd1;
                            end
                        end
                    end
                    
                    // Check if all cells visited
                    for (integer i = 0; i < 256; i = i + 1) begin
                        if (temp_region[i] && !visited[i]) begin
                            region_connected <= 1'b0;
                        end
                    end
                end
                
                // Repeat for regions B and C
                temp_region <= region_b;
                connectivity_counter <= 8'd0;
                for (integer i = 0; i < 256; i = i + 1) begin
                    if (temp_region[i]) begin
                        connectivity_counter <= connectivity_counter + 8'd1;
                        break;
                    end
                end
                
                if (connectivity_counter > 8'd0) begin
                    queue_head <= 8'd0;
                    queue_tail <= 8'd0;
                    for (integer i = 0; i < 256; i = i + 1) begin
                        visited[i] <= 8'd0;
                    end
                    
                    for (integer i = 0; i < 256; i = i + 1) begin
                        if (temp_region[i]) begin
                            queue[queue_tail] <= i;
                            queue_tail <= queue_tail + 8'd1;
                            visited[i] <= 8'd1;
                            break;
                        end
                    end
                    
                    while (queue_head < queue_tail) begin
                        current_cell <= queue[queue_head];
                        queue_head <= queue_head + 8'd1;
                        
                        integer x = current_cell % 16;
                        integer y = current_cell / 16;
                        
                        if (y > 0) begin
                            integer neighbor = (y - 1) * 16 + x;
                            if (temp_region[neighbor] && !visited[neighbor]) begin
                                queue[queue_tail] <= neighbor;
                                queue_tail <= queue_tail + 8'd1;
                                visited[neighbor] <= 8'd1;
                            end
                        end
                        
                        if (y < 15) begin
                            integer neighbor = (y + 1) * 16 + x;
                            if (temp_region[neighbor] && !visited[neighbor]) begin
                                queue[queue_tail] <= neighbor;
                                queue_tail <= queue_tail + 8'd1;
                                visited[neighbor] <= 8'd1;
                            end
                        end
                        
                        if (x > 0) begin
                            integer neighbor = y * 16 + (x - 1);
                            if (temp_region[neighbor] && !visited[neighbor]) begin
                                queue[queue_tail] <= neighbor;
                                queue_tail <= queue_tail + 8'd1;
                                visited[neighbor] <= 8'd1;
                            end
                        end
                        
                        if (x < 15) begin
                            integer neighbor = y * 16 + (x + 1);
                            if (temp_region[neighbor] && !visited[neighbor]) begin
                                queue[queue_tail] <= neighbor;
                                queue_tail <= queue_tail + 8'd1;
                                visited[neighbor] <= 8'd1;
                            end
                        end
                    end
                    
                    for (integer i = 0; i < 256; i = i + 1) begin
                        if (temp_region[i] && !visited[i]) begin
                            region_connected <= 1'b0;
                        end
                    end
                end
                
                temp_region <= region_c;
                connectivity_counter <= 8'd0;
                for (integer i = 0; i < 256; i = i + 1) begin
                    if (temp_region[i]) begin
                        connectivity_counter <= connectivity_counter + 8'd1;
                        break;
                    end
                end
                
                if (connectivity_counter > 8'd0) begin
                    queue_head <= 8'd0;
                    queue_tail <= 8'd0;
                    for (integer i = 0; i < 256; i = i + 1) begin
                        visited[i] <= 8'd0;
                    end
                    
                    for (integer i = 0; i < 256; i = i + 1) begin
                        if (temp_region[i]) begin
                            queue[queue_tail] <= i;
                            queue_tail <= queue_tail + 8'd1;
                            visited[i] <= 8'd1;
                            break;
                        end
                    end
                    
                    while (queue_head < queue_tail) begin
                        current_cell <= queue[queue_head];
                        queue_head <= queue_head + 8'd1;
                        
                        integer x = current_cell % 16;
                        integer y = current_cell / 16;
                        
                        if (y > 0) begin
                            integer neighbor = (y - 1) * 16 + x;
                            if (temp_region[neighbor] && !visited[neighbor]) begin
                                queue[queue_tail] <= neighbor;
                                queue_tail <= queue_tail + 8'd1;
                                visited[neighbor] <= 8'd1;
                            end
                        end
                        
                        if (y < 15) begin
                            integer neighbor = (y + 1) * 16 + x;
                            if (temp_region[neighbor] && !visited[neighbor]) begin
                                queue[queue_tail] <= neighbor;
                                queue_tail <= queue_tail + 8'd1;
                                visited[neighbor] <= 8'd1;
                            end
                        end
                        
                        if (x > 0) begin
                            integer neighbor = y * 16 + (x - 1);
                            if (temp_region[neighbor] && !visited[neighbor]) begin
                                queue[queue_tail] <= neighbor;
                                queue_tail <= queue_tail + 8'd1;
                                visited[neighbor] <= 8'd1;
                            end
                        end
                        
                        if (x < 15) begin
                            integer neighbor = y * 16 + (x + 1);
                            if (temp_region[neighbor] && !visited[neighbor]) begin
                                queue[queue_tail] <= neighbor;
                                queue_tail <= queue_tail + 8'd1;
                                visited[neighbor] <= 8'd1;
                            end
                        end
                    end
                    
                    for (integer i = 0; i < 256; i = i + 1) begin
                        if (temp_region[i] && !visited[i]) begin
                            region_connected <= 1'b0;
                        end
                    end
                end
                
                if (region_connected) begin
                    next_state <= OUTPUT;
                end else if (cycle_count >= MAX_CYCLES) begin
                    possible <= 1'b0;
                    next_state <= DONE_STATE;
                end
            end
        end
    end

    // Output phase
    always @(posedge clk) begin
        if (state == OUTPUT) begin
            result_a <= region_a;
            result_b <= region_b;
            result_c <= region_c;
            next_state <= DONE_STATE;
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
            next_state <= IDLE;
        end else begin
            done <= 1'b0;
        end
    end

    // State transition
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            LOAD: begin
                if (load_counter == 8'd256) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = LOAD;
                end
            end
            COMPUTE: begin
                if (region_connected || cycle_count >= MAX_CYCLES) begin
                    if (region_connected) begin
                        next_state = OUTPUT;
                    end else begin
                        next_state = DONE_STATE;
                    end
                end else begin
                    next_state = COMPUTE;
                end
            end
            OUTPUT: next_state = DONE_STATE;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule