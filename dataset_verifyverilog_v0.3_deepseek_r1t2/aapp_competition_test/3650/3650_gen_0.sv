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

    // State declarations with explicit widths
    localparam [2:0] S_IDLE     = 3'd0;
    localparam [2:0] S_CHECK    = 3'd1;
    localparam [2:0] S_SEARCH   = 3'd2;
    localparam [2:0] S_OUTPUT   = 3'd3;
    localparam [2:0] S_UPDATE   = 3'd4;
    localparam [2:0] S_COMPLETE = 3'd5;
    localparam [2:0] S_FAIL     = 3'd6;
    
    reg [2:0] state;
    
    // Grid storage
    reg [GRID_ROWS*GRID_COLS-1:0] grid;
    
    // Internal registers
    reg [3:0] idx;
    reg [DATA_WIDTH-1:0] cur_r;
    reg [DATA_WIDTH-1:0] cur_c;
    reg [DATA_WIDTH-1:0] k_reg;
    reg [1:0] dir_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Functions
    function automatic bit is_occ(input [DATA_WIDTH-1:0] r, c);
        is_occ = (r >= 4'd1 && r <= GRID_ROWS && c >= 4'd1 && c <= GRID_COLS) ? grid[(r-1)*GRID_COLS + (c-1)] : 1'b0;
    endfunction

    function automatic [9:0] find_move(input [DATA_WIDTH-1:0] r, c);
        bit v_up, v_down, v_left, v_right;
        integer up_i, down_i, left_i, right_i;
    begin
        v_up = 1'b0;
        v_down = 1'b0;
        v_left = 1'b0;
        v_right = 1'b0;
        
        // Check vertical paths
        if (is_occ(r-4'd1, c) && !is_occ(r+4'd1, c)) begin
            v_up = 1'b1;
            for (up_i = r+4'd1; up_i <= GRID_ROWS; up_i = up_i + 4'd1)
                if (is_occ(up_i, c)) v_up = 1'b0;
        end
        
        if (is_occ(r+4'd1, c) && !is_occ(r-4'd1, c)) begin
            v_down = 1'b1;
            for (down_i = r-4'd1; down_i >= 4'd1; down_i = down_i - 4'd1)
                if (is_occ(down_i, c)) v_down = 1'b0;
        end
        
        // Check horizontal paths
        if (is_occ(r, c-4'd1) && !is_occ(r, c+4'd1)) begin
            v_left = 1'b1;
            for (left_i = c+4'd1; left_i <= GRID_COLS; left_i = left_i + 4'd1)
                if (is_occ(r, left_i)) v_left = 1'b0;
        end
        
        if (is_occ(r, c+4'd1) && !is_occ(r, c-4'd1)) begin
            v_right = 1'b1;
            for (right_i = c-4'd1; right_i >= 4'd1; right_i = right_i - 4'd1)
                if (is_occ(r, right_i)) v_right = 1'b0;
        end
        
        if (v_up) find_move = {1'b1, 2'b11, r};
        else if (v_down) find_move = {1'b1, 2'b10, r};
        else if (v_left) find_move = {1'b1, 2'b00, c};
        else if (v_right) find_move = {1'b1, 2'b01, c};
        else find_move = 10'd0;
    end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            grid <= {GRID_ROWS*GRID_COLS{1'b0}};
            idx <= 4'd0;
            move_valid <= 1'b0;
            move_dir <= 2'd0;
            move_k <= {DATA_WIDTH{1'b0}};
            done <= 1'b0;
            possible <= 1'b0;
            cycle_count <= 8'd0;
            cur_r <= {DATA_WIDTH{1'b0}};
            cur_c <= {DATA_WIDTH{1'b0}};
            k_reg <= {DATA_WIDTH{1'b0}};
            dir_reg <= 2'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    possible <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        grid <= {GRID_ROWS*GRID_COLS{1'b0}};
                        if (init_r >= 4'd1 && init_r <= GRID_ROWS && init_c >= 4'd1 && init_c <= GRID_COLS)
                            grid[(init_r-1)*GRID_COLS + (init_c-1)] <= 1'b1;
                        idx <= 4'd0;
                        state <= S_CHECK;
                    end
                end
                
                S_CHECK: begin
                    move_valid <= 1'b0;
                    if (cycle_count >= MAX_CYCLES) state <= S_FAIL;
                    else if (idx >= num_blocks) begin
                        possible <= 1'b1;
                        state <= S_COMPLETE;
                    end else begin
                        cur_r <= target_r[idx];
                        cur_c <= target_c[idx];
                        state <= S_SEARCH;
                    end
                end
                
                S_SEARCH: begin
                    {dir_reg, k_reg} <= find_move(cur_r, cur_c);
                    if (cycle_count >= MAX_CYCLES) state <= S_FAIL;
                    else if (find_move(cur_r, cur_c)[9]) state <= S_OUTPUT;
                    else state <= S_FAIL;
                end
                
                S_OUTPUT: begin
                    move_valid <= 1'b1;
                    move_dir <= dir_reg;
                    move_k <= k_reg;
                    state <= S_UPDATE;
                end
                
                S_UPDATE: begin
                    move_valid <= 1'b0;
                    if (cur_r >= 4'd1 && cur_r <= GRID_ROWS && cur_c >= 4'd1 && cur_c <= GRID_COLS)
                        grid[(cur_r-1)*GRID_COLS + (cur_c-1)] <= 1'b1;
                    idx <= idx + 4'd1;
                    cycle_count <= 8'd0;
                    state <= S_CHECK;
                end
                
                S_COMPLETE: begin
                    done <= 1'b1;
                    state <= S_IDLE;
                end
                
                S_FAIL: begin
                    possible <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule