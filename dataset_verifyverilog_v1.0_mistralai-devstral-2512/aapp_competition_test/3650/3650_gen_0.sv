module sliding_blocks(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] target_blocks_x [0:15],
    input wire [3:0] target_blocks_y [0:15],
    input wire [15:0] block_valid,
    input wire [3:0] initial_x,
    input wire [3:0] initial_y,
    output reg possible,
    output reg done,
    output reg [31:0] move_sequence,
    output reg [3:0] move_count
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] PROCESS   = 3'd2;
    localparam [2:0] CHECK     = 3'd3;
    localparam [2:0] VALIDATE  = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    reg [2:0] state, next_state;

    // Internal registers
    reg [3:0] current_block_idx;
    reg [3:0] visited_count;
    reg [15:0][15:0] visited_grid;
    reg [3:0] parent_x, parent_y;
    reg [3:0] current_x, current_y;
    reg [3:0] temp_x, temp_y;
    reg [3:0] cycle_count;
    reg [3:0] i, j;
    reg [3:0] dx, dy;
    reg [3:0] slide_dir;
    reg [3:0] move_idx;
    reg [31:0] temp_sequence;

    // Constants
    localparam [7:0] MAX_CYCLES = 8'd256;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            possible <= 1'b0;
            done <= 1'b0;
            move_sequence <= 32'd0;
            move_count <= 4'd0;
            current_block_idx <= 4'd0;
            visited_count <= 4'd0;
            cycle_count <= 8'd0;
            
            // Initialize visited grid
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    visited_grid[i][j] <= 1'b0;
                end
            end
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
                    next_state = INIT;
                end
            end
            
            INIT: begin
                next_state = PROCESS;
            end
            
            PROCESS: begin
                if (visited_count == 16'd16 || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK;
                end
            end
            
            CHECK: begin
                next_state = VALIDATE;
            end
            
            VALIDATE: begin
                next_state = PROCESS;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized in reset
        end else begin
            case (state)
                INIT: begin
                    // Mark initial block as visited
                    visited_grid[initial_x][initial_y] <= 1'b1;
                    visited_count <= 4'd1;
                    current_block_idx <= 4'd1;
                    cycle_count <= 8'd0;
                    move_count <= 4'd0;
                    move_sequence <= 32'd0;
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if all blocks are processed
                    if (current_block_idx == 16'd16) begin
                        possible <= 1'b1;
                    end
                end
                
                CHECK: begin
                    // Find next valid block
                    if (block_valid[current_block_idx]) begin
                        current_x <= target_blocks_x[current_block_idx];
                        current_y <= target_blocks_y[current_block_idx];
                        
                        // Find parent block (already visited)
                        for (i = 0; i < 16; i = i + 1) begin
                            for (j = 0; j < 16; j = j + 1) begin
                                if (visited_grid[i][j]) begin
                                    parent_x <= i;
                                    parent_y <= j;
                                end
                            end
                        end
                    end else begin
                        current_block_idx <= current_block_idx + 4'd1;
                    end
                end
                
                VALIDATE: begin
                    // Check adjacency and slide path
                    dx <= current_x - parent_x;
                    dy <= current_y - parent_y;
                    
                    // Manhattan distance check
                    if ((dx == 4'd1 && dy == 4'd0) || (dx == 4'd0 && dy == 4'd1) ||
                        (dx == 4'd0 && dy == 4'd15) || (dx == 4'd15 && dy == 4'd0)) begin
                        
                        // Check slide path is clear
                        reg path_clear;
                        path_clear = 1'b1;
                        
                        if (dx == 4'd1) begin
                            for (i = parent_x + 4'd1; i < current_x; i = i + 1) begin
                                if (visited_grid[i][current_y]) begin
                                    path_clear = 1'b0;
                                end
                            end
                        end else if (dx == 4'd15) begin
                            for (i = parent_x - 4'd1; i > current_x; i = i - 1) begin
                                if (visited_grid[i][current_y]) begin
                                    path_clear = 1'b0;
                                end
                            end
                        end else if (dy == 4'd1) begin
                            for (j = parent_y + 4'd1; j < current_y; j = j + 1) begin
                                if (visited_grid[current_x][j]) begin
                                    path_clear = 1'b0;
                                end
                            end
                        end else if (dy == 4'd15) begin
                            for (j = parent_y - 4'd1; j > current_y; j = j - 1) begin
                                if (visited_grid[current_x][j]) begin
                                    path_clear = 1'b0;
                                end
                            end
                        end
                        
                        if (path_clear) begin
                            visited_grid[current_x][current_y] <= 1'b1;
                            visited_count <= visited_count + 4'd1;
                            
                            // Record move
                            move_sequence <= move_sequence + (current_block_idx << (move_count * 4'd4));
                            move_count <= move_count + 4'd1;
                        end
                    end
                    
                    current_block_idx <= current_block_idx + 4'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule