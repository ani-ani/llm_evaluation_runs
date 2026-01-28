module sliding_blocks (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0][3:0] target_blocks_x,
    input wire [15:0][3:0] target_blocks_y,
    input wire [15:0] block_valid,
    input wire [3:0] initial_x,
    input wire [3:0] initial_y,
    output reg possible,
    output reg done,
    output reg [31:0] move_sequence,
    output reg [3:0] move_count
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_BLOCK = 3'd1;
    localparam [2:0] VERIFY_PATH = 3'd2;
    localparam [2:0] MARK_VISITED = 3'd3;
    localparam [2:0] FINISHED = 3'd4;
    localparam [2:0] FAILED = 3'd5;

    // Grid state (16x16 bits)
    reg [15:0] visited_grid [15:0];
    
    // Control registers
    reg [2:0] state, next_state;
    reg [3:0] current_block_idx;
    reg [3:0] parent_idx;
    reg [3:0] block_x, block_y;
    reg [3:0] parent_x, parent_y;
    reg [3:0] path_x, path_y;
    reg [3:0] i, j;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Path verification registers
    reg path_valid;
    reg [2:0] direction; // 0=left, 1=right, 2=up, 3=down

    // Move encoding
    // Each move: 4 bits for direction (0:L,1:R,2:U,3:D) + 4 bits for block index
    // Stored in 32-bit vector (max 4 moves, 8 bits each)
    reg [2:0] move_idx;
    
    integer k;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            possible <= 1'b0;
            done <= 1'b0;
            move_sequence <= 32'd0;
            move_count <= 4'd0;
            current_block_idx <= 4'd0;
            parent_idx <= 4'd0;
            cycle_count <= 8'd0;
            move_idx <= 3'd0;
            // Reset visited grid
            for (k = 0; k < 16; k = k + 1) begin
                visited_grid[k] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    possible <= 1'b0;
                    cycle_count <= 8'd0;
                    move_idx <= 3'd0;
                    move_sequence <= 32'd0;
                    move_count <= 4'd0;
                    
                    if (start) begin
                        // Initialize grid with initial block
                        visited_grid[initial_y] <= (16'd1 << initial_x);
                        current_block_idx <= 4'd1; // Start from block 1 (0 is initial)
                        state <= CHECK_BLOCK;
                    end else begin
                        state <= IDLE;
                    end
                end

                CHECK_BLOCK: begin
                    if (current_block_idx >= 4'd15 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISHED;
                    end else if (block_valid[current_block_idx]) begin
                        // Load block coordinates
                        block_x <= target_blocks_x[current_block_idx];
                        block_y <= target_blocks_y[current_block_idx];
                        parent_idx <= 4'd0; // Reset parent search
                        state <= VERIFY_PATH;
                    end else begin
                        current_block_idx <= current_block_idx + 4'd1;
                        state <= CHECK_BLOCK;
                    end
                end

                VERIFY_PATH: begin
                    if (parent_idx >= 4'd15) begin
                        // No valid parent found for this block
                        state <= FAILED;
                    end else if (block_valid[parent_idx] && visited_grid[target_blocks_y[parent_idx]][target_blocks_x[parent_idx]]) begin
                        // Check if adjacent
                        parent_x <= target_blocks_x[parent_idx];
                        parent_y <= target_blocks_y[parent_idx];
                        
                        // Check Manhattan distance == 1
                        if ((block_x == parent_x && (block_y == parent_y + 4'd1 || block_y + 4'd1 == parent_y)) ||
                            (block_y == parent_y && (block_x == parent_x + 4'd1 || block_x + 4'd1 == parent_x))) begin
                            
                            // Determine direction and verify path
                            if (block_x == parent_x) begin
                                if (block_y > parent_y) begin // DOWN
                                    direction <= 3'd3;
                                    path_x <= block_x;
                                    path_y <= parent_y + 4'd1;
                                end else begin // UP
                                    direction <= 3'd2;
                                    path_x <= block_x;
                                    path_y <= block_y + 4'd1;
                                end
                            end else begin
                                if (block_x > parent_x) begin // RIGHT
                                    direction <= 3'd1;
                                    path_x <= parent_x + 4'd1;
                                    path_y <= block_y;
                                end else begin // LEFT
                                    direction <= 3'd0;
                                    path_x <= block_x + 4'd1;
                                    path_y <= block_y;
                                end
                            end
                            path_valid <= 1'b1;
                            i <= 4'd0; // Use i for path check loop
                            state <= MARK_VISITED;
                        end else begin
                            parent_idx <= parent_idx + 4'd1;
                            state <= VERIFY_PATH;
                        end
                    end else begin
                        parent_idx <= parent_idx + 4'd1;
                        state <= VERIFY_PATH;
                    end
                end

                MARK_VISITED: begin
                    // Check path until we reach parent or block
                    if (path_x == parent_x && path_y == parent_y) begin
                        // Path clear, mark block as visited
                        visited_grid[block_y] <= visited_grid[block_y] | (16'd1 << block_x);
                        
                        // Record move (simplified encoding)
                        if (move_idx < 3'd4) begin
                            move_sequence[move_idx * 8 +: 8] <= {direction, current_block_idx};
                            move_idx <= move_idx + 3'd1;
                            move_count <= move_count + 4'd1;
                        end
                        
                        current_block_idx <= current_block_idx + 4'd1;
                        cycle_count <= cycle_count + 8'd1;
                        state <= CHECK_BLOCK;
                    end else if (path_x == block_x && path_y == block_y) begin
                        // Reached target, path clear
                        visited_grid[block_y] <= visited_grid[block_y] | (16'd1 << block_x);
                        
                        if (move_idx < 3'd4) begin
                            move_sequence[move_idx * 8 +: 8] <= {direction, current_block_idx};
                            move_idx <= move_idx + 3'd1;
                            move_count <= move_count + 4'd1;
                        end
                        
                        current_block_idx <= current_block_idx + 4'd1;
                        cycle_count <= cycle_count + 8'd1;
                        state <= CHECK_BLOCK;
                    end else begin
                        // Check if this cell is occupied (blocking the path)
                        if (visited_grid[path_y][path_x]) begin
                            path_valid <= 1'b0;
                            parent_idx <= parent_idx + 4'd1;
                            state <= VERIFY_PATH;
                        end else begin
                            // Move to next cell in path
                            if (direction == 3'd0) path_x <= path_x + 4'd1; // LEFT (moving right to check)
                            else if (direction == 3'd1) path_x <= path_x + 4'd1; // RIGHT
                            else if (direction == 3'd2) path_y <= path_y + 4'd1; // UP (moving down to check)
                            else if (direction == 3'd3) path_y <= path_y - 4'd1; // DOWN
                            state <= MARK_VISITED;
                        end
                    end
                end

                FINISHED: begin
                    possible <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                FAILED: begin
                    possible <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule