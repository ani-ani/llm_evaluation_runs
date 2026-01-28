module peg_board_checker (
    input clk,
    input rst_n,
    input start,
    input [15:0] start_grid,
    input [15:0] target_grid,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] CHECK_START  = 3'd1;
    localparam [2:0] INITIALIZE   = 3'd2;
    localparam [2:0] PROCESS_QUEUE = 3'd3;
    localparam [2:0] CHECK_TARGET = 3'd4;
    localparam [2:0] GENERATE_NEIGHBORS = 3'd5;
    localparam [2:0] CHECK_VISITED = 3'd6;
    localparam [2:0] FINISH       = 3'd7;

    reg [2:0] state, next_state;
    
    // Search state
    reg [15:0] current_state;
    reg [15:0] state_queue [0:255]; // Queue for BFS
    reg [7:0] queue_head;            // Points to current element
    reg [7:0] queue_tail;            // Points to next empty slot
    reg queue_empty;
    reg queue_full;
    
    // Visited states bitmap (65536 bits = 2048 32-bit words)
    reg [31:0] visited_bitmap [0:2047];
    
    // Neighbors generation
    reg [15:0] neighbor_state;
    reg [3:0] cell_idx;
    reg [1:0] row, col;
    reg [3:0] neighbor_idx;
    reg [15:0] flipped_state;
    
    // Control signals
    reg start_search;
    reg found_target;
    reg [9:0] cycle_count;  // Max 1024 cycles
    reg [4:0] neighbor_count; // 0-16 neighbors
    reg [15:0] temp_state;
    
    // Temp variables for combinational logic
    reg [15:0] check_mask;
    reg [15:0] flipped_mask;
    reg [31:0] word_idx;
    reg [4:0] bit_idx;
    reg [31:0] word_mask;
    reg word_exists;
    reg bit_set;
    reg [31:0] read_word;
    
    // Combinational logic for neighbor generation
    always @(*) begin
        // Calculate row and column from cell_idx
        row = cell_idx[3:2];
        col = cell_idx[1:0];
        
        // Base flip mask (horizontal and vertical neighbors)
        check_mask = 16'd0;
        
        // Center cell (always flipped)
        check_mask[4*row + col] = 1'b1;
        
        // Left neighbor
        if (col > 2'd0) begin
            check_mask[4*row + (col-1'b1)] = 1'b1;
        end
        // Right neighbor
        if (col < 2'd3) begin
            check_mask[4*row + (col+1'b1)] = 1'b1;
        end
        // Top neighbor
        if (row > 2'd0) begin
            check_mask[4*(row-1'b1) + col] = 1'b1;
        end
        // Bottom neighbor
        if (row < 2'd3) begin
            check_mask[4*(row+1'b1) + col] = 1'b1;
        end
        
        // Generate flipped state
        flipped_state = current_state ^ check_mask;
    end
    
    // Combinational logic for visited check
    always @(*) begin
        word_idx = neighbor_state[15:5]; // Divide by 32
        bit_idx = neighbor_state[4:0];   // Bit position
        word_mask = 32'd1 << bit_idx;
        
        read_word = visited_bitmap[word_idx];
        word_exists = (read_word & word_mask) != 32'd0;
    end
    
    // State register and reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_state <= 16'd0;
            result <= 1'b0;
            done <= 1'b0;
            queue_head <= 8'd0;
            queue_tail <= 8'd0;
            queue_empty <= 1'b1;
            queue_full <= 1'b0;
            cycle_count <= 10'd0;
            neighbor_count <= 5'd0;
            cell_idx <= 4'd0;
            start_search <= 1'b0;
            found_target <= 1'b0;
            // Initialize visited bitmap
            for (integer i = 0; i < 2048; i = i + 1) begin
                visited_bitmap[i] <= 32'd0;
            end
            // Initialize queue
            for (integer i = 0; i < 256; i = i + 1) begin
                state_queue[i] <= 16'd0;
            end
        end else begin
            // Default assignments
            done <= 1'b0;
            result <= result; // Keep result stable
            
            case (state)
                IDLE: begin
                    start_search <= 1'b0;
                    cycle_count <= 10'd0;
                    found_target <= 1'b0;
                    result <= 1'b0;
                    queue_head <= 8'd0;
                    queue_tail <= 8'd0;
                    queue_empty <= 1'b1;
                    queue_full <= 1'b0;
                    // Clear visited bitmap
                    for (integer i = 0; i < 2048; i = i + 1) begin
                        visited_bitmap[i] <= 32'd0;
                    end
                    // Clear queue
                    for (integer i = 0; i < 256; i = i + 1) begin
                        state_queue[i] <= 16'd0;
                    end
                    if (start) begin
                        start_search <= 1'b1;
                        current_state <= start_grid;
                    end
                end
                
                CHECK_START: begin
                    if (start_search) begin
                        if (current_state == target_grid) begin
                            found_target <= 1'b1;
                        end else begin
                            current_state <= start_grid;
                        end
                        start_search <= 1'b0;
                    end
                end
                
                INITIALIZE: begin
                    // Mark start as visited and enqueue
                    visited_bitmap[16'd0] <= visited_bitmap[16'd0] | (32'd1 << current_state[4:0]);
                    state_queue[8'd0] <= current_state;
                    queue_tail <= 8'd1;
                    queue_empty <= 1'b0;
                    cycle_count <= 10'd0;
                    cell_idx <= 4'd0;
                end
                
                PROCESS_QUEUE: begin
                    // Check queue state
                    queue_empty <= (queue_head == queue_tail);
                    queue_full <= ((queue_tail + 8'd1) == queue_head) || 
                                  ((queue_tail == 8'd255) && (queue_head == 8'd0));
                    
                    if (!queue_empty && cycle_count < 10'd1024) begin
                        // Dequeue current state
                        current_state <= state_queue[queue_head];
                        cell_idx <= 4'd0;
                        neighbor_count <= 5'd0;
                        cycle_count <= cycle_count + 10'd1;
                    end
                end
                
                CHECK_TARGET: begin
                    if (current_state == target_grid) begin
                        found_target <= 1'b1;
                    end
                    cell_idx <= cell_idx + 4'd1;
                    if (cell_idx == 4'd15) begin
                        cell_idx <= 4'd0; // Reset for next state
                    end
                end
                
                GENERATE_NEIGHBORS: begin
                    // Generate neighbor for current cell_idx
                    neighbor_state <= flipped_state;
                end
                
                CHECK_VISITED: begin
                    if (!word_exists) begin
                        // Mark as visited and enqueue
                        visited_bitmap[word_idx] <= visited_bitmap[word_idx] | word_mask;
                        state_queue[queue_tail] <= neighbor_state;
                        queue_tail <= queue_tail + 8'd1;
                    end
                    
                    cell_idx <= cell_idx + 4'd1;
                    if (cell_idx == 4'd15) begin
                        // Finished all cells for this state
                        queue_head <= queue_head + 8'd1;
                    end
                end
                
                FINISH: begin
                    result <= found_target;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start_search) begin
                    next_state = CHECK_START;
                end else begin
                    next_state = IDLE;
                end
            end
            
            CHECK_START: begin
                if (found_target) begin
                    next_state = FINISH;
                end else begin
                    next_state = INITIALIZE;
                end
            end
            
            INITIALIZE: begin
                next_state = PROCESS_QUEUE;
            end
            
            PROCESS_QUEUE: begin
                if (queue_empty || cycle_count >= 10'd1024) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK_TARGET;
                end
            end
            
            CHECK_TARGET: begin
                if (found_target) begin
                    next_state = FINISH;
                end else if (cell_idx == 4'd0) begin
                    next_state = PROCESS_QUEUE;
                end else begin
                    next_state = GENERATE_NEIGHBORS;
                end
            end
            
            GENERATE_NEIGHBORS: begin
                next_state = CHECK_VISITED;
            end
            
            CHECK_VISITED: begin
                if (cell_idx == 4'd0) begin
                    next_state = PROCESS_QUEUE;
                end else begin
                    next_state = GENERATE_NEIGHBORS;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule