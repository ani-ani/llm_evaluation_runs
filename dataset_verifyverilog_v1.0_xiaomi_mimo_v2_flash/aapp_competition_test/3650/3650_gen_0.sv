module sliding_blocks_solver #(
    parameter GRID_ROWS = 4,
    parameter GRID_COLS = 4,
    parameter MAX_BLOCKS = 8,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] init_r,
    input wire [DATA_WIDTH-1:0] init_c,
    input wire [DATA_WIDTH-1:0] target_r [0:MAX_BLOCKS-1],
    input wire [DATA_WIDTH-1:0] target_c [0:MAX_BLOCKS-1],
    input wire [3:0] num_blocks,
    output reg move_valid,
    output reg [1:0] move_dir,
    output reg [DATA_WIDTH-1:0] move_k,
    output reg done,
    output reg possible
);

// State machine declarations
localparam [2:0] S_IDLE    = 3'd0;
localparam [2:0] S_CHECK   = 3'd1;
localparam [2:0] S_SEARCH  = 3'd2;
localparam [2:0] S_OUTPUT  = 3'd3;
localparam [2:0] S_UPDATE  = 3'd4;
localparam [2:0] S_COMPLETE = 3'd5;
localparam [2:0] S_FAIL    = 3'd6;

reg [2:0] state;
reg [2:0] next_state;

// Grid state: flattened 2D array (1-indexed coordinates)
reg [GRID_ROWS*GRID_COLS-1:0] grid;

// Index and temporary registers
reg [3:0] idx;
reg [DATA_WIDTH-1:0] cur_r;
reg [DATA_WIDTH-1:0] cur_c;
reg [1:0] dir_reg;
reg [DATA_WIDTH-1:0] k_reg;
reg found_valid_move;

// Cycle counter to prevent infinite loops
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd250;

// Helper function: check if cell is occupied (1-indexed)
function automatic bit is_occ(
    input [DATA_WIDTH-1:0] r,
    input [DATA_WIDTH-1:0] c
);
    begin
        if (r >= 1 && r <= GRID_ROWS && c >= 1 && c <= GRID_COLS) begin
            is_occ = grid[(r - 1) * GRID_COLS + (c - 1)];
        end else begin
            is_occ = 1'b0;
        end
    end
endfunction

// Function to find a valid move for given position
function automatic [10:0] find_move(
    input [DATA_WIDTH-1:0] r,
    input [DATA_WIDTH-1:0] c
);
    reg up_valid, down_valid, left_valid, right_valid;
    integer i;
    begin
        // Check UP (direction 2'b11)
        up_valid = is_occ(r - 1, c) && !is_occ(r + 1, c);
        for (i = r + 1; i <= GRID_ROWS; i = i + 1) begin
            if (is_occ(i, c)) up_valid = 1'b0;
        end
        
        // Check DOWN (direction 2'b10)
        down_valid = is_occ(r + 1, c) && !is_occ(r - 1, c);
        for (i = r - 1; i >= 1; i = i - 1) begin
            if (is_occ(i, c)) down_valid = 1'b0;
        end
        
        // Check LEFT (direction 2'b00)
        left_valid = is_occ(r, c - 1) && !is_occ(r, c + 1);
        for (i = c + 1; i <= GRID_COLS; i = i + 1) begin
            if (is_occ(r, i)) left_valid = 1'b0;
        end
        
        // Check RIGHT (direction 2'b01)
        right_valid = is_occ(r, c + 1) && !is_occ(r, c - 1);
        for (i = c - 1; i >= 1; i = i - 1) begin
            if (is_occ(r, i)) right_valid = 1'b0;
        end
        
        // Return first valid move found (priority order: up, down, left, right)
        if (up_valid) begin
            find_move = {1'b1, 2'b11, r};  // {valid, dir, k}
        end else if (down_valid) begin
            find_move = {1'b1, 2'b10, r};
        end else if (left_valid) begin
            find_move = {1'b1, 2'b00, c};
        end else if (right_valid) begin
            find_move = {1'b1, 2'b01, c};
        end else begin
            find_move = 11'b0;  // No valid move
        end
    end
endfunction

// Combinational logic for move search (moved outside FSM for better timing)
wire [10:0] move_result;
wire valid_move_found;

assign move_result = find_move(cur_r, cur_c);
assign valid_move_found = move_result[10];

// State transition logic
always @(*) begin
    case (state)
        S_IDLE: begin
            if (start) next_state = S_CHECK;
            else next_state = S_IDLE;
        end
        S_CHECK: begin
            if (idx >= num_blocks) begin
                next_state = S_COMPLETE;
            end else begin
                next_state = S_SEARCH;
            end
        end
        S_SEARCH: begin
            if (valid_move_found) next_state = S_OUTPUT;
            else next_state = S_FAIL;
        end
        S_OUTPUT: begin
            next_state = S_UPDATE;
        end
        S_UPDATE: begin
            next_state = S_CHECK;
        end
        S_COMPLETE: begin
            next_state = S_IDLE;
        end
        S_FAIL: begin
            next_state = S_IDLE;
        end
        default: next_state = S_IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        grid <= {GRID_ROWS*GRID_COLS{1'b0}};
        idx <= 4'd0;
        cur_r <= {DATA_WIDTH{1'b0}};
        cur_c <= {DATA_WIDTH{1'b0}};
        dir_reg <= 2'b00;
        k_reg <= {DATA_WIDTH{1'b0}};
        move_valid <= 1'b0;
        move_dir <= 2'b00;
        move_k <= {DATA_WIDTH{1'b0}};
        done <= 1'b0;
        possible <= 1'b0;
        cycle_count <= 8'd0;
    end else begin
        state <= next_state;
        
        case (state)
            S_IDLE: begin
                // Reset outputs and counters when idle
                move_valid <= 1'b0;
                done <= 1'b0;
                possible <= 1'b0;
                idx <= 4'd0;
                cycle_count <= 8'd0;
                
                if (start) begin
                    // Initialize grid with starting block
                    grid <= {GRID_ROWS*GRID_COLS{1'b0}};
                    if (init_r >= 1 && init_r <= GRID_ROWS && 
                        init_c >= 1 && init_c <= GRID_COLS) begin
                        grid[(init_r - 1) * GRID_COLS + (init_c - 1)] <= 1'b1;
                    end
                end
            end
            
            S_CHECK: begin
                // Update current target block
                if (idx < num_blocks) begin
                    cur_r <= target_r[idx];
                    cur_c <= target_c[idx];
                end
            end
            
            S_SEARCH: begin
                // Store move result for output
                dir_reg <= move_result[8:7];  // bits 8:7 are direction
                k_reg <= move_result[6:0];    // bits 6:0 are k value (7 bits for 1-64)
            end
            
            S_OUTPUT: begin
                // Present the move
                move_valid <= 1'b1;
                move_dir <= dir_reg;
                move_k <= k_reg;
            end
            
            S_UPDATE: begin
                // Clear move valid and add new block to grid
                move_valid <= 1'b0;
                if (cur_r >= 1 && cur_r <= GRID_ROWS && 
                    cur_c >= 1 && cur_c <= GRID_COLS) begin
                    grid[(cur_r - 1) * GRID_COLS + (cur_c - 1)] <= 1'b1;
                end
                idx <= idx + 4'd1;
                cycle_count <= cycle_count + 8'd1;
            end
            
            S_COMPLETE: begin
                // All blocks processed successfully
                done <= 1'b1;
                possible <= 1'b1;
            end
            
            S_FAIL: begin
                // No valid move found
                done <= 1'b1;
                possible <= 1'b0;
            end
            
            default: begin
                // Safety catch
                state <= S_IDLE;
            end
        endcase
        
        // Cycle count protection
        if (cycle_count >= MAX_CYCLES && state == S_UPDATE) begin
            state <= S_FAIL;
        end
    end
end

endmodule