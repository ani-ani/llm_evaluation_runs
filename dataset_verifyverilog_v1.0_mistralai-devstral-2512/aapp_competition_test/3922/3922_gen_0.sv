module alien_surgery(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [7:0] arr_8,
    input wire [7:0] arr_9,
    input wire [7:0] arr_10,
    input wire [7:0] arr_11,
    input wire [7:0] arr_12,
    input wire [7:0] arr_13,
    output reg [7:0] result,
    output reg done,
    output reg [511:0] moves_out
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SOLVE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Grid representation (14 cells)
    reg [7:0] grid [0:13];
    
    // Target configuration for k=3 (2x7 grid)
    localparam [7:0] TARGET [0:13] = '{8'd1, 8'd2, 8'd3, 8'd4, 8'd5, 8'd6, 8'd7,
                                              8'd13, 8'd12, 8'd11, 8'd10, 8'd9, 8'd8, 8'd0};

    // DFS state
    reg [7:0] empty_pos; // 0-13 (0-6: row0, 7-13: row1)
    reg [7:0] depth;
    reg [7:0] move_count;
    reg [255:0] move_sequence; // Store up to 256 moves (2 bits each)
    
    // Current path tracking
    reg [7:0] path [0:255]; // Stores grid configurations
    reg [7:0] path_empty [0:255]; // Stores empty positions
    
    // Solution found flag
    reg solution_found;

    // Initialize grid from inputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize grid
            grid[0] <= 8'd0;
            grid[1] <= 8'd0;
            grid[2] <= 8'd0;
            grid[3] <= 8'd0;
            grid[4] <= 8'd0;
            grid[5] <= 8'd0;
            grid[6] <= 8'd0;
            grid[7] <= 8'd0;
            grid[8] <= 8'd0;
            grid[9] <= 8'd0;
            grid[10] <= 8'd0;
            grid[11] <= 8'd0;
            grid[12] <= 8'd0;
            grid[13] <= 8'd0;
            
            empty_pos <= 8'd0;
            depth <= 8'd0;
            move_count <= 8'd0;
            
            // Initialize path arrays
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                path[i] <= 8'd0;
                path_empty[i] <= 8'd0;
            end
            
            solution_found <= 1'b0;
            moves_out <= 512'd0;
        end else begin
            // Update grid from inputs when in IDLE
            if (state == IDLE) begin
                grid[0] <= arr_0;
                grid[1] <= arr_1;
                grid[2] <= arr_2;
                grid[3] <= arr_3;
                grid[4] <= arr_4;
                grid[5] <= arr_5;
                grid[6] <= arr_6;
                grid[7] <= arr_7;
                grid[8] <= arr_8;
                grid[9] <= arr_9;
                grid[10] <= arr_10;
                grid[11] <= arr_11;
                grid[12] <= arr_12;
                grid[13] <= arr_13;
                
                // Find empty position
                integer j;
                for (j = 0; j < 14; j = j + 1) begin
                    if (grid[j] == 8'd0) begin
                        empty_pos <= j;
                    end
                end
            end
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SOLVE;
                        depth <= 8'd0;
                        move_count <= 8'd0;
                        solution_found <= 1'b0;
                        
                        // Initialize path
                        integer k;
                        for (k = 0; k < 14; k = k + 1) begin
                            path[0][k] <= grid[k];
                        end
                        path_empty[0] <= empty_pos;
                    end
                end
                
                SOLVE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current state matches target
                    reg match;
                    integer m;
                    match = 1'b1;
                    for (m = 0; m < 14; m = m + 1) begin
                        if (grid[m] != TARGET[m]) begin
                            match = 1'b0;
                        end
                    end
                    
                    if (match) begin
                        solution_found <= 1'b1;
                        state <= DONE_STATE;
                    end else if (cycle_count >= MAX_CYCLES || depth >= 8'd255) begin
                        // No solution found within limits
                        result <= 8'd0;
                        state <= DONE_STATE;
                    end else begin
                        // Try all possible moves
                        reg [7:0] current_empty;
                        current_empty = empty_pos;
                        
                        // Try moving up (from row 1 to row 0)
                        if (current_empty >= 7 && current_empty <= 13) begin
                            reg [7:0] new_empty;
                            new_empty = current_empty - 7;
                            
                            // Check if move is valid (empty in leftmost, rightmost, or center column)
                            reg [7:0] col;
                            col = current_empty % 7;
                            
                            if (col == 0 || col == 6 || col == 3) begin
                                // Make the move
                                grid[current_empty] <= grid[new_empty];
                                grid[new_empty] <= 8'd0;
                                empty_pos <= new_empty;
                                
                                // Store move (00 = up)
                                move_sequence[move_count] <= 2'd0;
                                move_count <= move_count + 8'd1;
                                
                                // Update path
                                integer p;
                                for (p = 0; p < 14; p = p + 1) begin
                                    path[depth+1][p] <= grid[p];
                                end
                                path_empty[depth+1] <= empty_pos;
                                depth <= depth + 8'd1;
                            end
                        end
                        
                        // Try moving down (from row 0 to row 1)
                        if (current_empty >= 0 && current_empty <= 6) begin
                            reg [7:0] new_empty;
                            new_empty = current_empty + 7;
                            
                            // Check if move is valid (empty in leftmost, rightmost, or center column)
                            reg [7:0] col;
                            col = current_empty % 7;
                            
                            if (col == 0 || col == 6 || col == 3) begin
                                // Make the move
                                grid[current_empty] <= grid[new_empty];
                                grid[new_empty] <= 8'd0;
                                empty_pos <= new_empty;
                                
                                // Store move (01 = down)
                                move_sequence[move_count] <= 2'd1;
                                move_count <= move_count + 8'd1;
                                
                                // Update path
                                integer p;
                                for (p = 0; p < 14; p = p + 1) begin
                                    path[depth+1][p] <= grid[p];
                                end
                                path_empty[depth+1] <= empty_pos;
                                depth <= depth + 8'd1;
                            end
                        end
                        
                        // Try moving left
                        if (current_empty % 7 != 0) begin
                            reg [7:0] new_empty;
                            new_empty = current_empty - 1;
                            
                            // Make the move
                            grid[current_empty] <= grid[new_empty];
                            grid[new_empty] <= 8'd0;
                            empty_pos <= new_empty;
                            
                            // Store move (10 = left)
                            move_sequence[move_count] <= 2'd2;
                            move_count <= move_count + 8'd1;
                            
                            // Update path
                            integer p;
                            for (p = 0; p < 14; p = p + 1) begin
                                path[depth+1][p] <= grid[p];
                            end
                            path_empty[depth+1] <= empty_pos;
                            depth <= depth + 8'd1;
                        end
                        
                        // Try moving right
                        if (current_empty % 7 != 6) begin
                            reg [7:0] new_empty;
                            new_empty = current_empty + 1;
                            
                            // Make the move
                            grid[current_empty] <= grid[new_empty];
                            grid[new_empty] <= 8'd0;
                            empty_pos <= new_empty;
                            
                            // Store move (11 = right)
                            move_sequence[move_count] <= 2'd3;
                            move_count <= move_count + 8'd1;
                            
                            // Update path
                            integer p;
                            for (p = 0; p < 14; p = p + 1) begin
                                path[depth+1][p] <= grid[p];
                            end
                            path_empty[depth+1] <= empty_pos;
                            depth <= depth + 8'd1;
                        end
                        
                        // If no moves were made, backtrack
                        if (depth == 8'd0) begin
                            // No solution found
                            result <= 8'd0;
                            state <= DONE_STATE;
                        end else begin
                            // Backtrack
                            depth <= depth - 8'd1;
                            move_count <= move_count - 8'd1;
                            
                            // Restore grid from path
                            integer p;
                            for (p = 0; p < 14; p = p + 1) begin
                                grid[p] <= path[depth][p];
                            end
                            empty_pos <= path_empty[depth];
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (solution_found) begin
                        result <= 8'd1;
                        
                        // Pack moves into output
                        integer i;
                        for (i = 0; i < 256; i = i + 1) begin
                            moves_out[i*2 + 1] <= move_sequence[i][1];
                            moves_out[i*2] <= move_sequence[i][0];
                        end
                    end else begin
                        result <= 8'd0;
                    end
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule