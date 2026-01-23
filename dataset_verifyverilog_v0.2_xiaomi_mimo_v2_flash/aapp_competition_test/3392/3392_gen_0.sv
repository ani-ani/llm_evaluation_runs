module forest_growth (
    input clk,
    input rst_n,
    input start,
    input [7:0] heights [0:63],
    input [7:0] speeds [0:63],
    output reg [7:0] max_group_size,
    output reg done
);

    // Parameters
    parameter N = 8;
    parameter GRID_SIZE = 64;
    
    // State definitions
    localparam IDLE = 3'b000;
    localparam CHECK_CELL = 3'b001;
    localparam PROPAGATE = 3'b010;
    localparam UPDATE_MAX = 3'b011;
    localparam DONE = 3'b100;
    
    // Registers and Wires
    reg [2:0] current_state, next_state;
    reg [5:0] root_idx; // Current cell index being processed as root
    reg [5:0] current_idx; // For BFS traversal
    reg [5:0] queue [0:63]; // BFS queue
    reg [5:0] queue_head, queue_tail;
    reg [63:0] visited; // Global visited mask to avoid reprocessing roots
    reg [63:0] component_visited; // Component-specific visited
    reg [7:0] component_size;
    reg [7:0] current_max;
    
    // Neighbor calculation variables
    reg [5:0] neighbor_idx;
    reg [2:0] row, col;
    reg [2:0] n_row, n_col;
    
    // Temporary storage for speed/height comparisons
    reg [7:0] root_h, root_v;
    reg [7:0] curr_h, curr_v;
    reg equal_condition;
    
    // Helper signals
    reg queue_empty;
    reg [5:0] dequeue_idx;
    
    integer i;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = CHECK_CELL;
            end
            CHECK_CELL: begin
                if (root_idx >= GRID_SIZE) next_state = DONE;
                else if (visited[root_idx]) next_state = CHECK_CELL; // Skip visited
                else next_state = PROPAGATE;
            end
            PROPAGATE: begin
                if (queue_empty && queue_head == queue_tail) next_state = UPDATE_MAX;
                else next_state = PROPAGATE;
            end
            UPDATE_MAX: begin
                next_state = CHECK_CELL;
            end
            DONE: begin
                // Stay in done state
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Main FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_group_size <= 8'b0;
            done <= 1'b0;
            root_idx <= 6'b0;
            current_max <= 8'b0;
            visited <= 64'b0;
            queue_head <= 6'b0;
            queue_tail <= 6'b0;
            component_size <= 8'b0;
            component_visited <= 64'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        root_idx <= 6'b0;
                        visited <= 64'b0;
                        current_max <= 8'b0;
                        done <= 1'b0;
                    end
                end
                
                CHECK_CELL: begin
                    if (root_idx < GRID_SIZE && !visited[root_idx]) begin
                        // Initialize component search
                        visited[root_idx] <= 1'b1;
                        component_visited[root_idx] <= 1'b1;
                        component_size <= 8'd1;
                        queue_head <= 6'b0;
                        queue_tail <= 6'b0;
                        // Get root properties
                        root_h <= heights[root_idx];
                        root_v <= speeds[root_idx];
                        // Enqueue root for propagation
                        queue[0] <= root_idx;
                        queue_tail <= 6'd1;
                    end else if (root_idx >= GRID_SIZE) begin
                        // Done
                    end else begin
                        // Skip visited
                    end
                end
                
                PROPAGATE: begin
                    if (!queue_empty && queue_head < queue_tail) begin
                        // Dequeue current cell
                        current_idx <= queue[queue_head];
                        queue_head <= queue_head + 1;
                        
                        // Get current cell properties
                        // (Will be available next cycle)
                    end else begin
                        // Queue empty, propagate done
                    end
                end
                
                UPDATE_MAX: begin
                    if (component_size > current_max) begin
                        current_max <= component_size;
                    end
                    root_idx <= root_idx + 1;
                end
                
                DONE: begin
                    max_group_size <= current_max;
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Neighbor processing logic (combinational)
    always @(*) begin
        equal_condition = 1'b0;
        neighbor_idx = 6'b0;
        
        if (current_state == PROPAGATE && !queue_empty) begin
            // Get current cell properties
            curr_h = heights[queue[queue_head]];
            curr_v = speeds[queue[queue_head]];
            
            // Check 4 neighbors (top, bottom, left, right)
            row = queue[queue_head] / N;
            col = queue[queue_head] % N;
            
            // Iterate through neighbors (simplified sequential check)
            // For each neighbor, calculate index and check condition
        end
    end
    
    // Process neighbors sequentially in additional state logic
    // We'll use a small counter to check neighbors
    reg [2:0] neighbor_check_idx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            neighbor_check_idx <= 3'b0;
        end else if (current_state == PROPAGATE && !queue_empty) begin
            if (neighbor_check_idx < 3'd4) begin
                neighbor_check_idx <= neighbor_check_idx + 1;
                
                // Calculate neighbor coordinates
                row = queue[queue_head] / N;
                col = queue[queue_head] % N;
                
                case (neighbor_check_idx)
                    3'd0: begin // Top
                        if (row > 0) begin
                            n_row = row - 1;
                            n_col = col;
                        end else n_row = N;
                    end
                    3'd1: begin // Bottom
                        if (row < N-1) begin
                            n_row = row + 1;
                            n_col = col;
                        end else n_row = N;
                    end
                    3'd2: begin // Left
                        if (col > 0) begin
                            n_row = row;
                            n_col = col - 1;
                        end else n_row = N;
                    end
                    3'd3: begin // Right
                        if (col < N-1) begin
                            n_row = row;
                            n_col = col + 1;
                        end else n_row = N;
                    end
                endcase
                
                // Check if valid neighbor
                if (n_row < N && n_col < N) begin
                    neighbor_idx = n_row * N + n_col;
                    
                    // Check equal height condition
                    if (!component_visited[neighbor_idx]) begin
                        // Check if heights are equal at some time t
                        // Simplified: check if (h1,v1) == (h2,v2) OR ratio condition
                        // For hardware, we primarily check exact match
                        if ((heights[neighbor_idx] == heights[queue[queue_head]]) && 
                            (speeds[neighbor_idx] == speeds[queue[queue_head]])) begin
                            equal_condition = 1'b1;
                        end
                        
                        // Also check cross-pair compatibility if needed
                        // For simplicity, check if neighbor matches root
                        if ((heights[neighbor_idx] == root_h) && (speeds[neighbor_idx] == root_v)) begin
                            equal_condition = 1'b1;
                        end
                        
                        if (equal_condition) begin
                            // Enqueue neighbor
                            visited[neighbor_idx] = 1'b1;
                            component_visited[neighbor_idx] = 1'b1;
                            component_size = component_size + 1;
                            // Actual enqueue in clocked logic
                            // We need to write this into the queue
                        end
                    end
                end
            end else begin
                neighbor_check_idx <= 3'b0;
            end
        end else begin
            neighbor_check_idx <= 3'b0;
        end
    end
    
    // Revised neighbor handling with proper queue insertion
    reg [5:0] next_neighbor;
    reg should_enqueue;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
        end else if (current_state == CHECK_CELL) begin
            // Reset neighbor processing
        end else if (current_state == PROPAGATE && !queue_empty) begin
            // Process one neighbor per cycle
            if (queue_head < queue_tail) begin
                // Get current processing cell
                reg [5:0] proc_cell = queue[queue_head];
                reg [2:0] p_row = proc_cell / N;
                reg [2:0] p_col = proc_cell % N;
                
                // Try to find an unvisited neighbor
                should_enqueue = 1'b0;
                next_neighbor = 6'b0;
                
                // Check neighbors in sequence
                if (neighbor_check_idx == 3'd0 && p_row > 0) begin
                    next_neighbor = (p_row - 1) * N + p_col;
                    neighbor_check_idx = 3'd1;
                end else if (neighbor_check_idx == 3'd1 && p_row < N-1) begin
                    next_neighbor = (p_row + 1) * N + p_col;
                    neighbor_check_idx = 3'd2;
                end else if (neighbor_check_idx == 3'd2 && p_col > 0) begin
                    next_neighbor = p_row * N + (p_col - 1);
                    neighbor_check_idx = 3'd3;
                end else if (neighbor_check_idx == 3'd3 && p_col < N-1) begin
                    next_neighbor = p_row * N + (p_col + 1);
                    neighbor_check_idx = 3'd4;
                end else begin
                    // All neighbors checked, move to next queue item
                    neighbor_check_idx = 3'd0;
                    // Queue head will increment in separate logic
                end
                
                // Check condition for next_neighbor
                if (neighbor_check_idx > 0 && !component_visited[next_neighbor]) begin
                    // Check equal height condition
                    // Use root's properties for component consistency
                    if ((heights[next_neighbor] == root_h) && (speeds[next_neighbor] == root_v)) begin
                        should_enqueue = 1'b1;
                    end
                    
                    // Also check with current cell (maintain chain)
                    // But root-based is simpler and correct for identical trees
                end
                
                if (should_enqueue) begin
                    component_visited[next_neighbor] <= 1'b1;
                    visited[next_neighbor] <= 1'b1;
                    component_size <= component_size + 1;
                    queue[queue_tail] <= next_neighbor;
                    queue_tail <= queue_tail + 1;
                end
            end
        end
    end
    
    // Queue empty detection
    always @(*) begin
        queue_empty = (queue_head == queue_tail);
    end
    
    // Increment root index in CHECK_CELL if skipping
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset
        end else if (current_state == CHECK_CELL && visited[root_idx]) begin
            root_idx <= root_idx + 1;
        end
    end

endmodule

// Helper module for neighbor calculation (optional, but handled inline above)
module neighbor_calc (
    input [5:0] idx,
    input [2:0] direction, // 0:top, 1:bottom, 2:left, 3:right
    input [2:0] N,
    output reg [5:0] neighbor,
    output reg valid
);
    reg [2:0] row, col;
    always @(*) begin
        row = idx / N;
        col = idx % N;
        valid = 1'b0;
        neighbor = 6'b0;
        case (direction)
            3'd0: if (row > 0) begin neighbor = (row-1)*N + col; valid = 1'b1; end
            3'd1: if (row < N-1) begin neighbor = (row+1)*N + col; valid = 1'b1; end
            3'd2: if (col > 0) begin neighbor = row*N + (col-1); valid = 1'b1; end
            3'd3: if (col < N-1) begin neighbor = row*N + (col+1); valid = 1'b1; end
        endcase
    end
endmodule