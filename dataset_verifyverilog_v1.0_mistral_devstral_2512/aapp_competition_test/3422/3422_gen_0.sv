module TreasureMapReconstructor(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_pieces,
    input [3:0] piece_w [3:0],
    input [3:0] piece_h [3:0],
    input [3:0] piece_grid [3:0][3:0][3:0],
    output reg [3:0] out_width,
    output reg [3:0] out_height,
    output reg [3:0] out_grid [15:0],
    output reg [2:0] out_piece_map [15:0],
    output reg done,
    output reg valid
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PREPARE = 2'd1;
    localparam [1:0] SOLVE = 2'd2;
    localparam [1:0] OUTPUT = 2'd3;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;
    
    reg [3:0] total_area;
    reg [3:0] candidate_w, candidate_h;
    reg [3:0] candidate_index;
    
    reg [3:0] current_grid [15:0];
    reg [2:0] current_piece_map [15:0];
    
    reg [1:0] backtrack_stack [15:0];
    reg [1:0] stack_ptr;
    
    reg [3:0] rotated_piece [3:0][3:0][3:0];
    reg [3:0] rotated_w, rotated_h;
    
    reg [3:0] treasure_x, treasure_y;
    reg treasure_found;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 8'd0;
            out_width <= 4'd0;
            out_height <= 4'd0;
            
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                out_grid[i] <= 4'd0;
                out_piece_map[i] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        state <= PREPARE;
                    end
                end
                
                PREPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    total_area <= 4'd0;
                    integer i;
                    for (i = 0; i < num_pieces; i = i + 1) begin
                        total_area <= total_area + (piece_w[i] * piece_h[i]);
                    end
                    
                    candidate_w <= 4'd0;
                    candidate_h <= 4'd0;
                    candidate_index <= 4'd0;
                    
                    integer j, k;
                    for (j = 0; j < 16; j = j + 1) begin
                        current_grid[j] <= 4'd0;
                        current_piece_map[j] <= 3'd0;
                    end
                    
                    stack_ptr <= 2'd0;
                    
                    state <= SOLVE;
                end
                
                SOLVE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end else begin
                        if (stack_ptr == num_pieces) begin
                            treasure_found <= 1'b0;
                            
                            integer x, y, tx, ty;
                            for (tx = 0; tx < candidate_w; tx = tx + 1) begin
                                for (ty = 0; ty < candidate_h; ty = ty + 1) begin
                                    treasure_found <= 1'b1;
                                    
                                    for (x = 0; x < candidate_w; x = x + 1) begin
                                        for (y = 0; y < candidate_h; y = y + 1) begin
                                            if (current_grid[x + y * candidate_w] != (abs(x - tx) + abs(y - ty)) % 10) begin
                                                treasure_found <= 1'b0;
                                            end
                                        end
                                    end
                                    
                                    if (treasure_found) begin
                                        treasure_x <= tx;
                                        treasure_y <= ty;
                                        
                                        integer i;
                                        for (i = 0; i < 16; i = i + 1) begin
                                            out_grid[i] <= current_grid[i];
                                            out_piece_map[i] <= current_piece_map[i];
                                        end
                                        
                                        out_width <= candidate_w;
                                        out_height <= candidate_h;
                                        
                                        state <= OUTPUT;
                                    end
                                end
                            end
                            
                            if (!treasure_found) begin
                                stack_ptr <= stack_ptr - 2'd1;
                            end
                        end else begin
                            integer piece_idx;
                            piece_idx <= stack_ptr;
                            
                            if (piece_idx < num_pieces) begin
                                integer rot, x, y;
                                
                                for (rot = 0; rot < 4; rot = rot + 1) begin
                                    rotated_w <= (rot == 0 || rot == 2) ? piece_w[piece_idx] : piece_h[piece_idx];
                                    rotated_h <= (rot == 0 || rot == 2) ? piece_h[piece_idx] : piece_w[piece_idx];
                                    
                                    for (x = 0; x <= candidate_w - rotated_w; x = x + 1) begin
                                        for (y = 0; y <= candidate_h - rotated_h; y = y + 1) begin
                                            integer can_place;
                                            can_place <= 1'b1;
                                            
                                            integer i, j;
                                            for (i = 0; i < rotated_w; i = i + 1) begin
                                                for (j = 0; j < rotated_h; j = j + 1) begin
                                                    if (current_grid[x + i + (y + j) * candidate_w] != 4'd0) begin
                                                        can_place <= 1'b0;
                                                    end
                                                end
                                            end
                                            
                                            if (can_place) begin
                                                for (i = 0; i < rotated_w; i = i + 1) begin
                                                    for (j = 0; j < rotated_h; j = j + 1) begin
                                                        current_grid[x + i + (y + j) * candidate_w] <= rotated_piece[piece_idx][i][j];
                                                        current_piece_map[x + i + (y + j) * candidate_w] <= piece_idx + 1;
                                                    end
                                                end
                                                
                                                stack_ptr <= stack_ptr + 2'd1;
                                            end
                                        end
                                    end
                                end
                            end else begin
                                stack_ptr <= stack_ptr - 2'd1;
                            end
                        end
                    end
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule