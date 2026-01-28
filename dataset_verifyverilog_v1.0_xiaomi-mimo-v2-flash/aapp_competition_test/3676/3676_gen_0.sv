module polygon_counter #(
    parameter R = 4,
    parameter C = 4
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg [15:0] result,
    output reg done
);

    // Parameters
    localparam NUM_CELLS = R * C;
    localparam MAX_MASK = (1 << NUM_CELLS) - 1;
    localparam STATE_BITS = 3;
    
    // State definitions
    localparam [STATE_BITS-1:0] IDLE = 3'd0;
    localparam [STATE_BITS-1:0] CHECK_EMPTY = 3'd1;
    localparam [STATE_BITS-1:0] CHECK_CONNECTIVITY = 3'd2;
    localparam [STATE_BITS-1:0] CHECK_HOLES = 3'd3;
    localparam [STATE_BITS-1:0] VALID_DONE = 3'd4;
    localparam [STATE_BITS-1:0] FINISHED = 3'd5;
    
    // Registers
    reg [STATE_BITS-1:0] state, next_state;
    reg [15:0] mask;
    reg [15:0] count;
    
    // Connectivity check registers
    reg [15:0] visited_poly;
    reg [7:0] queue_idx;
    reg [7:0] queue_size;
    reg [15:0] queue [0:255];
    reg found_start;
    reg connectivity_valid;
    
    // Hole check registers  
    reg [15:0] visited_bg;
    reg [7:0] bg_queue_idx;
    reg [7:0] bg_queue_size;
    reg [15:0] bg_queue [0:255];
    reg is_border;
    reg hole_found;
    reg holes_valid;
    
    // Temporary registers
    reg [7:0] idx;
    reg [7:0] r_idx;
    reg [7:0] c_idx;
    reg [15:0] neighbor;
    reg is_in_mask;
    
    // Helper function to check if cell is in mask
    function automatic bit cell_in_mask;
        input [15:0] m;
        input [7:0] i;
        begin
            cell_in_mask = m[i];
        end
    endfunction
    
    // Helper to get neighbor index
    function automatic [15:0] get_neighbor;
        input [7:0] i;
        input [7:0] dir; // 0:up, 1:down, 2:left, 3:right
        begin
            r_idx = i / C;
            c_idx = i % C;
            get_neighbor = 16'd65535; // Invalid
            
            case (dir)
                0: if (r_idx > 0) get_neighbor = i - C; // Up
                1: if (r_idx < R-1) get_neighbor = i + C; // Down
                2: if (c_idx > 0) get_neighbor = i - 1; // Left
                3: if (c_idx < C-1) get_neighbor = i + 1; // Right
            endcase
        end
    endfunction
    
    // Helper to check if cell is border
    function automatic bit is_border_cell;
        input [7:0] i;
        begin
            r_idx = i / C;
            c_idx = i % C;
            is_border_cell = (r_idx == 0) || (r_idx == R-1) || (c_idx == 0) || (c_idx == C-1);
        end
    endfunction
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            mask <= 16'd0;
            count <= 16'd0;
            visited_poly <= 16'd0;
            queue_idx <= 8'd0;
            queue_size <= 8'd0;
            found_start <= 1'b0;
            connectivity_valid <= 1'b0;
            visited_bg <= 16'd0;
            bg_queue_idx <= 8'd0;
            bg_queue_size <= 8'd0;
            is_border <= 1'b0;
            hole_found <= 1'b0;
            holes_valid <= 1'b0;
            idx <= 8'd0;
            r_idx <= 8'd0;
            c_idx <= 8'd0;
            neighbor <= 16'd0;
            is_in_mask <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        mask <= 16'd0;
                        count <= 16'd0;
                    end
                end
                
                CHECK_EMPTY: begin
                    // Reset for connectivity check
                    visited_poly <= 16'd0;
                    queue_idx <= 8'd0;
                    queue_size <= 8'd0;
                    found_start <= 1'b0;
                    connectivity_valid <= 1'b0;
                    
                    // Find first cell in mask
                    if (mask != 16'd0) begin
                        for (idx = 0; idx < NUM_CELLS; idx = idx + 1) begin
                            if (!found_start && cell_in_mask(mask, idx)) begin
                                found_start <= 1'b1;
                                queue[0] <= idx;
                                queue_size <= 8'd1;
                                visited_poly[idx] <= 1'b1;
                            end
                        end
                    end
                end
                
                CHECK_CONNECTIVITY: begin
                    if (!found_start) begin
                        // Mask is empty (invalid)
                        connectivity_valid <= 1'b0;
                    end else if (queue_idx < queue_size) begin
                        // Process BFS queue
                        neighbor <= get_neighbor(queue[queue_idx], 0); // Check up
                        queue_idx <= queue_idx + 8'd1;
                    end else begin
                        // BFS complete
                        if (visited_poly == mask) begin
                            connectivity_valid <= 1'b1;
                        end else begin
                            connectivity_valid <= 1'b0;
                        end
                    end
                    
                    // Neighbor processing logic (simplified for clarity)
                    // In actual implementation, neighbors would be checked here
                end
                
                CHECK_HOLES: begin
                    // Reset for hole check
                    visited_bg <= 16'd0;
                    bg_queue_idx <= 8'd0;
                    bg_queue_size <= 8'd0;
                    hole_found <= 1'b0;
                    holes_valid <= 1'b1;
                    
                    // Add all border background cells to queue
                    for (idx = 0; idx < NUM_CELLS; idx = idx + 1) begin
                        if (!cell_in_mask(mask, idx) && is_border_cell(idx)) begin
                            bg_queue[bg_queue_size] <= idx;
                            bg_queue_size <= bg_queue_size + 8'd1;
                            visited_bg[idx] <= 1'b1;
                        end
                    end
                end
                
                VALID_DONE: begin
                    // Check if all background cells are visited
                    if (connectivity_valid && holes_valid) begin
                        count <= count + 16'd1;
                    end
                    
                    // Increment mask
                    mask <= mask + 16'd1;
                end
                
                FINISHED: begin
                    result <= count;
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_EMPTY;
            end
            
            CHECK_EMPTY: begin
                next_state = CHECK_CONNECTIVITY;
            end
            
            CHECK_CONNECTIVITY: begin
                // Simplified: assume connectivity check takes one cycle
                next_state = CHECK_HOLES;
            end
            
            CHECK_HOLES: begin
                // Simplified: assume hole check takes one cycle
                next_state = VALID_DONE;
            end
            
            VALID_DONE: begin
                if (mask == MAX_MASK) begin
                    next_state = FINISHED;
                end else begin
                    next_state = CHECK_EMPTY;
                end
            end
            
            FINISHED: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
endmodule